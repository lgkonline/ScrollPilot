# ScrollPilot website

Static Astro site using custom CSS, bundled through Astro’s Vite pipeline. Icons come from the separate `react-bootstrap-icons` package; Bootstrap CSS and JavaScript are not used. Node.js 22.12 or newer is required.

```sh
cd website
npm ci
npm run dev
```

The development site is served at `/`. Run `npm run check` for Astro/TypeScript validation, `npm run build` to generate `dist/`, and `npm run preview` to inspect the production build.

## GitHub Pages

The [deployment workflow](../.github/workflows/website.yml) builds and deploys on changes to the website on `main`, or via a manual workflow run. In the GitHub repository, set **Settings → Pages → Build and deployment → Source** to **GitHub Actions**. The site is configured for the custom domain `https://scrollpilot.lgk.io/`.

For a different domain or repository, update `site` and `base` in [astro.config.mjs](./astro.config.mjs). For a domain served at its root, use `base: '/'`. All site styles and scripts are bundled locally; the site needs no server or external font service.

Downloads link to GitHub Releases. The device demo illustrates switching; it does not access hardware or change system settings. Animations respect reduced-motion preferences. The product currently targets macOS 27 in its Xcode project; check release compatibility before changing download copy.

## Languages

English is served at `/en/`, German at `/de/`. The root `/` is a language router: it uses a saved manual language choice first, then the first supported language in the browser’s preference list (including regional variants such as `de-CH`), falling back to English. GitHub Pages serves static files, so this redirect runs in JavaScript; without JavaScript, the root offers links to both languages. Redirects preserve query parameters and fragments and replace the root history entry. Explicit language URLs never redirect. Manual switcher choices are saved in local storage when available. The language switcher uses static links and works without JavaScript. Both routes render the shared [MarketingPage component](./src/components/MarketingPage.astro). English source strings are translation keys; their German equivalents live in [de.json](./src/i18n/de.json), with the typed translator in [i18n/index.ts](./src/i18n/index.ts). Translate new copy there and render it with `t(...)`. Demo status strings are passed through HTML data attributes so client interactions use the selected language. Each page includes its own canonical URL, language metadata, and alternate-language links.
