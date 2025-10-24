# Link Radar Extension

A Chrome extension for saving and organizing links from your browser.

## Setup

This extension was created using [WXT](https://wxt.dev/), a next-generation framework for building web extensions, with Vue 3 for the UI.

### Prerequisites

- Node.js 18+
- pnpm 10.10.0+

### Installation

```bash
# Run the setup script to initialize .env from template
bin/setup

# Install dependencies
pnpm install
```

The setup script will automatically create a `.env` file from `.env.template` if it doesn't exist.

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
  - `options/` - Extension settings/configuration page
    - `Options.vue` - Settings UI component
    - `main.ts` - Vue app initialization
    - `index.html` - Options page HTML
    - `style.css` - Styles for options page
  - `background.ts` - Background service worker
- `lib/` - Shared utilities and configuration
  - `config.ts` - Configuration constants (API URL, storage keys)
- `public/` - Static assets (icons, etc.)
- `wxt.config.ts` - WXT configuration
- `tsconfig.json` - TypeScript configuration

## Tech Stack

- **Framework:** WXT 0.20.11
- **UI:** Vue 3.5 with Composition API
- **TypeScript:** Chrome extension types included (@types/chrome)
- **Utilities:** @vueuse/core for composables (clipboard, etc.)

## Configuration

### API Key Setup

Before using the extension, you need to configure your API key:

1. Click the extension icon in your browser toolbar
2. Click the settings gear icon (⚙️) in the top right
3. Enter your API key from the backend configuration
4. Click "Save Settings"

The API key is stored securely in your browser's sync storage and will sync across your devices.

**Default Development API Key:**
```
dev_api_key_change_in_production
```

This is the default API key configured in the backend's `config/core.yml` file for development. You can copy and paste this into the extension settings to get started quickly.

### Backend URL Configuration

By default, the extension connects to `http://localhost:3000/api/v1` (base API URL).

For custom port configurations or production deployments, you can override the backend URL using the `VITE_BACKEND_URL` environment variable:

**Option 1: Create a `.env` file (Recommended for Development)**

The setup script will create a `.env` file from `.env.template`. Edit this file to set your backend URL:

```bash
# .env
VITE_BACKEND_URL=http://localhost:3001/api/v1
```

**Option 2: Set at Build Time**

```bash
# Build for production with custom backend URL
VITE_BACKEND_URL=https://api.linkradar.com/api/v1 pnpm build

# Build for staging
VITE_BACKEND_URL=https://staging-api.linkradar.com/api/v1 pnpm build

# Development with custom port
VITE_BACKEND_URL=http://localhost:3001/api/v1 pnpm dev
```

**Note:** The `BACKEND_URL` is the base API path. Specific endpoints (like `/links`) are appended automatically when making requests. The backend URL is configured in `lib/config.ts` and is compiled into the extension at build time.

## Backend Integration

The extension is designed to work with the Link Radar Rails backend API at `http://localhost:3000/api/v1` by default.

**If your backend is running on a different port:**
1. Edit the `.env` file in the extension directory
2. Set `VITE_BACKEND_URL=http://localhost:YOUR_PORT/api/v1`
3. Restart the development server

Make sure the backend is running and you have configured your API key in the extension settings before testing link saving functionality.

## Learn More

- [WXT Documentation](https://wxt.dev/)
- [Chrome Extension API](https://developer.chrome.com/docs/extensions/)
