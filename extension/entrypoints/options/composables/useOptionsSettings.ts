/**
 * @fileoverview Composable for managing options/settings page business logic.
 * Centralizes all state management and operations for settings configuration.
 */

import type { BackendEnvironment, EnvironmentProfiles } from "../../../lib/settings"
import { computed, ref } from "vue"
import { useNotification } from "../../../lib/composables/useNotification"
import { DEFAULT_AUTO_CLOSE_DELAY, getAutoCloseDelay, getBackendEnvironment, getDeveloperMode, getProfiles, setAutoCloseDelay, setBackendEnvironment, setDeveloperMode, setProfileApiKey, setProfileUrl } from "../../../lib/settings"

/**
 * Composable that manages all settings state and operations.
 * Provides centralized business logic for the options page.
 */
export function useOptionsSettings() {
  // Use notification composable for success/error messages
  const { showSuccess, showError } = useNotification()

  // State
  /** Environment profiles state containing URL and API key for each environment */
  const profiles = ref<EnvironmentProfiles>({
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
  const developerMode = ref(false)

  /** Backend environment selection */
  const backendEnvironment = ref<BackendEnvironment>("local")

  /** Whether a save operation is currently in progress */
  const isSaving = ref(false)

  // Computed
  /** Computed label for the auto-close delay display */
  const delayLabel = computed(() => {
    return autoCloseDelay.value === 0 ? "Disabled" : `${autoCloseDelay.value}ms`
  })

  // Methods
  /**
   * Loads saved profiles, auto-close delay, developer mode, and backend environment from browser storage.
   * Called automatically on component mount.
   */
  async function loadSettings() {
    try {
      profiles.value = await getProfiles()
      autoCloseDelay.value = await getAutoCloseDelay()
      developerMode.value = await getDeveloperMode()
      backendEnvironment.value = await getBackendEnvironment()
    }
    catch (error) {
      console.error("Error loading settings:", error)
      showError("Failed to load settings")
    }
  }

  /**
   * Saves all settings to browser storage.
   */
  async function saveSettings() {
    // Validate current environment profile
    const currentProfile = profiles.value[backendEnvironment.value]

    if (!currentProfile.apiKey.trim()) {
      showError(`Please enter an API key for ${backendEnvironment.value} environment`)
      return
    }

    if (backendEnvironment.value === "custom" && !currentProfile.url.trim()) {
      showError("Please enter a custom backend URL")
      return
    }

    isSaving.value = true
    try {
      // Save all profile configurations
      await setProfileApiKey("production", profiles.value.production.apiKey)
      await setProfileApiKey("local", profiles.value.local.apiKey)
      await setProfileApiKey("custom", profiles.value.custom.apiKey)
      await setProfileUrl("custom", profiles.value.custom.url)

      // Save other settings
      await setAutoCloseDelay(autoCloseDelay.value)
      await setDeveloperMode(developerMode.value)
      await setBackendEnvironment(backendEnvironment.value)

      showSuccess("Settings saved successfully!")
    }
    catch (error) {
      console.error("Error saving settings:", error)
      showError("Failed to save settings")
    }
    finally {
      isSaving.value = false
    }
  }

  /**
   * Toggles the visibility of the API key input field for a specific environment.
   *
   * @param environment - The environment whose API key visibility to toggle
   */
  function toggleShowApiKey(environment: BackendEnvironment) {
    showApiKeys.value[environment] = !showApiKeys.value[environment]
  }

  return {
    // State
    profiles,
    showApiKeys,
    autoCloseDelay,
    developerMode,
    backendEnvironment,
    isSaving,
    // Computed
    delayLabel,
    // Methods
    loadSettings,
    saveSettings,
    toggleShowApiKey,
  }
}
