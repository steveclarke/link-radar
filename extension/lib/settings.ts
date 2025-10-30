/**
 * Settings management for the Link Radar extension.
 *
 * This module provides functions and constants for managing extension settings
 * stored in browser storage. Designed to work from both Vue contexts (popup,
 * options page) and non-Vue contexts (background service workers, content
 * scripts).
 *
 * Vue contexts should use the reactive composables (useEnvironment, useSettings),
 * while non-Vue contexts use the functions exported from this module directly.
 */

// ============================================================================
// Types & Interfaces
// ============================================================================

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

// ============================================================================
// Storage Keys
// ============================================================================

/**
 * Browser storage keys for local storage (stored locally, never synced).
 * Used for sensitive data like API keys that shouldn't sync across devices.
 */
export const localStorageKeys = {
  /** Environment configs (contains API keys - stored locally only) */
  environmentConfigs: "linkradar_environment_configs",
} as const

/**
 * Browser storage keys for synced storage (synced across browsers).
 * Used for user preferences that are safe to sync for convenience.
 */
export const syncedStorageKeys = {
  /** Current active environment */
  environment: "linkradar_environment",
  /** Auto-close delay setting */
  autoCloseDelay: "linkradar_auto_close_delay",
  /** Developer mode toggle */
  isDeveloperMode: "linkradar_is_developer_mode",
} as const

// ============================================================================
// Environment Configuration
// ============================================================================

/**
 * Build-time constants from Vite environment variables.
 * These are set at build time and never change at runtime.
 * Must be configured in .env file - no defaults provided.
 */
export const defaultBackendUrl = import.meta.env.VITE_BACKEND_URL
export const defaultDevBackendUrl = import.meta.env.VITE_DEV_BACKEND_URL
export const defaultDevApiKey = import.meta.env.VITE_DEV_API_KEY

/**
 * Get all environment configurations from storage. Initializes with defaults
 * on first run. Always ensures URLs and keys from env vars take precedence.
 */
export async function getEnvironmentConfigs(): Promise<EnvironmentConfigs> {
  const result = await browser.storage.local.get(localStorageKeys.environmentConfigs)
  const stored = result[localStorageKeys.environmentConfigs] as EnvironmentConfigs | undefined

  if (!stored) {
    // First run - initialize with defaults
    const defaultConfigs: EnvironmentConfigs = {
      production: { url: defaultBackendUrl, apiKey: "" },
      local: { url: defaultDevBackendUrl, apiKey: defaultDevApiKey },
      custom: { url: "", apiKey: "" },
    }
    await setEnvironmentConfigs(defaultConfigs)
    return defaultConfigs
  }

  // Merge stored values with build-time defaults
  // Build-time URLs and keys always take precedence for production/local
  return {
    production: {
      url: defaultBackendUrl,
      apiKey: stored.production.apiKey,
    },
    local: {
      url: defaultDevBackendUrl,
      apiKey: defaultDevApiKey,
    },
    custom: {
      url: stored.custom.url,
      apiKey: stored.custom.apiKey,
    },
  }
}

/**
 * Save all environment configurations to storage.
 * Only stores user-provided values (production API key, custom URL/key).
 * URLs for production/local are never stored (always from env vars).
 */
export async function setEnvironmentConfigs(configs: EnvironmentConfigs): Promise<void> {
  const configsToStore: EnvironmentConfigs = {
    production: {
      url: "",
      apiKey: configs.production.apiKey,
    },
    local: {
      url: "",
      apiKey: "",
    },
    custom: {
      url: configs.custom.url,
      apiKey: configs.custom.apiKey,
    },
  }

  await browser.storage.local.set({
    [localStorageKeys.environmentConfigs]: configsToStore,
  })
}

/**
 * Get the currently selected environment from storage.
 * Returns "production" when not configured (default for end users).
 */
export async function getEnvironment(): Promise<Environment> {
  const result = await browser.storage.sync.get(syncedStorageKeys.environment)
  return (result[syncedStorageKeys.environment] as Environment) ?? "production"
}

/**
 * Set the currently selected environment in storage.
 */
export async function setEnvironment(environment: Environment): Promise<void> {
  await browser.storage.sync.set({
    [syncedStorageKeys.environment]: environment,
  })
}

/**
 * Get the configuration for the currently active environment.
 * Combines the active environment selection with its configuration.
 */
export async function getActiveEnvironmentConfig(): Promise<EnvironmentConfig> {
  const environment = await getEnvironment()
  const configs = await getEnvironmentConfigs()
  return configs[environment]
}

// ============================================================================
// App Behavior Settings
// ============================================================================

/**
 * Default auto-close delay in milliseconds for the popup after successful operations.
 * 0 = disabled (popup stays open)
 */
export const defaultAutoCloseDelay = 500

/**
 * Maximum allowed auto-close delay in milliseconds.
 * Prevents users from setting unreasonably long delays.
 */
export const maxAutoCloseDelay = 2000

/**
 * Get the auto-close delay setting from storage.
 * Returns the default value (500ms) when not configured.
 */
export async function getAutoCloseDelay(): Promise<number> {
  const result = await browser.storage.sync.get(syncedStorageKeys.autoCloseDelay)
  return result[syncedStorageKeys.autoCloseDelay] ?? defaultAutoCloseDelay
}

/**
 * Set the auto-close delay setting in storage.
 * @param delay - Delay in milliseconds (0 = disabled)
 */
export async function setAutoCloseDelay(delay: number): Promise<void> {
  await browser.storage.sync.set({
    [syncedStorageKeys.autoCloseDelay]: delay,
  })
}

/**
 * Get the developer mode setting from storage.
 * Returns false when not configured (disabled by default).
 */
export async function getDeveloperMode(): Promise<boolean> {
  const result = await browser.storage.sync.get(syncedStorageKeys.isDeveloperMode)
  return result[syncedStorageKeys.isDeveloperMode] ?? false
}

/**
 * Set the developer mode setting in storage.
 * @param enabled - Whether developer mode is enabled
 */
export async function setDeveloperMode(enabled: boolean): Promise<void> {
  await browser.storage.sync.set({
    [syncedStorageKeys.isDeveloperMode]: enabled,
  })
}
