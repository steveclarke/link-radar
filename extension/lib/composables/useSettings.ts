/**
 * @fileoverview Reactive settings composable with cross-tab synchronization.
 * Provides singleton state management for all extension settings with automatic
 * browser storage listeners.
 *
 * This composable establishes the architectural pattern for settings management:
 * - Vue contexts use this composable for reactive state
 * - Non-Vue contexts (service workers, background scripts) use settings.ts functions
 * - Both stay synchronized via browser storage events
 */

import type { Environment, EnvironmentConfig, EnvironmentConfigs } from "../settings"
import { computed, ref } from "vue"
import {
  getAutoCloseDelay,
  getConfigs,
  getDeveloperMode,
  getEnvironment,
  SENSITIVE_STORAGE_KEYS,
  setAutoCloseDelay,
  setConfigs,
  setDeveloperMode,
  setEnvironment,
  SYNC_STORAGE_KEYS,
} from "../settings"

// Singleton state - shared across all component instances
let isInitialized = false
const environment = ref<Environment>("local")
const environmentConfigs = ref<EnvironmentConfigs>({
  production: { url: "", apiKey: "" },
  local: { url: "", apiKey: "" },
  custom: { url: "", apiKey: "" },
})
const autoCloseDelay = ref(500)
const isDeveloperMode = ref(false)

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
 * Load all settings from browser storage.
 * Called once during initialization.
 */
async function loadAllSettings() {
  try {
    environmentConfigs.value = await getConfigs()
    environment.value = await getEnvironment()
    autoCloseDelay.value = await getAutoCloseDelay()
    isDeveloperMode.value = await getDeveloperMode()
  }
  catch (error) {
    console.error("Error loading settings:", error)
  }
}

/**
 * Local storage change handler for cross-tab synchronization.
 * Reloads environment configs when they change in another tab.
 */
function handleLocalStorageChange(changes: Record<string, chrome.storage.StorageChange>) {
  if (changes[SENSITIVE_STORAGE_KEYS.ENVIRONMENT_PROFILES]) {
    getConfigs().then((configs) => {
      environmentConfigs.value = configs
    })
  }
}

/**
 * Sync storage change handler for cross-tab synchronization.
 * Reloads settings when they change in another tab.
 */
function handleSyncStorageChange(changes: Record<string, chrome.storage.StorageChange>) {
  if (changes[SYNC_STORAGE_KEYS.BACKEND_ENVIRONMENT]) {
    getEnvironment().then((env) => {
      environment.value = env
    })
  }

  if (changes[SYNC_STORAGE_KEYS.AUTO_CLOSE_DELAY]) {
    getAutoCloseDelay().then((delay) => {
      autoCloseDelay.value = delay
    })
  }

  if (changes[SYNC_STORAGE_KEYS.DEVELOPER_MODE]) {
    getDeveloperMode().then((mode) => {
      isDeveloperMode.value = mode
    })
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
 * Update auto-close delay and persist to storage.
 */
async function updateAutoCloseDelay(newDelay: number) {
  autoCloseDelay.value = newDelay
  await setAutoCloseDelay(newDelay)
}

/**
 * Update developer mode and persist to storage.
 */
async function updateDeveloperMode(newMode: boolean) {
  isDeveloperMode.value = newMode
  await setDeveloperMode(newMode)
}

/**
 * Reactive settings composable with singleton pattern.
 * Provides shared state across all Vue components with automatic
 * cross-tab synchronization via browser storage events.
 *
 * @example
 * ```typescript
 * const { environmentConfig, isAppConfigured, environment } = useSettings()
 *
 * // Use in templates or computed properties - automatically reactive
 * watchEffect(() => {
 *   console.log('Current environment:', environment.value)
 *   console.log('Is configured:', isAppConfigured.value)
 * })
 * ```
 */
export function useSettings() {
  // Initialize on first use
  if (!isInitialized) {
    loadAllSettings()

    // Set up storage listeners for cross-tab sync
    browser.storage.local.onChanged.addListener(handleLocalStorageChange)
    browser.storage.sync.onChanged.addListener(handleSyncStorageChange)

    isInitialized = true
  }

  return {
    // Reactive state (read-only refs)
    environment: computed(() => environment.value),
    environmentConfig,
    environmentConfigs: computed(() => environmentConfigs.value),
    autoCloseDelay: computed(() => autoCloseDelay.value),
    isDeveloperMode: computed(() => isDeveloperMode.value),
    isAppConfigured,

    // Update methods that sync to storage
    updateEnvironment,
    updateEnvironmentConfigs,
    updateAutoCloseDelay,
    updateDeveloperMode,
  }
}
