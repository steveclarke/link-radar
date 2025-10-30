/**
 * @fileoverview Composable for managing options/settings page business logic.
 * Centralizes all state management and operations for settings configuration.
 */

import type { Environment, EnvironmentConfigs } from "../../../lib/settings"
import { ref } from "vue"
import { useNotification } from "../../../lib/composables/useNotification"
import { DEFAULT_AUTO_CLOSE_DELAY, getAutoCloseDelay, getConfigs, getDeveloperMode, getEnvironment, setAutoCloseDelay, setConfigs, setDeveloperMode, setEnvironment } from "../../../lib/settings"

/**
 * Validates that a URL is safe for use as a backend URL.
 * Only allows http: and https: protocols to prevent protocol-based attacks.
 *
 * @param url - The URL to validate
 * @returns true if valid, false otherwise
 */
function validateBackendUrl(url: string): boolean {
  if (!url.trim())
    return false

  try {
    const parsed = new URL(url)
    // Only allow HTTP(S) protocols - blocks javascript:, data:, file:, etc.
    return parsed.protocol === "http:" || parsed.protocol === "https:"
  }
  catch {
    // URL constructor throws on invalid/malformed URLs
    return false
  }
}

/**
 * Composable that manages all settings state and operations.
 * Provides centralized business logic for the options page.
 */
export function useOptionsSettings() {
  // Use notification composable for success/error messages
  const { showSuccess, showError } = useNotification()

  // State
  /** Environment configurations state containing URL and API key for each environment */
  const environmentConfigs = ref<EnvironmentConfigs>({
    production: { url: "", apiKey: "" },
    local: { url: "", apiKey: "" },
    custom: { url: "", apiKey: "" },
  })

  /** Whether API keys should be displayed as plain text (true) or masked (false) */
  const showApiKeys = ref({
    production: false,
    local: false,
    custom: false,
  })

  /** Auto-close delay in milliseconds for the popup after successful operations */
  const autoCloseDelay = ref(DEFAULT_AUTO_CLOSE_DELAY)

  /** Whether developer mode is enabled (shows backend configuration) */
  const isDeveloperMode = ref(false)

  /** Environment selection */
  const environment = ref<Environment>("local")

  /** Whether a save operation is currently in progress */
  const isSaving = ref(false)

  /** Whether settings are currently being loaded from storage */
  const isLoading = ref(false)

  // Methods
  /**
   * Loads saved environment configs, auto-close delay, developer mode, and environment from browser storage.
   * Called automatically on component mount.
   */
  async function loadSettings() {
    isLoading.value = true
    try {
      environmentConfigs.value = await getConfigs()
      autoCloseDelay.value = await getAutoCloseDelay()
      isDeveloperMode.value = await getDeveloperMode()
      environment.value = await getEnvironment()
    }
    catch (error) {
      console.error("Error loading settings:", error)
      // Provide actionable error message to users
      const errorMessage = error instanceof Error ? error.message : "Unknown error"
      showError(`Failed to load settings: ${errorMessage}. Try reloading the page or check browser permissions.`)
    }
    finally {
      isLoading.value = false
    }
  }

  /**
   * Check if an environment is configured (has required fields).
   * Custom environments need both URL and API key.
   * Production and local only need API key (URL from env vars).
   *
   * @param env - The environment to check
   * @param configsData - Optional configs data to check (defaults to internal environmentConfigs state)
   * @returns true if environment has required fields
   */
  function isConfigured(env: Environment, configsData?: EnvironmentConfigs): boolean {
    const configsToCheck = configsData || environmentConfigs.value
    const config = configsToCheck[env]
    if (env === "custom") {
      return !!config.url && !!config.apiKey
    }
    return !!config.apiKey
  }

  /**
   * Saves all settings to browser storage.
   */
  async function saveSettings() {
    // Validate current environment config
    const currentConfig = environmentConfigs.value[environment.value]

    if (!currentConfig.apiKey.trim()) {
      showError(`Please enter an API key for ${environment.value} environment`)
      return
    }

    if (environment.value === "custom") {
      if (!currentConfig.url.trim()) {
        showError("Please enter a custom backend URL")
        return
      }

      // Validate custom URL is safe (blocks dangerous protocols)
      if (!validateBackendUrl(currentConfig.url)) {
        showError("Invalid URL. Please use a valid HTTP or HTTPS URL")
        return
      }
    }

    isSaving.value = true
    try {
      // Convert reactive Proxy object to plain object before saving
      // browser.storage cannot serialize Proxy objects, so we need a plain copy
      const plainConfigs: EnvironmentConfigs = JSON.parse(JSON.stringify(environmentConfigs.value))
      await setConfigs(plainConfigs)

      // Save other settings
      await setAutoCloseDelay(autoCloseDelay.value)
      await setDeveloperMode(isDeveloperMode.value)
      await setEnvironment(environment.value)

      showSuccess("Settings saved successfully!")
    }
    catch (error) {
      console.error("Error saving settings:", error)
      const errorMessage = error instanceof Error ? error.message : "Unknown error"
      showError(`Failed to save settings: ${errorMessage}. Please try again.`)
    }
    finally {
      isSaving.value = false
    }
  }

  return {
    // State
    environmentConfigs,
    showApiKeys,
    autoCloseDelay,
    isDeveloperMode,
    environment,
    isSaving,
    isLoading,
    // Methods
    loadSettings,
    saveSettings,
    isConfigured,
  }
}
