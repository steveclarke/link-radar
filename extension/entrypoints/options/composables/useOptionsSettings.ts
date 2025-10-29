/**
 * @fileoverview Composable for managing options/settings page business logic.
 * Centralizes all state management and operations for settings configuration.
 */

import type { BackendEnvironment, EnvironmentProfiles } from "../../../lib/settings"
import { ref } from "vue"
import { useNotification } from "../../../lib/composables/useNotification"
import { DEFAULT_AUTO_CLOSE_DELAY, getAutoCloseDelay, getBackendEnvironment, getDeveloperMode, getProfiles, setAutoCloseDelay, setBackendEnvironment, setDeveloperMode, setProfiles } from "../../../lib/settings"

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

  /** Whether settings are currently being loaded from storage */
  const isLoading = ref(false)

  // Methods
  /**
   * Loads saved profiles, auto-close delay, developer mode, and backend environment from browser storage.
   * Called automatically on component mount.
   */
  async function loadSettings() {
    isLoading.value = true
    try {
      profiles.value = await getProfiles()
      autoCloseDelay.value = await getAutoCloseDelay()
      developerMode.value = await getDeveloperMode()
      backendEnvironment.value = await getBackendEnvironment()
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
   * Check if a profile is configured (has required fields).
   * Custom environments need both URL and API key.
   * Production and local only need API key (URL from env vars).
   *
   * @param environment - The environment to check
   * @param profilesData - Optional profiles data to check (defaults to internal profiles state)
   * @returns true if profile has required fields
   */
  function isProfileConfigured(environment: BackendEnvironment, profilesData?: EnvironmentProfiles): boolean {
    const profilesToCheck = profilesData || profiles.value
    const profile = profilesToCheck[environment]
    if (environment === "custom") {
      return !!profile.url && !!profile.apiKey
    }
    return !!profile.apiKey
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

    if (backendEnvironment.value === "custom") {
      if (!currentProfile.url.trim()) {
        showError("Please enter a custom backend URL")
        return
      }

      // Validate custom URL is safe (blocks dangerous protocols)
      if (!validateBackendUrl(currentProfile.url)) {
        showError("Invalid URL. Please use a valid HTTP or HTTPS URL")
        return
      }
    }

    isSaving.value = true
    try {
      // Convert reactive Proxy object to plain object before saving
      // browser.storage cannot serialize Proxy objects, so we need a plain copy
      const plainProfiles: EnvironmentProfiles = JSON.parse(JSON.stringify(profiles.value))
      await setProfiles(plainProfiles)

      // Save other settings
      await setAutoCloseDelay(autoCloseDelay.value)
      await setDeveloperMode(developerMode.value)
      await setBackendEnvironment(backendEnvironment.value)

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
    profiles,
    showApiKeys,
    autoCloseDelay,
    developerMode,
    backendEnvironment,
    isSaving,
    isLoading,
    // Methods
    loadSettings,
    saveSettings,
    isProfileConfigured,
  }
}
