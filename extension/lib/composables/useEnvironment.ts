/**
 * @fileoverview Reactive environment composable with cross-tab synchronization.
 * Provides singleton state management for all backend environment configuration
 * including environment selection, API endpoints, and UI badge styling.
 *
 * This composable establishes the architectural pattern for environment management:
 * - Vue contexts use this composable for reactive environment state
 * - Non-Vue contexts (service workers, background scripts) use settings.ts functions
 * - Both stay synchronized via browser storage events
 */

import type { Environment, EnvironmentConfig, EnvironmentConfigs } from "../settings"
import { computed, effectScope, ref } from "vue"
import {
  getConfigs,
  getEnvironment,
  SENSITIVE_STORAGE_KEYS,
  setConfigs,
  setEnvironment,
  SYNC_STORAGE_KEYS,
} from "../settings"

/**
 * Configuration object for environment badge styling and display
 */
export interface EnvironmentBadgeConfig {
  /** Icon name from Material Symbols */
  icon: string
  /** Hex color for the icon */
  iconColor: string
  /** Display label for the environment */
  label: string
  /** Tailwind background color class */
  bgColor: string
  /** Tailwind text color class */
  textColor: string
  /** Tailwind border color class */
  borderColor: string
}

/**
 * Environment badge configuration lookup.
 * Provides consistent styling across all environment-related UI components.
 */
export const ENVIRONMENT_BADGE_CONFIGS: Record<Environment, EnvironmentBadgeConfig> = {
  production: {
    icon: "material-symbols:circle",
    iconColor: "#22c55e", // green-500
    label: "Production",
    bgColor: "bg-green-100",
    textColor: "text-green-800",
    borderColor: "border-green-300",
  },
  local: {
    icon: "material-symbols:circle",
    iconColor: "#eab308", // yellow-500
    label: "Local Dev",
    bgColor: "bg-yellow-100",
    textColor: "text-yellow-800",
    borderColor: "border-yellow-300",
  },
  custom: {
    icon: "material-symbols:circle",
    iconColor: "#3b82f6", // blue-500
    label: "Custom",
    bgColor: "bg-blue-100",
    textColor: "text-blue-800",
    borderColor: "border-blue-300",
  },
}

// Singleton state - shared across all component instances
let isInitialized = false
// Effect scope for managing lifecycle of watchers and listeners
let scope: ReturnType<typeof effectScope> | null = null

const environment = ref<Environment>("production")
const environmentConfigs = ref<EnvironmentConfigs>({
  production: { url: "", apiKey: "" },
  local: { url: "", apiKey: "" },
  custom: { url: "", apiKey: "" },
})

/**
 * Computed property for the currently active environment configuration.
 * Automatically updates when environment or configs change.
 */
const environmentConfig = computed<EnvironmentConfig | null>(() => {
  if (!environment.value)
    return null
  return environmentConfigs.value[environment.value]
})

/**
 * Computed property that determines if the app is configured and ready to use.
 * Checks if the active environment has an API key set.
 */
const isAppConfigured = computed<boolean>(() => {
  return !!environmentConfig.value?.apiKey
})

/**
 * Load all environment settings from browser storage.
 * Called once during initialization.
 */
async function loadAllEnvironmentSettings() {
  try {
    environmentConfigs.value = await getConfigs()
    environment.value = await getEnvironment()
  }
  catch (error) {
    console.error("Error loading environment settings:", error)
  }
}

/**
 * Local storage change handler for cross-tab synchronization.
 * Reloads environment configs when they change in another tab.
 * Type-safe handler that only processes known storage keys.
 */
async function handleLocalStorageChange(changes: Record<string, chrome.storage.StorageChange>) {
  try {
    // Type narrowing: only handle known keys
    const profileChange = changes[SENSITIVE_STORAGE_KEYS.ENVIRONMENT_PROFILES]
    if (profileChange) {
      environmentConfigs.value = await getConfigs()
    }
  }
  catch (error) {
    console.error("Error handling local storage change:", error)
  }
}

/**
 * Sync storage change handler for cross-tab synchronization.
 * Reloads environment setting when it changes in another tab.
 * Type-safe handler that only processes known storage keys.
 */
async function handleSyncStorageChange(changes: Record<string, chrome.storage.StorageChange>) {
  try {
    // Type narrowing: only handle known keys
    const environmentChange = changes[SYNC_STORAGE_KEYS.BACKEND_ENVIRONMENT]

    if (environmentChange) {
      environment.value = await getEnvironment()
    }
  }
  catch (error) {
    console.error("Error handling sync storage change:", error)
  }
}

/**
 * Update environment setting and persist to storage.
 */
async function updateEnvironment(newEnvironment: Environment) {
  environment.value = newEnvironment
  await setEnvironment(newEnvironment)
}

/**
 * Update environment configurations and persist to storage.
 */
async function updateEnvironmentConfigs(newConfigs: EnvironmentConfigs) {
  environmentConfigs.value = newConfigs
  await setConfigs(newConfigs)
}

/**
 * Cleanup function to dispose of storage listeners.
 * Useful for testing, HMR, or extension shutdown scenarios.
 */
export function disposeEnvironment() {
  if (scope) {
    scope.stop()
    scope = null
  }
  browser.storage.local.onChanged.removeListener(handleLocalStorageChange)
  browser.storage.sync.onChanged.removeListener(handleSyncStorageChange)
  isInitialized = false
}

/**
 * Reactive environment composable with singleton pattern.
 * Provides shared state across all Vue components with automatic
 * cross-tab synchronization via browser storage events.
 *
 * Storage listeners are managed in an effectScope for proper cleanup.
 * Call disposeEnvironment() to cleanup if needed (e.g., tests, HMR).
 *
 * @example
 * ```typescript
 * const { environmentConfig, isAppConfigured, environment } = useEnvironment()
 *
 * // Use in templates or computed properties - automatically reactive
 * watchEffect(() => {
 *   console.log('Current environment:', environment.value)
 *   console.log('Is configured:', isAppConfigured.value)
 * })
 * ```
 */
export function useEnvironment() {
  // Initialize on first use
  if (!isInitialized) {
    // Create effect scope for lifecycle management
    scope = effectScope()

    scope.run(() => {
      loadAllEnvironmentSettings()

      // Set up storage listeners for cross-tab sync within the scope
      browser.storage.local.onChanged.addListener(handleLocalStorageChange)
      browser.storage.sync.onChanged.addListener(handleSyncStorageChange)
    })

    isInitialized = true
  }

  return {
    // Reactive state (read-only for form draft pattern)
    environment: computed(() => environment.value),
    environmentConfig,
    environmentConfigs: computed(() => environmentConfigs.value),
    isAppConfigured,

    // Update methods for saving form data
    updateEnvironment,
    updateEnvironmentConfigs,
  }
}

