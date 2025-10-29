import tailwindcss from "@tailwindcss/vite"
import { defineConfig } from "wxt"

// See https://wxt.dev/api/config.html
export default defineConfig({
  modules: ["@wxt-dev/module-vue"],
  outDir: "dist",
  vite: () => ({
    plugins: [
      tailwindcss(),
    ],
  }),
  manifest: {
    name: "Link Radar",
    description: "Save and organize links from your browser",
    permissions: ["storage", "activeTab"],
    icons: {
      16: "icon/16.png",
      32: "icon/32.png",
      48: "icon/48.png",
      128: "icon/128.png",
    },
  },
  // Browser startup configuration for development
  runner: {
    chromiumArgs: ["--user-data-dir=./.wxt/chrome-data"],
  },
  // Use port 9001 for extension dev server (9000 reserved for web app)
  dev: {
    server: {
      port: 9001,
    },
  },
})
