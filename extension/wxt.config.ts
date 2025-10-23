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
});

