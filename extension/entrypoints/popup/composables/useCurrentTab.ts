/**
 * @fileoverview Composable for accessing current browser tab information.
 * Provides reactive state and methods to load details about the currently active tab.
 */

import type { TabInfo } from "../../../lib/types"
import { ref } from "vue"

/**
 * Composable for managing current browser tab information.
 * Provides reactive access to the active tab's title, URL, and favicon
 * using the WebExtensions browser.tabs API.
 */
export function useCurrentTab() {
  /** Current tab information (title, URL, favicon) */
  const tabInfo = ref<TabInfo | null>(null)

  /** Whether tab information is currently being loaded */
  const isLoading = ref(false)

  /** Error message if tab loading fails */
  const error = ref<string | null>(null)

  /**
   * Loads information about the currently active browser tab.
   * Queries for the active tab in the current window and extracts its title, URL, and favicon.
   *
   * @returns Promise resolving to TabInfo if successful, null if failed
   */
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
