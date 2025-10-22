# Link Radar Extension

A Chrome extension for saving and organizing links from your browser.

## Setup

This extension was created using [WXT](https://wxt.dev/), a next-generation framework for building web extensions.

### Prerequisites

- Node.js 18+
- pnpm 10+

### Installation

```bash
pnpm install
```

**Note:** Due to a known issue with WXT 0.20.11, we use a pnpm override to pin `@wxt-dev/storage` to version 1.2.0. This is defined in `package.json` and should work automatically.

## Development

Start the development server:

```bash
pnpm dev
```

This will:
- Build the extension in development mode
- Watch for file changes
- Automatically reload the extension

To load the extension in Chrome:
1. Open Chrome and navigate to `chrome://extensions/`
2. Enable "Developer mode" (toggle in top right)
3. Click "Load unpacked"
4. Select the `dist/chrome-mv3` directory from this project

## Building

Build for production:

```bash
pnpm build
```

The built extension will be in the `dist/chrome-mv3` directory.

## Project Structure

- `entrypoints/` - Extension entry points (popup, background, content scripts)
  - `popup/` - Popup UI when clicking the extension icon
  - `background.ts` - Background service worker
- `public/` - Static assets (icons, etc.)
- `wxt.config.ts` - WXT configuration
- `tsconfig.json` - TypeScript configuration

## Backend Integration

The extension is designed to work with the Link Radar Rails backend API running at `http://localhost:3000/api/v1/links`.

Make sure the backend is running before testing link saving functionality.

## Learn More

- [WXT Documentation](https://wxt.dev/)
- [Chrome Extension API](https://developer.chrome.com/docs/extensions/)

