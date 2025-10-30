/**
 * Background script for LinkRadar browser extension.
 *
 * This service worker is currently reserved for future background tasks such as:
 * - Background sync: Periodic syncing of links when the popup is closed
 * - Notifications: Browser event listeners (tabs, bookmarks) that trigger actions
 * - WebSocket connections: Maintaining persistent connections to the backend
 * - Cross-context coordination: Managing state shared across popup, options, and content scripts
 *
 * Note: API calls are made directly from the popup/options pages for simplicity and performance.
 */
export default defineBackground(() => {
  // Background service worker initialized and ready for future background tasks
})
