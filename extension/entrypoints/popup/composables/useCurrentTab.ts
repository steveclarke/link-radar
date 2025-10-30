/**
 * Composable for managing current browser tab information.
 * Provides reactive access to the active tab's title, URL, and favicon.
 */
import type { TabInfo } from "../../../lib/types"
import { ref } from "vue"

/**
 * Shared global state for current tab information.
 * This ensures all components access the same tab data.
 */
const tabInfo = ref<TabInfo | null>(null)
const isLoading = ref(false)
const error = ref<string | null>(null)

/**
 * Composable that returns shared global state for current browser tab.
 * Uses shared refs so all components see the same tab data.
 */
export function useCurrentTab() {
  /**
   * Loads information about the currently active browser tab.
   * Queries for the active tab and extracts its title, URL, favicon, and meta description.
   *
   * @returns Promise resolving to TabInfo if successful, null if failed
   */
  async function loadCurrentTab() {
    isLoading.value = true
    error.value = null

    try {
      // browser.tabs.query returns an array of tabs matching the query criteria.
      // { active: true, currentWindow: true } finds the currently active tab in the current window.
      // We destructure [tab] to get the first (and only) result since there can only be one active tab.
      const [tab] = await browser.tabs.query({ active: true, currentWindow: true })

      if (!tab || !tab.url || !tab.id) {
        error.value = "Unable to access current tab"
        return null
      }

      // Extract meta description from the page using browser.scripting.executeScript.
      // This injects a script into the page to read the meta description tag.
      let description: string | undefined
      try {
        const results = await browser.scripting.executeScript({
          target: { tabId: tab.id },
          func: () => {
            const metaDescription = document.querySelector("meta[name=\"description\"]")
            return metaDescription?.getAttribute("content") || undefined
          },
        })
        description = results[0]?.result
      }
      catch (err) {
        // Failed to extract description (e.g., on chrome:// pages), continue without it
        console.warn("Could not extract meta description:", err)
      }

      tabInfo.value = {
        title: tab.title || "Untitled",
        url: tab.url,
        favicon: tab.favIconUrl,
        description,
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
