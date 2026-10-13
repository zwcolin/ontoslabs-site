# Ontos Labs: stealth site

A one-page static site: logo, motto, contact address, and a looping, heavily blurred
background video. There is no build step; the folder is deployable as is.

## What's here

| Path | What it is |
| --- | --- |
| `index.html` | The page: inline SVG logo, motto, `mailto:` link, background `<video>`, social meta tags |
| `styles.css` | Layout for phones, tablets and desktops, scrim, focus styles, print and forced colours |
| `script.js` | Pause/play button for the background video (remembered per visitor) |
| `media/bg.mp4` | Desktop background, 1280x720 H.264, 28 s loop, about 1.7 MB |
| `media/bg-mobile.mp4` | Phone background, 640x360, about 0.55 MB (picked automatically on small screens) |
| `media/bg-poster*.jpg` | Still frames shown before the video plays, or instead of it when reduced motion is on |
| `media/og.jpg` | 1200x630 preview image for link sharing |
| `favicon.*`, `apple-touch-icon.png` | Icons |
| `tools/make-bg.swift` | Rebuilds the background media from a source video (macOS, no dependencies) |
| `.nojekyll` | Tells GitHub Pages to serve the files exactly as they are |

The page makes no external requests: no fonts, analytics or CDNs. The video is muted and
does not autoplay when the visitor has reduced motion turned on, and the pause button
(bottom right) stops it at any time.

## Publish in 2 minutes (GitHub web UI)

1. Go to <https://github.com/new>, choose a repository name (for example `ontoslabs-site`), and
   make it **Public**. On a free plan, Pages only works for public repos. Click **Create repository**.
2. On the new repo page, click **uploading an existing file**. Drag in the **contents** of this
   folder (`index.html`, `styles.css`, `script.js`, the icons, `.nojekyll`, and the `media/` folder),
   not the folder itself. `index.html` must be at the top level of the repo. Click **Commit changes**.
   The browser may hide `.nojekyll` because it starts with a dot. The site works without it.
   `tools/` and `README.md` are optional. Anything you upload to a public repo is public.
3. Open **Settings → Pages**. Under **Build and deployment**, set **Source** to **Deploy from a
   branch**, choose **Branch: `main`** and folder **`/ (root)`**, then click **Save**.
4. After about a minute the site is live at:

   `https://<user>.github.io/<repo>/`

   For example, `https://octocat.github.io/ontoslabs-site/`. If you name the repo
   `<user>.github.io`, the address is `https://<user>.github.io/`.

Command-line alternative: this folder is already a git repo with one commit on `main`, so you can run
`git remote add origin https://github.com/<user>/<repo>.git && git push -u origin main`
and then do step 3.

After publishing, make the social preview URLs absolute: in `index.html`, change
`content="media/og.jpg"` (in both `og:image` and `twitter:image`) to
`content="https://<your-site>/media/og.jpg"`. Most link scrapers ignore relative image URLs.

## Optional: custom domain (for example ontoslabs.ai)

1. Add a file named `CNAME` at the top level of the repo. It should contain one line: the domain,
   for example `ontoslabs.ai` or `www.ontoslabs.ai`. You can also enter the domain under
   **Settings → Pages → Custom domain**, which creates the file for you.
2. At your DNS provider:
   - **Apex domain** (`ontoslabs.ai`): add four `A` records pointing to
     `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`.
     Optional IPv6 `AAAA` records: `2606:50c0:8000::153`, `2606:50c0:8001::153`,
     `2606:50c0:8002::153`, `2606:50c0:8003::153`.
   - **Subdomain** (`www.ontoslabs.ai`): add a `CNAME` record pointing to `<user>.github.io`.
     Do not include the repo name.
3. DNS can take from a few minutes up to 24 hours to propagate. Once the domain check passes, tick
   **Enforce HTTPS** in **Settings → Pages**.

Email: the `mailto:contact@ontoslabs.ai` link only works if mail for that address is set up
with your mail provider. GitHub Pages does not handle email.

## Replacing the background video

Use `tools/make-bg.swift`. It needs macOS with the Xcode command-line tools, uses AVFoundation
and Core Image, and installs nothing.

```sh
swiftc -O -swift-version 5 tools/make-bg.swift -o /tmp/make-bg
/tmp/make-bg contact source.mp4 /tmp/sheet.jpg 15     # one frame every 15 s, to find a calm shot with no cuts
/tmp/make-bg preview source.mp4 /tmp/look.jpg 240 250 # preview the blurred look at those times (s)
/tmp/make-bg render  source.mp4 media 235.6 28 --speed=0.72 --sigma=0.09 --ev=-1.1 --sat=0.8 --contrast=0.92 --hi-kbps=900 --lo-kbps=320
```

`render <src> <mediaDir> <start-seconds> <duration-seconds>` rewrites `media/bg.mp4`,
`media/bg-mobile.mp4`, `media/bg-poster.jpg` and `media/bg-poster-small.jpg`. It crossfades the
end into the start so the loop has no seam. Other flags:

- `--sigma`: blur strength, as a fraction of frame height.
- `--ev`, `--sat`, `--contrast`: exposure, saturation and contrast.
- `--speed`: playback speed. Values below 1 are slower and calmer.
- `--xfade`: length of the loop crossfade, in seconds.

Keep the two videos under about 5 MB (desktop) and 2 MB (mobile).

Text contrast depends on how bright the video is. The scrim in `styles.css` (`.bg::after`) was
checked against every poster pixel and every video frame, sampled every 0.5 s:

- email: at least 7.7:1
- "being": at least 4.5:1
- footer: at least 6.0:1

If the new video is brighter, add `--ev=-1.5` or raise the scrim's `0.50` alpha.
