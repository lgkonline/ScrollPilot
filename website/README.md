# ScrollPilot website

Static Astro site using Bootstrap 6.0.0-alpha.1, compiled from Sass through Astro’s Vite pipeline. Node.js 22.12 or newer is required.

```sh
cd website
npm ci
npm run dev
```

The development URL includes `/ScrollPilot/`. Run `npm run check` for Astro/TypeScript validation, `npm run build` to generate `dist/`, and `npm run preview` to inspect the production build.

## GitHub Pages

The [deployment workflow](../.github/workflows/website.yml) builds and deploys on changes to the website on `main`, or via a manual workflow run. In the GitHub repository, set **Settings → Pages → Build and deployment → Source** to **GitHub Actions**. The resulting URL is `https://lgkonline.github.io/ScrollPilot/`.

For a custom domain or different repository, update `site` and `base` in [astro.config.mjs](./astro.config.mjs). For a domain served at its root, use `base: '/'`. All site styles and scripts are bundled locally; the site needs no server or external font service.

Downloads link to GitHub Releases. The device demo illustrates switching; it does not access hardware or change system settings. Animations respect reduced-motion preferences. The product currently targets macOS 27 in its Xcode project; check release compatibility before changing download copy.

## Languages

English is served at `/ScrollPilot/`, German at `/ScrollPilot/de/`. The language switcher uses static links and works without JavaScript. Both routes render the shared [MarketingPage component](./src/components/MarketingPage.astro). English source strings are translation keys; their German equivalents live in [de.json](./src/i18n/de.json), with the typed translator in [i18n/index.ts](./src/i18n/index.ts). Translate new copy there and render it with `t(...)`. Demo status strings are passed through HTML data attributes so client interactions use the selected language. Each page includes its own canonical URL, language metadata, and alternate-language links.
