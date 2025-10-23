# Link Radar Extension

A Chrome extension for saving and organizing links from your browser.

## Setup

This extension was created using [WXT](https://wxt.dev/), a next-generation framework for building web extensions, with Vue 3 for the UI.

### Prerequisites

- Node.js 18+
- pnpm 10.10.0+

### Installation

```bash
pnpm install
```

## Development

Start the development server:

```bash
pnpm dev
```

This will:
- Build the extension in development mode
- Watch for file changes
- Automatically reload the extension
- Start the dev server on port 9001

To load the extension in Chrome:
1. Open Chrome and navigate to `chrome://extensions/`
2. Enable "Developer mode" (toggle in top right)
3. Click "Load unpacked"
4. Select the `dist/chrome-mv3-dev` directory from this project

For Firefox development:
```bash
pnpm dev:firefox
```

## Building

Build for production:

```bash
pnpm build              # Chrome
pnpm build:firefox      # Firefox
```

The built extension will be in the `dist/chrome-mv3` (or `dist/firefox-mv2`) directory.

Create a distributable ZIP:

```bash
pnpm zip                # Chrome
pnpm zip:firefox        # Firefox
```

## Project Structure

- `entrypoints/` - Extension entry points (popup, background, content scripts)
  - `popup/` - Vue 3 popup UI when clicking the extension icon
    - `App.vue` - Main popup component
    - `main.ts` - Vue app initialization
    - `index.html` - Popup HTML template
  - `background.ts` - Background service worker
- `public/` - Static assets (icons, etc.)
- `wxt.config.ts` - WXT configuration
- `tsconfig.json` - TypeScript configuration

## Tech Stack

- **Framework:** WXT 0.20.11
- **UI:** Vue 3.5 with Composition API
- **TypeScript:** Chrome extension types included (@types/chrome)
- **Utilities:** @vueuse/core for composables (clipboard, etc.)

## Backend Integration

The extension is designed to work with the Link Radar Rails backend API running at `http://localhost:3000/api/v1/links`.

Make sure the backend is running before testing link saving functionality.

## Learn More

- [WXT Documentation](https://wxt.dev/)
- [Chrome Extension API](https://developer.chrome.com/docs/extensions/)

