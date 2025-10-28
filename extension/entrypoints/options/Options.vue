<script lang="ts" setup>
import { onMounted, ref } from "vue"
import { getApiKey, setApiKey } from "../../lib/apiKey"

const apiKey = ref("")
const showApiKey = ref(false)
const message = ref<{ text: string, type: "success" | "error" } | null>(null)
const isSaving = ref(false)

async function loadSettings() {
  try {
    apiKey.value = (await getApiKey()) || ""
  }
  catch (error) {
    console.error("Error loading settings:", error)
    showError("Failed to load settings")
  }
}

async function saveSettings() {
  if (!apiKey.value.trim()) {
    showError("Please enter an API key")
    return
  }

  isSaving.value = true
  try {
    await setApiKey(apiKey.value.trim())
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

function toggleShowApiKey() {
  showApiKey.value = !showApiKey.value
}

function showSuccess(text: string) {
  showMessage(text, "success")
}

function showError(text: string) {
  showMessage(text, "error")
}

function showMessage(text: string, type: "success" | "error") {
  message.value = { text, type }
  setTimeout(() => {
    message.value = null
  }, 3000)
}

onMounted(() => {
  loadSettings()
})
</script>

<template>
  <div class="max-w-3xl mx-auto p-6 font-sans">
    <div class="mb-8">
      <h1 class="m-0 mb-2 text-[32px] text-gray-900">
        Link Radar Settings
      </h1>
      <p class="m-0 text-base text-gray-600">
        Configure your Link Radar extension
      </p>
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
              class="flex-1 px-3 py-2.5 border border-gray-300 rounded-md text-sm font-mono transition-colors focus:outline-none focus:border-blue-600 focus:ring-2 focus:ring-blue-200"
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

        <button
          :disabled="isSaving"
          class="px-6 py-2.5 border-none rounded-md text-sm font-medium bg-blue-600 text-white cursor-pointer transition-colors hover:bg-blue-700 disabled:opacity-60 disabled:cursor-not-allowed"
          @click="saveSettings"
        >
          {{ isSaving ? 'Saving...' : 'Save Settings' }}
        </button>
      </div>

      <div class="bg-white rounded-lg p-6 shadow-sm">
        <h3 class="m-0 mb-4 text-xl text-gray-900">
          Backend Setup
        </h3>
        <p class="m-0 mb-3 text-sm text-gray-600 leading-normal">
          To use Link Radar, you need to have the backend API running.
          By default, the extension expects the API to be available at:
        </p>
        <code class="block p-3 bg-gray-50 border border-gray-200 rounded font-mono text-[13px] text-gray-800 my-3">http://localhost:3000/api/v1/links</code>
        <p class="m-0 text-[13px] text-gray-500 italic">
          For production use, the backend URL can be configured at build time
          using the <code class="px-1.5 py-0.5 bg-gray-50 border border-gray-200 rounded-sm font-mono text-xs">VITE_BACKEND_URL</code> environment variable.
        </p>
      </div>
    </div>

    <div v-if="message" class="fixed top-6 right-6 px-4 py-3 rounded-md text-sm font-medium z-1000 shadow-md" :class="message.type === 'success' ? 'bg-green-100 text-green-800 border border-green-200' : 'bg-red-100 text-red-800 border border-red-200'">
      {{ message.text }}
    </div>
  </div>
</template>
