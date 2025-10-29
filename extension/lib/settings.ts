/**
 * Settings management for the Link Radar extension.
 * Provides configuration constants and functions to get/set user preferences
 * stored in browser.storage.sync.
 */

/**
 * Backend API base URL (without endpoint path)
 * Append specific endpoints like `/links` when making requests
 * Can be overridden at build time using VITE_BACKEND_URL environment variable
 * Example: VITE_BACKEND_URL=http://localhost:3001/api/v1 pnpm build
 */
export const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || "http://localhost:3000/api/v1"

/**
 * Local development backend URL
 */
export const LOCAL_DEV_BACKEND_URL = "http://localhost:3000/api/v1"

/**
 * Default auto-close delay in milliseconds for the popup after successful operations.
 * 0 = disabled (popup stays open)
 */
export const DEFAULT_AUTO_CLOSE_DELAY = 500

/**
 * Backend environment types
 */
export type BackendEnvironment = "production" | "local" | "custom"

/**
 * Browser storage keys for persisting user settings
 */
export const STORAGE_KEYS = {
  API_KEY: "linkradar_api_key",
  AUTO_CLOSE_DELAY: "linkradar_auto_close_delay",
  DEVELOPER_MODE: "linkradar_developer_mode",
  BACKEND_ENVIRONMENT: "linkradar_backend_environment",
  CUSTOM_BACKEND_URL: "linkradar_custom_backend_url",
} as const

/**
 * Read the API key from browser sync storage.
 * Returns undefined when not configured.
 */
export async function getApiKey(): Promise<string | undefined> {
  const result = await browser.storage.sync.get(STORAGE_KEYS.API_KEY)
  return result[STORAGE_KEYS.API_KEY]
}

/**
 * Persist the API key to browser sync storage.
 */
export async function setApiKey(apiKey: string): Promise<void> {
  await browser.storage.sync.set({ [STORAGE_KEYS.API_KEY]: apiKey })
}

/**
 * Read the auto-close delay from browser sync storage.
 * Returns the default value (500ms) when not configured.
 */
export async function getAutoCloseDelay(): Promise<number> {
  const result = await browser.storage.sync.get(STORAGE_KEYS.AUTO_CLOSE_DELAY)
  return result[STORAGE_KEYS.AUTO_CLOSE_DELAY] ?? DEFAULT_AUTO_CLOSE_DELAY
}

/**
 * Persist the auto-close delay to browser sync storage.
 * @param delay - Delay in milliseconds (0 = disabled)
 */
export async function setAutoCloseDelay(delay: number): Promise<void> {
  await browser.storage.sync.set({ [STORAGE_KEYS.AUTO_CLOSE_DELAY]: delay })
}

/**
 * Read the developer mode setting from browser sync storage.
 * Returns false when not configured (disabled by default).
 */
export async function getDeveloperMode(): Promise<boolean> {
  const result = await browser.storage.sync.get(STORAGE_KEYS.DEVELOPER_MODE)
  return result[STORAGE_KEYS.DEVELOPER_MODE] ?? false
}

/**
 * Persist the developer mode setting to browser sync storage.
 * @param enabled - Whether developer mode is enabled
 */
export async function setDeveloperMode(enabled: boolean): Promise<void> {
  await browser.storage.sync.set({ [STORAGE_KEYS.DEVELOPER_MODE]: enabled })
}

/**
 * Read the backend environment setting from browser sync storage.
 * Returns "production" when not configured (default).
 */
export async function getBackendEnvironment(): Promise<BackendEnvironment> {
  const result = await browser.storage.sync.get(STORAGE_KEYS.BACKEND_ENVIRONMENT)
  return (result[STORAGE_KEYS.BACKEND_ENVIRONMENT] as BackendEnvironment) ?? "production"
}

/**
 * Persist the backend environment setting to browser sync storage.
 * @param environment - The backend environment to use
 */
export async function setBackendEnvironment(environment: BackendEnvironment): Promise<void> {
  await browser.storage.sync.set({ [STORAGE_KEYS.BACKEND_ENVIRONMENT]: environment })
}

/**
 * Read the custom backend URL from browser sync storage.
 * Returns empty string when not configured.
 */
export async function getCustomBackendUrl(): Promise<string> {
  const result = await browser.storage.sync.get(STORAGE_KEYS.CUSTOM_BACKEND_URL)
  return result[STORAGE_KEYS.CUSTOM_BACKEND_URL] ?? ""
}

/**
 * Persist the custom backend URL to browser sync storage.
 * @param url - The custom backend URL
 */
export async function setCustomBackendUrl(url: string): Promise<void> {
  await browser.storage.sync.set({ [STORAGE_KEYS.CUSTOM_BACKEND_URL]: url })
}

/**
 * Get the active backend URL based on the current environment setting.
 * Returns the appropriate URL for production, local development, or custom environment.
 */
export async function getActiveBackendUrl(): Promise<string> {
  const environment = await getBackendEnvironment()

  switch (environment) {
    case "local":
      return LOCAL_DEV_BACKEND_URL
    case "custom": {
      const customUrl = await getCustomBackendUrl()
      return customUrl || BACKEND_URL // Fallback to production if custom URL not set
    }
    case "production":
    default:
      return BACKEND_URL
  }
}
