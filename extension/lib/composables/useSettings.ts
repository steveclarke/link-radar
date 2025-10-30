/**
 * Reactive settings composable for general app behavior settings. Provides
 * singleton state management for popup behavior and developer mode with
 * automatic browser storage synchronization.
 *
 * For environment-related settings (backend URLs, API keys, environment
 * selection), use the useEnvironment composable instead.
 *
 * This composable establishes the architectural pattern for settings management:
 * - Vue contexts use this composable for reactive state
 * - Non-Vue contexts (service workers, background scripts) use settings.ts functions
 * - Both stay synchronized via browser storage events
 */

import { createGlobalState } from "@vueuse/core"
import { ref } from "vue"
import {
  getAutoCloseDelay,
  getDeveloperMode,
  setAutoCloseDelay,
  setDeveloperMode,
  syncedStorageKeys,
} from "../settings"

/**
 * Reactive settings composable for app behavior settings with singleton pattern.
 * Provides shared state across all Vue components with automatic
 * cross-tab synchronization via browser storage events.
 *
 * For environment configuration (backend URLs, API keys), use useEnvironment() instead.
 *
 * @example
 * ```typescript
 * const { autoCloseDelay, isDeveloperMode } = useSettings()
 *
 * // Use in templates or computed properties - automatically reactive
 * watchEffect(() => {
 *   console.log('Auto-close delay:', autoCloseDelay.value)
 *   console.log('Developer mode:', isDeveloperMode.value)
 * })
 * ```
 */
export const useSettings = createGlobalState(() => {
  // Singleton state - shared across all component instances
  const autoCloseDelay = ref(500)
  const isDeveloperMode = ref(false)

  /**
   * Load all app behavior settings from browser storage.
   * Called once during initialization.
   */
  async function loadAllSettings() {
    try {
      autoCloseDelay.value = await getAutoCloseDelay()
      isDeveloperMode.value = await getDeveloperMode()
    }
    catch (error) {
      console.error("Error loading settings:", error)
    }
  }

  /**
   * Sync storage change handler for cross-tab synchronization.
   * Reloads settings when they change in another tab.
   * Type-safe handler that only processes known storage keys.
   */
  async function handleSyncStorageChange(changes: Record<string, chrome.storage.StorageChange>) {
    try {
      // Type narrowing: only handle known keys
      const delayChange = changes[syncedStorageKeys.autoCloseDelay]
      const developerModeChange = changes[syncedStorageKeys.isDeveloperMode]

      if (delayChange) {
        autoCloseDelay.value = await getAutoCloseDelay()
      }

      if (developerModeChange) {
        isDeveloperMode.value = await getDeveloperMode()
      }
    }
    catch (error) {
      console.error("Error handling sync storage change:", error)
    }
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

  // Initialize on first call
  loadAllSettings()

  // Set up storage listeners for cross-tab sync
  browser.storage.sync.onChanged.addListener(handleSyncStorageChange)

  return {
    autoCloseDelay,
    isDeveloperMode,
    updateAutoCloseDelay,
    updateDeveloperMode,
  }
})
