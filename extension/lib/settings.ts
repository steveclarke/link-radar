/**
 * Settings management for the Link Radar extension.
 * Provides configuration constants and functions to get/set user preferences
 * stored in browser.storage.sync.
 *
 * Uses environment profiles where each environment (production, local, custom)
 * has its own backend URL and API key configuration.
 */

/**
 * Backend environment types
 */
export type BackendEnvironment = "production" | "local" | "custom"

/**
 * Environment profile containing URL and API key for a specific environment
 */
export interface EnvironmentProfile {
  /** Backend API URL for this environment */
  url: string
  /** API key for this environment */
  apiKey: string
}

/**
 * Collection of environment profiles for all supported environments
 */
export interface EnvironmentProfiles {
  production: EnvironmentProfile
  local: EnvironmentProfile
  custom: EnvironmentProfile
}

/**
 * Default auto-close delay in milliseconds for the popup after successful operations.
 * 0 = disabled (popup stays open)
 */
export const DEFAULT_AUTO_CLOSE_DELAY = 500

/**
 * Browser storage keys for persisting user settings
 */
export const STORAGE_KEYS = {
  /** Current active environment */
  BACKEND_ENVIRONMENT: "linkradar_backend_environment",
  /** Environment profiles (all URLs and API keys) */
  ENVIRONMENT_PROFILES: "linkradar_environment_profiles",
  /** Auto-close delay setting */
  AUTO_CLOSE_DELAY: "linkradar_auto_close_delay",
  /** Developer mode toggle */
  DEVELOPER_MODE: "linkradar_developer_mode",
} as const

/**
 * Production backend URL from environment variables.
 * Can be overridden at build time using VITE_BACKEND_URL environment variable.
 */
export const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || "http://localhost:3000/api/v1"

/**
 * Local development backend URL from environment variables.
 * Can be overridden at build time using VITE_DEV_BACKEND_URL environment variable.
 */
export const DEV_BACKEND_URL = import.meta.env.VITE_DEV_BACKEND_URL || "http://localhost:3000/api/v1"

/**
 * Development API key from environment variables.
 * Can be overridden at build time using VITE_DEV_API_KEY environment variable.
 */
export const DEV_API_KEY = import.meta.env.VITE_DEV_API_KEY || "dev_api_key_change_in_production"

/**
 * Initialize default environment profiles from environment variables.
 * Called on first run or when profiles don't exist in storage.
 */
export function initializeProfiles(): EnvironmentProfiles {
  return {
    production: {
      url: BACKEND_URL,
      apiKey: "", // User must configure
    },
    local: {
      url: DEV_BACKEND_URL,
      apiKey: DEV_API_KEY, // Default from env vars
    },
    custom: {
      url: "", // User must configure
      apiKey: "", // User must configure
    },
  }
}

/**
 * Get all environment profiles from storage.
 * Initializes with defaults on first run.
 */
export async function getProfiles(): Promise<EnvironmentProfiles> {
  const result = await browser.storage.sync.get(STORAGE_KEYS.ENVIRONMENT_PROFILES)
  const profiles = result[STORAGE_KEYS.ENVIRONMENT_PROFILES] as EnvironmentProfiles | undefined

  if (!profiles) {
    // First run - initialize with defaults
    const defaultProfiles = initializeProfiles()
    await setProfiles(defaultProfiles)
    return defaultProfiles
  }

  return profiles
}

/**
 * Save all environment profiles to storage.
 */
export async function setProfiles(profiles: EnvironmentProfiles): Promise<void> {
  await browser.storage.sync.set({ [STORAGE_KEYS.ENVIRONMENT_PROFILES]: profiles })
}

/**
 * Get the profile for a specific environment.
 */
export async function getProfile(environment: BackendEnvironment): Promise<EnvironmentProfile> {
  const profiles = await getProfiles()
  return profiles[environment]
}

/**
 * Get the profile for the currently active environment.
 */
export async function getActiveProfile(): Promise<EnvironmentProfile> {
  const environment = await getBackendEnvironment()
  return getProfile(environment)
}

/**
 * Set the API key for a specific environment.
 */
export async function setProfileApiKey(environment: BackendEnvironment, apiKey: string): Promise<void> {
  const profiles = await getProfiles()
  profiles[environment].apiKey = apiKey
  await setProfiles(profiles)
}

/**
 * Set the URL for a specific environment.
 * Typically only used for the "custom" environment.
 */
export async function setProfileUrl(environment: BackendEnvironment, url: string): Promise<void> {
  const profiles = await getProfiles()
  profiles[environment].url = url
  await setProfiles(profiles)
}

/**
 * Read the backend environment setting from browser sync storage.
 * Returns "local" when not configured (default for development).
 */
export async function getBackendEnvironment(): Promise<BackendEnvironment> {
  const result = await browser.storage.sync.get(STORAGE_KEYS.BACKEND_ENVIRONMENT)
  return (result[STORAGE_KEYS.BACKEND_ENVIRONMENT] as BackendEnvironment) ?? "local"
}

/**
 * Persist the backend environment setting to browser sync storage.
 * @param environment - The backend environment to use
 */
export async function setBackendEnvironment(environment: BackendEnvironment): Promise<void> {
  await browser.storage.sync.set({ [STORAGE_KEYS.BACKEND_ENVIRONMENT]: environment })
}

/**
 * Get the active backend URL based on the current environment's profile.
 */
export async function getActiveBackendUrl(): Promise<string> {
  const profile = await getActiveProfile()
  return profile.url
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
