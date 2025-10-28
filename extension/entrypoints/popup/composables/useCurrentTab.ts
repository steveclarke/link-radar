import type { TabInfo } from "../types"
import { ref } from "vue"

export function useCurrentTab() {
  const pageInfo = ref<TabInfo | null>(null)
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function loadCurrentPageInfo() {
    isLoading.value = true
    error.value = null

    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true })

      if (!tab || !tab.url) {
        error.value = "Unable to access current page"
        return null
      }

      pageInfo.value = {
        title: tab.title || "Untitled",
        url: tab.url,
        favicon: tab.favIconUrl,
      }

      return pageInfo.value
    }
    catch (err) {
      console.error("Error getting tab info:", err)
      error.value = "Error loading page information"
      return null
    }
    finally {
      isLoading.value = false
    }
  }

  return {
    pageInfo,
    isLoading,
    error,
    loadCurrentPageInfo,
  }
}
