# Ontos Labs: stealth site

A one-page static site: logo, motto and contact address on a dark background drawn from
a plain black background. There is no build step and no
JavaScript; the folder is deployable as is.

## What's here

| Path | What it is |
| --- | --- |
| `index.html` | The page: inline SVG logo, motto, `mailto:` link, social meta tags |
| `styles.css` | Layout for phones, tablets and desktops, focus styles, print and forced colours |
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

## Background

Plain black (`--night: #000` in `styles.css`), so the white text has maximum contrast.
