import { defineConfig } from "astro/config";

import react from "@astrojs/react";

export default defineConfig({
  site: "https://scrollpilot.lgk.io",
  output: "static",
  trailingSlash: "always",

  i18n: {
    defaultLocale: "en",
    locales: ["en", "de"],
    routing: { prefixDefaultLocale: false },
  },

  integrations: [react()],
});