# Ontos Labs: stealth site

A one-page static site: logo, motto and contact address on a dark background drawn from
the Ontos orbit (the rings of the logo mark, scaled up). There is no build step and no
JavaScript; the folder is deployable as is.

## What's here

| Path | What it is |
| --- | --- |
| `index.html` | The page: inline SVG logo, motto, `mailto:` link, inline SVG orbit background, social meta tags |
| `styles.css` | Layout for phones, tablets and desktops, orbit sizing, text halo, focus styles, print and forced colours |
| `media/og.jpg` | 1200x630 preview image for link sharing (a render of the page) |
| `favicon.*`, `apple-touch-icon.png` | Icons |
| `.nojekyll` | Tells GitHub Pages to serve the files exactly as they are |

The page makes no external requests: no fonts, analytics or CDNs. Nothing on it moves.

## Publish in 2 minutes (GitHub web UI)

1. Go to <https://github.com/new>, choose a repository name (for example `ontoslabs-site`), and
   make it **Public**. On a free plan, Pages only works for public repos. Click **Create repository**.
2. On the new repo page, click **uploading an existing file**. Drag in the **contents** of this
   folder (`index.html`, `styles.css`, the icons, `.nojekyll`, and the `media/` folder),
   not the folder itself. `index.html` must be at the top level of the repo. Click **Commit changes**.
   The browser may hide `.nojekyll` because it starts with a dot. The site works without it.
   `README.md` is optional. Anything you upload to a public repo is public.
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

## The orbit background

The background is the logo mark's outer ring (rx 26, ry 17.5) and middle ring (rx 16.5,
ry 11), drawn as one inline SVG in `index.html` with `viewBox="-26 -17.5 52 35"`. The
mark's filled inner ellipse becomes a faint blue glow behind the text.

- **Position:** centred on the text block (`.orbit` in `styles.css`, using the same safe-area
  padding as the body and the 2.75rem footer height).
- **Size:** `--r` is the middle ring's horizontal radius. In landscape (wider than 11:10) it is
  `max(7 x motto size, 0.656 x stage height)`: the middle ring fills about 7/8 of the stage
  height and always clears the motto, and the outer ring runs off the top and bottom and cuts
  the corners. In portrait the rings run off the sides; `--r` keeps the outer ring's lower arc
  above the footer (a 1.5rem gap, shrinking towards 0.25rem on short phones such as 320x568 so the
  middle ring still clears the logo by about 18px).
- **Strokes:** 1.25px at any size (`vector-effect: non-scaling-stroke`), in `--ring`
  (`#aebff0` at 17%) and `--ring-outer` (13%).
- **Clean text:** no ring passes behind the logo, motto, email or footer at any screen shape that
  was checked: 320x568, 360x640, 375x667, 390x844, 430x932, 844x390, 768x1024, 1024x1366,
  1280x800, 1440x900, 1920x1080 and 2560x1440 (closest approach: 18px, logo at 320x568).
  `.core::before` is also a soft plate of the page colour drawn above the rings, so no line
  can show through the words even on unusual screen shapes. Contrast on the plate: text
  16:1, "being" 9.7:1, footer 10.7:1.

To change how the orbit looks, edit `--ring`, `--ring-outer` and `--night`. After any
visual change, re-render `media/og.jpg` at 1200x630.
