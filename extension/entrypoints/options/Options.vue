<script lang="ts" setup>
/**
 * Settings page component for the Link Radar browser extension.
 * Provides UI for configuring the API key with validation, secure storage,
 * and auto-dismissing notifications.
 *
 * @component
 */
import type { BackendEnvironment } from "../../lib/settings"
import { computed, onMounted, ref } from "vue"
import { BACKEND_URL, DEFAULT_AUTO_CLOSE_DELAY, getApiKey, getAutoCloseDelay, getBackendEnvironment, getCustomBackendUrl, getDeveloperMode, LOCAL_DEV_BACKEND_URL, setApiKey, setAutoCloseDelay, setBackendEnvironment, setCustomBackendUrl, setDeveloperMode } from "../../lib/settings"

/** Duration in milliseconds for notification messages to display before auto-dismissal */
const MESSAGE_TIMEOUT_MS = 3000

/** Reactive reference to the API key input value */
const apiKey = ref("")

/** Whether the API key should be displayed as plain text (true) or masked (false) */
const showApiKey = ref(false)

/** Auto-close delay in milliseconds for the popup after successful operations */
const autoCloseDelay = ref(DEFAULT_AUTO_CLOSE_DELAY)

/** Whether developer mode is enabled (shows backend configuration) */
const developerMode = ref(false)

/** Backend environment selection */
const backendEnvironment = ref<BackendEnvironment>("production")

/** Custom backend URL (when environment is "custom") */
const customBackendUrl = ref("")

/** Current notification message to display (null if no message) */
const message = ref<{ text: string, type: "success" | "error" } | null>(null)

/** Whether a save operation is currently in progress */
const isSaving = ref(false)

/** Computed label for the auto-close delay display */
const delayLabel = computed(() => {
  return autoCloseDelay.value === 0 ? "Disabled" : `${autoCloseDelay.value}ms`
})

/**
 * Loads saved API key, auto-close delay, developer mode, and backend environment from browser storage.
 * Called automatically on component mount.
 */
async function loadSettings() {
  try {
    apiKey.value = (await getApiKey()) || ""
    autoCloseDelay.value = await getAutoCloseDelay()
    developerMode.value = await getDeveloperMode()
    backendEnvironment.value = await getBackendEnvironment()
    customBackendUrl.value = await getCustomBackendUrl()
  }
  catch (error) {
    console.error("Error loading settings:", error)
    showError("Failed to load settings")
  }
}

/**
 * Saves all settings (API key, auto-close delay, developer mode, backend environment) to browser storage.
 * Validates that the key is not empty before saving.
 */
async function saveSettings() {
  if (!apiKey.value.trim()) {
    showError("Please enter an API key")
    return
  }

  // Validate custom URL if custom environment is selected
  if (backendEnvironment.value === "custom" && !customBackendUrl.value.trim()) {
    showError("Please enter a custom backend URL")
    return
  }

  isSaving.value = true
  try {
    await setApiKey(apiKey.value.trim())
    await setAutoCloseDelay(autoCloseDelay.value)
    await setDeveloperMode(developerMode.value)
    await setBackendEnvironment(backendEnvironment.value)
    await setCustomBackendUrl(customBackendUrl.value.trim())
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
 * Toggles the visibility of the API key input field.
 */
function toggleShowApiKey() {
  showApiKey.value = !showApiKey.value
}

/**
 * Displays a success notification message with auto-dismissal.
 *
 * @param text - The success message to display
 */
function showSuccess(text: string) {
  showMessage(text, "success")
}

/**
 * Displays an error notification message with auto-dismissal.
 *
 * @param text - The error message to display
 */
function showError(text: string) {
  showMessage(text, "error")
}

/**
 * Internal helper to display a notification message.
 *
 * @param text - The message text to display
 * @param type - The message type ("success" or "error")
 */
function showMessage(text: string, type: "success" | "error") {
  message.value = { text, type }
  setTimeout(() => {
    message.value = null
  }, MESSAGE_TIMEOUT_MS)
}

// Load settings when component mounts
onMounted(() => {
  loadSettings()
})
</script>

<template>
  <div class="max-w-5xl mx-auto p-6 font-sans">
    <div class="mb-8 flex items-start justify-between">
      <div>
        <h1 class="m-0 mb-2 text-[32px] text-gray-900">
          Link Radar Settings
        </h1>
        <p class="m-0 text-base text-gray-600">
          Configure your Link Radar extension
        </p>
      </div>
      <div class="flex items-center gap-3">
        <span class="text-sm font-medium text-gray-700">
          Developer Mode
        </span>
        <button
          type="button"
          class="relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-brand-600 focus:ring-offset-2"
          :class="developerMode ? 'bg-brand-600' : 'bg-gray-200'"
          role="switch"
          :aria-checked="developerMode"
          @click="developerMode = !developerMode"
        >
          <span
            class="pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out"
            :class="developerMode ? 'translate-x-5' : 'translate-x-0'"
          />
        </button>
      </div>
    </div>

    <div class="flex flex-col gap-6">
      <div class="bg-white rounded-lg p-6 shadow-sm">
        <h2 class="m-0 mb-4 text-xl text-gray-900">
          API Configuration
        </h2>
        <p class="m-0 mb-5 text-sm text-gray-600 leading-normal">
          Enter your Link Radar API key to enable link saving. You can find this in your backend configuration.
        </p>

        <div class="mb-5">
          <label for="api-key" class="block text-sm font-medium text-gray-800 mb-2">API Key</label>
          <div class="flex gap-2 items-stretch">
            <input
              id="api-key"
              v-model="apiKey"
              :type="showApiKey ? 'text' : 'password'"
              placeholder="Enter your API key"
              class="flex-1 px-3 py-2.5 border border-gray-300 rounded-md text-sm font-mono transition-colors focus:outline-none focus:border-brand-600 focus:ring-2 focus:ring-brand-200"
            >
            <button
              type="button"
              class="px-3 border border-gray-300 rounded-md bg-white cursor-pointer text-lg transition-colors hover:bg-gray-50"
              :title="showApiKey ? 'Hide API key' : 'Show API key'"
              @click="toggleShowApiKey"
            >
              {{ showApiKey ? '👁️' : '👁️‍🗨️' }}
            </button>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-lg p-6 shadow-sm">
        <h3 class="m-0 mb-4 text-xl text-gray-900">
          Popup Behavior
        </h3>
        <p class="m-0 mb-5 text-sm text-gray-600 leading-normal">
          Control how long the popup stays open after saving, updating, or deleting a link.
          Set to 0 to disable auto-close (popup stays open).
        </p>

        <div class="mb-4">
          <label for="auto-close-delay" class="block text-sm font-medium text-gray-800 mb-2">
            Auto-close delay: <span class="font-semibold text-brand-600">{{ delayLabel }}</span>
          </label>
          <div class="flex gap-3 items-center">
            <input
              id="auto-close-delay"
              v-model.number="autoCloseDelay"
              type="range"
              min="0"
              max="2000"
              step="500"
              class="flex-1 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-brand-600"
            >
            <input
              v-model.number="autoCloseDelay"
              type="number"
              min="0"
              max="2000"
              placeholder="ms"
              class="w-24 px-3 py-2 border border-gray-300 rounded-md text-sm text-right transition-colors focus:outline-none focus:border-brand-600 focus:ring-2 focus:ring-brand-200"
            >
          </div>
          <p class="mt-2 text-xs text-gray-500">
            Recommended values: 0 (disabled), 500ms (quick), 1000ms (medium), 1500ms (slower), 2000ms (slowest)
          </p>
        </div>
      </div>
    </div>

    <!-- Global Save Button -->
    <div class="mt-8 flex justify-end">
      <button
        :disabled="isSaving"
        class="px-8 py-3 border-none rounded-md text-base font-medium bg-brand-600 text-white cursor-pointer transition-colors hover:bg-brand-700 disabled:opacity-60 disabled:cursor-not-allowed shadow-sm"
        @click="saveSettings"
      >
        {{ isSaving ? 'Saving...' : 'Save All Settings' }}
      </button>
    </div>

    <!-- Developer Information (only visible in developer mode) -->
    <div v-if="developerMode" class="mt-8 pt-8 border-t border-gray-200">
      <div class="bg-brand-50 border border-brand-200 rounded-lg p-6">
        <div class="flex items-start gap-3">
          <div class="text-2xl">
            ℹ️
          </div>
          <div class="flex-1">
            <h3 class="m-0 mb-4 text-lg font-semibold text-brand-900">
              Backend Environment
            </h3>

            <!-- Environment Selection -->
            <div class="mb-4">
              <label class="block text-sm font-medium text-brand-900 mb-3">
                Select Backend Environment:
              </label>
              <div class="space-y-3">
                <!-- Production -->
                <label class="flex items-start gap-3 cursor-pointer group">
                  <input
                    v-model="backendEnvironment"
                    type="radio"
                    value="production"
                    class="mt-1 w-4 h-4 accent-brand-600 cursor-pointer"
                  >
                  <div class="flex-1">
                    <div class="font-medium text-brand-900 group-hover:text-brand-700">
                      🟢 Production
                    </div>
                    <div class="text-xs text-brand-700 mt-0.5">
                      {{ BACKEND_URL }}
                    </div>
                  </div>
                </label>

                <!-- Local Development -->
                <label class="flex items-start gap-3 cursor-pointer group">
                  <input
                    v-model="backendEnvironment"
                    type="radio"
                    value="local"
                    class="mt-1 w-4 h-4 accent-brand-600 cursor-pointer"
                  >
                  <div class="flex-1">
                    <div class="font-medium text-brand-900 group-hover:text-brand-700">
                      🟡 Local Development
                    </div>
                    <div class="text-xs text-brand-700 mt-0.5">
                      {{ LOCAL_DEV_BACKEND_URL }}
                    </div>
                  </div>
                </label>

                <!-- Custom -->
                <label class="flex items-start gap-3 cursor-pointer group">
                  <input
                    v-model="backendEnvironment"
                    type="radio"
                    value="custom"
                    class="mt-1 w-4 h-4 accent-brand-600 cursor-pointer"
                  >
                  <div class="flex-1">
                    <div class="font-medium text-brand-900 group-hover:text-brand-700">
                      🔵 Custom URL
                    </div>
                    <div class="text-xs text-brand-700 mt-0.5">
                      Specify your own backend URL (e.g., staging environment)
                    </div>
                  </div>
                </label>

                <!-- Custom URL Input -->
                <div v-if="backendEnvironment === 'custom'" class="ml-7 mt-2">
                  <input
                    v-model="customBackendUrl"
                    type="url"
                    placeholder="https://api.example.com/api/v1"
                    class="w-full px-3 py-2 border border-brand-300 bg-white rounded-md text-sm font-mono transition-colors focus:outline-none focus:border-brand-600 focus:ring-2 focus:ring-brand-200"
                  >
                </div>
              </div>
            </div>

            <div class="pt-4 mt-4 border-t border-brand-300">
              <p class="m-0 text-xs text-brand-700 italic">
                <strong>Note:</strong> Remember to save your settings after changing the backend environment.
                The popup will show which backend you're currently connected to.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="message" class="fixed top-6 right-6 px-4 py-3 rounded-md text-sm font-medium z-1000 shadow-md" :class="message.type === 'success' ? 'bg-green-100 text-green-800 border border-green-200' : 'bg-red-100 text-red-800 border border-red-200'">
      {{ message.text }}
    </div>
  </div>
</template>
