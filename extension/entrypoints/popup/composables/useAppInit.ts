/**
 * @fileoverview Composable for app initialization.
 * Handles all startup logic including API key checking and tab loading.
 */

import type { TabInfo } from "../../../lib/types"
import { ref } from "vue"
import { useEnvironment } from "../../../lib/composables/useEnvironment"
import { useCurrentTab } from "./useCurrentTab"

/**
 * Composable for managing app initialization.
 * Loads all necessary data when the popup opens.
 */
export function useAppInit() {
  const isAppLoading = ref(false)
  const currentTabInfo = ref<TabInfo | null>(null)

  const { isAppConfigured } = useEnvironment()
  const { loadCurrentTab } = useCurrentTab()

  /**
   * Initializes the app by loading all necessary data.
   * Should be called on component mount.
   */
  async function initApp() {
    isAppLoading.value = true
    try {
      // Load current browser tab info
      const tabData = await loadCurrentTab()
      if (tabData) {
        currentTabInfo.value = tabData
      }
    }
    catch (error) {
      console.error("Error initializing app:", error)
    }
    finally {
      isAppLoading.value = false
    }
  }

  return {
    isAppLoading,
    isAppConfigured,
    currentTabInfo,
    initApp,
  }
}
