import { ref } from "vue"
import { STORAGE_KEYS } from "../../../lib/config"

export function useApiKey() {
  const apiKeyConfigured = ref(false)
  const isChecking = ref(false)

  async function checkApiKey() {
    isChecking.value = true
    try {
      const result = await chrome.storage.sync.get(STORAGE_KEYS.API_KEY)
      apiKeyConfigured.value = !!result[STORAGE_KEYS.API_KEY]
      return apiKeyConfigured.value
    }
    catch (error) {
      console.error("Error checking API key:", error)
      apiKeyConfigured.value = false
      return false
    }
    finally {
      isChecking.value = false
    }
  }

  function openSettings() {
    chrome.runtime.openOptionsPage()
  }

  return {
    apiKeyConfigured,
    isChecking,
    checkApiKey,
    openSettings,
  }
}
