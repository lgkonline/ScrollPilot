import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://lgkonline.github.io',
  base: '/ScrollPilot',
  output: 'static',
  trailingSlash: 'always',
  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'de'],
    routing: { prefixDefaultLocale: false },
  },
});
