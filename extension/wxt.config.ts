import { defineConfig } from 'wxt';

// See https://wxt.dev/api/config.html
export default defineConfig({
  modules: [],
  outDir: 'dist',
  manifest: {
    name: 'Link Radar',
    description: 'Save and organize links from your browser',
    permissions: ['storage', 'activeTab'],
  },
});

