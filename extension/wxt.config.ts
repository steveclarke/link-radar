import { defineConfig } from 'wxt';

// See https://wxt.dev/api/config.html
export default defineConfig({
  modules: ['@wxt-dev/module-vue'],
  outDir: 'dist',
  manifest: {
    name: 'Link Radar',
    description: 'Save and organize links from your browser',
    permissions: ['storage', 'activeTab'],
  },
  // Browser startup configuration for development
  runner: {
    chromiumArgs: ['--user-data-dir=./.wxt/chrome-data'],
  },
  // Use port 9001 for extension dev server (9000 reserved for web app)
  dev: {
    server: {
      port: 9001,
    },
  },
});

