/**
 * Settings management for the Link Radar extension.
 * Provides configuration constants and functions to get/set user preferences
 * stored in browser.storage.sync.
 *
 * Uses environment profiles where each environment (production, local, custom)
 * has its own backend URL and API key configuration.
 */

/**
 * Environment types for backend configurations
 */
export type Environment = "production" | "local" | "custom"

/**
 * Environment configuration containing URL and API key for a specific environment
 */
export interface EnvironmentConfig {
  /** Backend API URL for this environment */
  url: string
  /** API key for this environment */
  apiKey: string
}

/**
 * Collection of environment configurations for all supported environments
 */
export interface EnvironmentConfigs {
  production: EnvironmentConfig
  local: EnvironmentConfig
  custom: EnvironmentConfig
}

/**
 * Default auto-close delay in milliseconds for the popup after successful operations.
 * 0 = disabled (popup stays open)
 */
export const DEFAULT_AUTO_CLOSE_DELAY = 500

/**
 * Maximum allowed auto-close delay in milliseconds.
 * Prevents users from setting unreasonably long delays.
 */
export const MAX_AUTO_CLOSE_DELAY = 2000

/**
 * Browser storage keys for sensitive data (stored locally, never synced).
 * API keys and credentials should never sync across devices for security.
 */
export const SENSITIVE_STORAGE_KEYS = {
  /** Environment profiles (contains API keys - stored locally only) */
  ENVIRONMENT_PROFILES: "linkradar_environment_profiles",
} as const

/**
 * Browser storage keys for non-sensitive settings (synced across browsers).
 * User preferences that are safe to sync for convenience.
 */
export const SYNC_STORAGE_KEYS = {
  /** Current active environment */
  BACKEND_ENVIRONMENT: "linkradar_backend_environment",
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
 * Initialize default environment configurations from environment variables.
 * Called on first run or when configs don't exist in storage.
 */
export function initializeConfigs(): EnvironmentConfigs {
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
 * Get all environment configurations from storage.
 * Initializes with defaults on first run.
 * Always ensures URLs come from environment variables.
 */
export async function getConfigs(): Promise<EnvironmentConfigs> {
  const result = await browser.storage.local.get(SENSITIVE_STORAGE_KEYS.ENVIRONMENT_PROFILES)
  let configs = result[SENSITIVE_STORAGE_KEYS.ENVIRONMENT_PROFILES] as EnvironmentConfigs | undefined

  if (!configs) {
    // First run - initialize with defaults
    const defaultConfigs = initializeConfigs()
    await setConfigs(defaultConfigs)
    return defaultConfigs
  }

  // Always override URLs and keys that come from environment variables
  // This ensures they're always current with build-time configuration
  return {
    production: {
      url: BACKEND_URL,                    // Always from env var
      apiKey: configs.production.apiKey,    // From user input (stored)
    },
    local: {
      url: DEV_BACKEND_URL,                // Always from env var
      apiKey: DEV_API_KEY,                 // Always from env var
    },
    custom: {
      url: configs.custom.url,             // From user input (stored)
      apiKey: configs.custom.apiKey,        // From user input (stored)
    },
  }
}

/**
 * Save all environment configurations to storage.
 * Only stores user-provided values (production API key, custom URL/key).
 * URLs for production/local are never stored (always from env vars).
 */
export async function setConfigs(configs: EnvironmentConfigs): Promise<void> {
  // Only save user-editable fields to storage
  // Production and local URLs always come from env vars, not storage
  const configsToStore: EnvironmentConfigs = {
    production: {
      url: "", // Not stored - always from BACKEND_URL env var
      apiKey: configs.production.apiKey, // User input
    },
    local: {
      url: "", // Not stored - always from DEV_BACKEND_URL env var
      apiKey: "", // Not stored - always from DEV_API_KEY env var
    },
    custom: {
      url: configs.custom.url, // User input
      apiKey: configs.custom.apiKey, // User input
    },
  }

  await browser.storage.local.set({ [SENSITIVE_STORAGE_KEYS.ENVIRONMENT_PROFILES]: configsToStore })
}

/**
 * Get the configuration for a specific environment.
 */
export async function getConfig(environment: Environment): Promise<EnvironmentConfig> {
  const configs = await getConfigs()
  return configs[environment]
}

/**
 * Get the configuration for the currently active environment.
 */
export async function getActiveConfig(): Promise<EnvironmentConfig> {
  const environment = await getEnvironment()
  return getConfig(environment)
}

/**
 * Set the API key for a specific environment.
 */
export async function setConfigApiKey(environment: Environment, apiKey: string): Promise<void> {
  const configs = await getConfigs()
  configs[environment].apiKey = apiKey
  await setConfigs(configs)
}

/**
 * Set the URL for a specific environment.
 * Typically only used for the "custom" environment.
 */
export async function setConfigUrl(environment: Environment, url: string): Promise<void> {
  const configs = await getConfigs()
  configs[environment].url = url
  await setConfigs(configs)
}

/**
 * Read the environment setting from browser sync storage.
 * Returns "production" when not configured (default for end users).
 */
export async function getEnvironment(): Promise<Environment> {
  const result = await browser.storage.sync.get(SYNC_STORAGE_KEYS.BACKEND_ENVIRONMENT)
  return (result[SYNC_STORAGE_KEYS.BACKEND_ENVIRONMENT] as Environment) ?? "production"
}

/**
 * Persist the environment setting to browser sync storage.
 * @param environment - The environment to use
 */
export async function setEnvironment(environment: Environment): Promise<void> {
  await browser.storage.sync.set({ [SYNC_STORAGE_KEYS.BACKEND_ENVIRONMENT]: environment })
}

/**
 * Get the active backend URL based on the current environment's configuration.
 */
export async function getActiveBackendUrl(): Promise<string> {
  const config = await getActiveConfig()
  return config.url
}

/**
 * Read the auto-close delay from browser sync storage.
 * Returns the default value (500ms) when not configured.
 */
export async function getAutoCloseDelay(): Promise<number> {
  const result = await browser.storage.sync.get(SYNC_STORAGE_KEYS.AUTO_CLOSE_DELAY)
  return result[SYNC_STORAGE_KEYS.AUTO_CLOSE_DELAY] ?? DEFAULT_AUTO_CLOSE_DELAY
}

/**
 * Persist the auto-close delay to browser sync storage.
 * @param delay - Delay in milliseconds (0 = disabled)
 */
export async function setAutoCloseDelay(delay: number): Promise<void> {
  await browser.storage.sync.set({ [SYNC_STORAGE_KEYS.AUTO_CLOSE_DELAY]: delay })
}

/**
 * Read the developer mode setting from browser sync storage.
 * Returns false when not configured (disabled by default).
 */
export async function getDeveloperMode(): Promise<boolean> {
  const result = await browser.storage.sync.get(SYNC_STORAGE_KEYS.DEVELOPER_MODE)
  return result[SYNC_STORAGE_KEYS.DEVELOPER_MODE] ?? false
}

/**
 * Persist the developer mode setting to browser sync storage.
 * @param enabled - Whether developer mode is enabled
 */
export async function setDeveloperMode(enabled: boolean): Promise<void> {
  await browser.storage.sync.set({ [SYNC_STORAGE_KEYS.DEVELOPER_MODE]: enabled })
}
