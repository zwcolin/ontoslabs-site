// make-bg.swift — builds the blurred background media for the Ontos Labs page.
//
// Only macOS frameworks are used (AVFoundation, CoreImage, AppKit); no ffmpeg.
//
// Build:  swiftc -O -swift-version 5 tools/make-bg.swift -o /tmp/make-bg
// Usage:
//   make-bg info    <video>                               # duration, tracks, codec, colour tags, top-level atoms
//   make-bg contact <video> <out.jpg> [interval=15] [from=0] [to=end]   # contact sheet, one frame every N s
//   make-bg preview <video> <out.jpg> <t1> [t2 ...]       # the processed look at given source times
//   make-bg frames  <video> <out.jpg> <t1> [t2 ...]       # sheet of frames from any video (for checking outputs)
//   make-bg render  <src.mp4> <mediaDir> <start> <duration>
//        writes bg.mp4 (1280x720), bg-mobile.mp4 (640x360), bg-poster.jpg, bg-poster-small.jpg
//
// Media in ../media was made with (source segment 3:55.6-4:16.8, no cuts):
//   make-bg render overview.mp4 media 235.6 28 --speed=0.72 --sigma=0.09 --ev=-1.1 --sat=0.8 --contrast=0.92 --hi-kbps=900 --lo-kbps=320
//
// Options (any command that processes frames):
//   --sigma=0.028   Gaussian sigma as a fraction of frame height (0.028 ≈ 30 px at 1080p)
//   --sat=0.70      saturation        --ev=-0.6   exposure (stops)      --contrast=0.97
//   --xfade=1.5     seconds of crossfade between the segment's tail and its head, so the loop has no seam
//   --speed=1.0     playback speed vs the source (e.g. 0.72 = slower and calmer; frames are interpolated)
//   --hi-kbps=800   --lo-kbps=280     H.264 average bitrates for bg.mp4 / bg-mobile.mp4
//
// The loop (speed 1): the output plays source [start+xfade, start+duration+xfade). Over its last `xfade` seconds the
// picture dissolves into source [start, start+xfade), i.e. into the frames that immediately precede its own
// first frame, so the last frame flows straight into the first one when the browser loops.

import AVFoundation
import AppKit
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - helpers

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}
func log(_ msg: String) { print(msg); fflush(stdout) }
func cmt(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 600) }
func fmt(_ t: Double) -> String { String(format: "%d:%04.1f", Int(t) / 60, t.truncatingRemainder(dividingBy: 60)) }
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func fileSize(_ url: URL) -> Int { (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0 }

func writeJPEG(_ image: CGImage, to url: URL, quality: Double = 0.86, progressive: Bool = false) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { fail("cannot create \(url.path)") }
    var props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
    if progressive { props[kCGImagePropertyJFIFDictionary] = [kCGImagePropertyJFIFIsProgressive: true] }
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { fail("cannot write \(url.path)") }
}

// MARK: - options

var opts: [String: Double] = [:]
var args: [String] = []
for a in CommandLine.arguments.dropFirst() {
    if a.hasPrefix("--"), let eq = a.firstIndex(of: "=") {
        let k = String(a[a.index(a.startIndex, offsetBy: 2)..<eq])
        guard let v = Double(a[a.index(after: eq)...]) else { fail("bad value in \(a)") }
        opts[k] = v
    } else {
        args.append(a)
    }
}
func opt(_ k: String, _ d: Double) -> Double { opts[k] ?? d }

// MARK: - the look

struct Look {
    var sigmaFrac = opt("sigma", 0.028)
    var saturation = opt("sat", 0.70)
    var exposureEV = opt("ev", -0.6)
    var contrast = opt("contrast", 0.97)
}

/// All pixel values are treated as sRGB on the way in and out, so the video and the JPEG posters carry
/// identical code values (no gamma shift between poster and first video frame).
final class Processor {
    let look: Look
    let w: Int, h: Int
    init(look: Look, w: Int, h: Int) { self.look = look; self.w = w; self.h = h }

    func source(_ pb: CVPixelBuffer) -> CIImage { CIImage(cvPixelBuffer: pb, options: [.colorSpace: sRGB]) }
    func source(_ cg: CGImage) -> CIImage { CIImage(cgImage: cg, options: [.colorSpace: sRGB]) }

    /// Scale to w×h, blur (clamped edges, cropped back), desaturate and darken.
    func process(_ input: CIImage) -> CIImage {
        let e = input.extent
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        var img = input
            .transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
            .transformed(by: CGAffineTransform(scaleX: CGFloat(w) / e.width, y: CGFloat(h) / e.height))
        img = img.clampedToExtent()
            .applyingGaussianBlur(sigma: look.sigmaFrac * Double(h))
            .cropped(to: rect)
        img = img.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: look.saturation,
            kCIInputContrastKey: look.contrast,
            kCIInputBrightnessKey: 0.0,
        ])
        img = img.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: look.exposureEV])
        return img.cropped(to: rect)
    }
}

// MARK: - sheets (contact sheet / previews / output checks)

func drawSheet(_ cells: [(CGImage, String)], cellW: Int, columns: Int, out: URL) {
    let cellH = cellW * 9 / 16
    let pad = 6, label = 20
    let rows = (cells.count + columns - 1) / columns
    let W = columns * (cellW + pad) + pad
    let H = rows * (cellH + label + pad) + pad
    guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
                              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    else { fail("no context") }
    ctx.setFillColor(CGColor(gray: 0.12, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    for (i, (img, text)) in cells.enumerated() {
        let col = i % columns, row = i / columns
        let x = pad + col * (cellW + pad)
        let top = pad + row * (cellH + label + pad)
        let y = H - top - label - cellH
        ctx.draw(img, in: CGRect(x: x, y: y, width: cellW, height: cellH))
        (text as NSString).draw(at: NSPoint(x: x + 2, y: y + cellH + 3), withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white,
        ])
    }
    NSGraphicsContext.current = nil
    writeJPEG(ctx.makeImage()!, to: out, quality: 0.9)
}

func grab(_ url: URL, times: [Double], maxW: Int, exact: Bool) async throws -> [(CGImage, Double)] {
    let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    gen.appliesPreferredTrackTransform = true
    if maxW > 0 { gen.maximumSize = CGSize(width: maxW, height: maxW) }
    let tol = exact ? CMTime.zero : cmt(0.5)
    gen.requestedTimeToleranceBefore = tol
    gen.requestedTimeToleranceAfter = tol
    var out: [(CGImage, Double)] = []
    for t in times {
        let (img, actual) = try await gen.image(at: cmt(t))
        out.append((img, actual.seconds))
    }
    return out
}

// MARK: - info

func fourCC(_ v: FourCharCode) -> String {
    String(bytes: [24, 16, 8, 0].map { UInt8((v >> $0) & 0xff) }, encoding: .macOSRoman) ?? "\(v)"
}

func topLevelAtoms(_ url: URL) -> [String] {
    guard let fh = try? FileHandle(forReadingFrom: url) else { return [] }
    defer { try? fh.close() }
    var atoms: [String] = []
    var offset: UInt64 = 0
    let end = (try? fh.seekToEnd()) ?? 0
    while offset + 8 <= end, atoms.count < 32 {
        try? fh.seek(toOffset: offset)
        guard let hdr = try? fh.read(upToCount: 16), hdr.count >= 8 else { break }
        let b = [UInt8](hdr)
        var size = UInt64(b[0]) << 24 | UInt64(b[1]) << 16 | UInt64(b[2]) << 8 | UInt64(b[3])
        let type = String(bytes: b[4..<8], encoding: .macOSRoman) ?? "????"
        if size == 1, b.count >= 16 { size = b[8..<16].reduce(0) { $0 << 8 | UInt64($1) } }
        if size == 0 { size = end - offset }
        atoms.append("\(type)(\(size))")
        if size < 8 { break }
        offset += size
    }
    return atoms
}

func info(_ url: URL) async throws {
    let asset = AVURLAsset(url: url)
    let dur = try await asset.load(.duration)
    log("file: \(url.path)")
    log(String(format: "size: %d bytes (%.2f MB, %.2f MiB)", fileSize(url), Double(fileSize(url)) / 1e6, Double(fileSize(url)) / 1_048_576))
    log(String(format: "duration: %.3f s", dur.seconds))
    log("atoms: " + topLevelAtoms(url).joined(separator: " "))
    for track in try await asset.load(.tracks) {
        let type = track.mediaType.rawValue
        let natural = try await track.load(.naturalSize)
        let fps = try await track.load(.nominalFrameRate)
        let minDur = try await track.load(.minFrameDuration)
        let rate = try await track.load(.estimatedDataRate)
        let xf = try await track.load(.preferredTransform)
        let tr = try await track.load(.timeRange)
        log(String(format: "track %@: %.0fx%.0f, %.3f fps (minFrameDuration %lld/%d), %.0f kbps, track duration %.3f s, transform identity=%@",
                   type, natural.width, natural.height, fps, minDur.value, minDur.timescale, rate / 1000, tr.duration.seconds,
                   xf.isIdentity ? "yes" : "no"))
        for fd in try await track.load(.formatDescriptions) {
            var line = "  codec \(fourCC(CMFormatDescriptionGetMediaSubType(fd)))"
            if let ext = CMFormatDescriptionGetExtensions(fd) as? [String: Any] {
                for k in ["CVImageBufferColorPrimaries", "CVImageBufferTransferFunction", "CVImageBufferYCbCrMatrix", "FullRangeVideo"] {
                    if let v = ext[k] { line += " \(k.replacingOccurrences(of: "CVImageBuffer", with: ""))=\(v)" }
                }
                if let atoms = ext["SampleDescriptionExtensionAtoms"] as? [String: Any], let avcC = atoms["avcC"] as? Data, avcC.count > 3 {
                    let p = avcC[avcC.startIndex + 1], l = avcC[avcC.startIndex + 3]
                    line += " avcC profile=\(p) level=\(l)"
                }
            }
            log(line)
        }
    }
}

// MARK: - render

struct Output {
    let writer: AVAssetWriter
    let input: AVAssetWriterInput
    let adaptor: AVAssetWriterInputPixelBufferAdaptor
    let w: Int, h: Int
}

func makeOutput(_ url: URL, w: Int, h: Int, kbps: Int, fps: Double) throws -> Output {
    try? FileManager.default.removeItem(at: url)
    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true  // moov before mdat
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: w,
        AVVideoHeightKey: h,
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: kbps * 1000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
            AVVideoMaxKeyFrameIntervalKey: Int((fps * 3).rounded()),
            AVVideoMaxKeyFrameIntervalDurationKey: 3.0,
            AVVideoAllowFrameReorderingKey: true,
            AVVideoExpectedSourceFrameRateKey: Int(fps.rounded()),
        ] as [String: Any],
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: w,
        kCVPixelBufferHeightKey as String: h,
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
    ])
    guard writer.canAdd(input) else { fail("cannot add video input for \(url.lastPathComponent)") }
    writer.add(input)
    guard writer.startWriting() else { fail("startWriting: \(writer.error?.localizedDescription ?? "?")") }
    writer.startSession(atSourceTime: .zero)
    return Output(writer: writer, input: input, adaptor: adaptor, w: w, h: h)
}

func append(_ img: CIImage, to o: Output, ctx: CIContext, pts: CMTime) {
    while !o.input.isReadyForMoreMediaData {
        if o.writer.status == .failed { fail("writer failed: \(o.writer.error?.localizedDescription ?? "?")") }
        usleep(1000)
    }
    guard let pool = o.adaptor.pixelBufferPool else { fail("no pixel buffer pool: \(o.writer.error?.localizedDescription ?? "?")") }
    var pbOut: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut)
    guard let pb = pbOut else { fail("pixel buffer allocation failed") }
    ctx.render(img, to: pb, bounds: CGRect(x: 0, y: 0, width: o.w, height: o.h), colorSpace: sRGB)
    guard o.adaptor.append(pb, withPresentationTime: pts) else { fail("append failed: \(o.writer.error?.localizedDescription ?? "?")") }
}

/// Sequential reader that can return the (linearly interpolated) frame at any source time, so a segment
/// can be played slower than real time; with the heavy blur, blending neighbouring frames is invisible.
final class Stream {
    let reader: AVAssetReader
    let out: AVAssetReaderTrackOutput
    var a: (CIImage, Double)?, b: (CIImage, Double)?
    var started = false
    init(asset: AVAsset, track: AVAssetTrack, from: Double, to: Double) throws {
        reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: cmt(max(0, from)), end: cmt(to))
        out = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        out.alwaysCopiesSampleData = false
        reader.add(out)
        guard reader.startReading() else { fail("reader: \(reader.error?.localizedDescription ?? "?")") }
    }
    func pull() -> (CIImage, Double)? {
        while let sb = out.copyNextSampleBuffer() {
            if let pb = CMSampleBufferGetImageBuffer(sb) {
                return (CIImage(cvPixelBuffer: pb, options: [.colorSpace: sRGB]), CMSampleBufferGetPresentationTimeStamp(sb).seconds)
            }
        }
        return nil
    }
    func frame(at t: Double) -> CIImage? {
        if !started { started = true; a = pull(); b = pull() }
        while let bb = b, bb.1 <= t { a = bb; b = pull() }
        guard let aa = a else { return nil }
        guard let bb = b else { return aa.0 }
        let f = max(0, min(1, (t - aa.1) / (bb.1 - aa.1)))
        if f < 0.01 { return aa.0 }
        if f > 0.99 { return bb.0 }
        return aa.0.applyingFilter("CIDissolveTransition", parameters: [kCIInputTargetImageKey: bb.0, kCIInputTimeKey: f])
    }
}

func render(src: URL, mediaDir: URL, start s0: Double, duration D: Double) async throws {
    let look = Look()
    let X = opt("xfade", 1.5)          // output seconds
    let speed = opt("speed", 1.0)      // playback speed relative to the source (<1 = slower, calmer)
    let asset = AVURLAsset(url: src)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else { fail("no video track") }
    let fps = min(30, Double(try await track.load(.nominalFrameRate)).rounded())
    let frameDur = CMTime(value: 1, timescale: CMTimeScale(fps))
    let N = Int((D * fps).rounded())
    let nX = max(0, Int((X * fps).rounded()))
    let Xs = Double(nX) / fps * speed  // crossfade length in source seconds
    let mainStart = s0 + Xs
    log(String(format: "output %.0f fps, %d frames (%.2f s) at %.2fx speed; crossfade %d frames", fps, N, Double(N) / fps, speed, nX))
    log(String(format: "source used: %.2f s .. %.2f s (%@ .. %@); loop starts at source %.2f s",
               s0, mainStart + D * speed, fmt(s0), fmt(mainStart + D * speed), mainStart))

    let main = try Stream(asset: asset, track: track, from: mainStart - 0.2, to: mainStart + D * speed + 0.2)
    let head = try Stream(asset: asset, track: track, from: s0 - 0.2, to: mainStart + 0.2)
    let hiURL = mediaDir.appendingPathComponent("bg.mp4")
    let loURL = mediaDir.appendingPathComponent("bg-mobile.mp4")
    let hi = try makeOutput(hiURL, w: 1280, h: 720, kbps: Int(opt("hi-kbps", 800)), fps: fps)
    let lo = try makeOutput(loURL, w: 640, h: 360, kbps: Int(opt("lo-kbps", 280)), fps: fps)

    let ctx = CIContext(options: [.cacheIntermediates: false])
    let proc = Processor(look: look, w: 1280, h: 720)
    var written = 0
    let t0 = Date()
    for i in 0..<N {
        let ok: Bool = autoreleasepool {
            let tOut = Double(i) / fps
            guard var src = main.frame(at: mainStart + tOut * speed) else { return false }
            if i >= N - nX {  // dissolve into the frames that precede the loop's first frame
                let k = i - (N - nX)
                if let h = head.frame(at: s0 + Double(k) / fps * speed) {
                    let a = Double(k + 1) / Double(nX + 1)
                    let alpha = a * a * (3 - 2 * a)  // smoothstep
                    src = src.applyingFilter("CIDissolveTransition", parameters: [kCIInputTargetImageKey: h, kCIInputTimeKey: alpha])
                }
            }
            let frame = proc.process(src)
            let small = frame.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
            let pts = CMTimeMultiply(frameDur, multiplier: Int32(i))
            append(frame, to: hi, ctx: ctx, pts: pts)
            append(small, to: lo, ctx: ctx, pts: pts)
            if i == 0 {
                guard let big = ctx.createCGImage(frame, from: CGRect(x: 0, y: 0, width: 1280, height: 720), format: .RGBA8, colorSpace: sRGB),
                      let little = ctx.createCGImage(small, from: CGRect(x: 0, y: 0, width: 640, height: 360), format: .RGBA8, colorSpace: sRGB)
                else { fail("poster render failed") }
                writeJPEG(big, to: mediaDir.appendingPathComponent("bg-poster.jpg"), quality: 0.82, progressive: true)
                writeJPEG(little, to: mediaDir.appendingPathComponent("bg-poster-small.jpg"), quality: 0.82, progressive: true)
            }
            return true
        }
        if !ok { log("source ended early at output frame \(i)"); break }
        written += 1
        if written % 300 == 0 { log(String(format: "  %d/%d frames (%.1f s elapsed)", written, N, Date().timeIntervalSince(t0))) }
    }
    main.reader.cancelReading()
    head.reader.cancelReading()
    let endTime = CMTimeMultiply(frameDur, multiplier: Int32(written))
    for o in [hi, lo] {
        o.input.markAsFinished()
        o.writer.endSession(atSourceTime: endTime)
        await o.writer.finishWriting()
        guard o.writer.status == .completed else { fail("finishWriting: \(o.writer.error?.localizedDescription ?? "?")") }
    }
    log(String(format: "wrote %d frames in %.1f s", written, Date().timeIntervalSince(t0)))
    for name in ["bg.mp4", "bg-mobile.mp4", "bg-poster.jpg", "bg-poster-small.jpg"] {
        let u = mediaDir.appendingPathComponent(name)
        log(String(format: "  %-20@ %9d bytes (%.2f MB)", name as NSString, fileSize(u), Double(fileSize(u)) / 1e6))
    }
}

// MARK: - main

guard let cmd = args.first else { fail("usage: make-bg info|contact|preview|frames|render ... (see header)") }
func url(_ i: Int) -> URL {
    guard args.count > i else { fail("missing argument \(i) for \(cmd)") }
    return URL(fileURLWithPath: args[i])
}
func times(from i: Int) -> [Double] { args.dropFirst(i).compactMap { Double($0) } }

switch cmd {
case "info":
    for i in 1..<max(2, args.count) { try await info(url(i)) }
case "contact":
    let src = url(1)
    let interval = args.count > 3 ? Double(args[3]) ?? 15 : 15
    let dur = try await AVURLAsset(url: src).load(.duration).seconds
    let from = args.count > 4 ? Double(args[4]) ?? 0 : 0
    let to = args.count > 5 ? min(Double(args[5]) ?? dur, dur - 0.5) : dur - 0.5
    let ts = Array(stride(from: from, to: to, by: interval))
    let frames = try await grab(src, times: ts, maxW: 320, exact: false)
    drawSheet(frames.map { ($0.0, fmt($0.1)) }, cellW: 320, columns: 6, out: url(2))
    log("contact sheet: \(frames.count) frames -> \(args[2])")
case "preview":
    let src = url(1)
    let proc = Processor(look: Look(), w: 1280, h: 720)
    let ctx = CIContext()
    let frames = try await grab(src, times: times(from: 3), maxW: 0, exact: false)
    var cells: [(CGImage, String)] = []
    for (img, t) in frames {
        cells.append((img, "src " + fmt(t)))
        let out = proc.process(proc.source(img))
        cells.append((ctx.createCGImage(out, from: out.extent, format: .RGBA8, colorSpace: sRGB)!, "processed " + fmt(t)))
    }
    drawSheet(cells, cellW: 640, columns: 2, out: url(2))
    log("preview -> \(args[2])")
case "frames":
    let frames = try await grab(url(1), times: times(from: 3), maxW: 0, exact: true)
    drawSheet(frames.map { ($0.0, fmt($0.1) + " (\($0.0.width)x\($0.0.height))") }, cellW: 640, columns: 2, out: url(2))
    log("frames -> \(args[2])")
case "render":
    guard args.count >= 5, let s = Double(args[3]), let d = Double(args[4]) else { fail("render <src> <mediaDir> <start> <duration>") }
    try await render(src: url(1), mediaDir: url(2), start: s, duration: d)
default:
    fail("unknown command \(cmd)")
}
