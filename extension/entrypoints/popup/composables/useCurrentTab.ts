import type { TabInfo } from "../../../lib/types"
import { ref } from "vue"

export function useCurrentTab() {
  const tabInfo = ref<TabInfo | null>(null)
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function loadCurrentTab() {
    isLoading.value = true
    error.value = null

    try {
      // browser.tabs.query returns an array of tabs matching the query criteria
      // { active: true, currentWindow: true } finds the currently active tab in the current window
      // We destructure [tab] to get the first (and only) result since there can only be one active tab
      const [tab] = await browser.tabs.query({ active: true, currentWindow: true })

      if (!tab || !tab.url) {
        error.value = "Unable to access current tab"
        return null
      }

      tabInfo.value = {
        title: tab.title || "Untitled",
        url: tab.url,
        favicon: tab.favIconUrl,
      }

      return tabInfo.value
    }
    catch (err) {
      console.error("Error getting tab info:", err)
      error.value = "Error loading tab information"
      return null
    }
    finally {
      isLoading.value = false
    }
  }

  return {
    tabInfo,
    isLoading,
    error,
    loadCurrentTab,
  }
}
