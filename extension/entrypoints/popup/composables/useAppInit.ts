/**
 * @fileoverview Composable for app initialization.
 * Handles all startup logic including API key checking and tab loading.
 */

import type { EnvironmentProfile } from "../../../lib/settings"
import type { TabInfo } from "../../../lib/types"
import { computed, ref } from "vue"
import { getActiveProfile } from "../../../lib/settings"
import { useCurrentTab } from "./useCurrentTab"

/**
 * Composable for managing app initialization.
 * Loads all necessary data when the popup opens.
 */
export function useAppInit() {
  const isAppLoading = ref(false)
  const profile = ref<EnvironmentProfile | null>(null)
  const currentTabInfo = ref<TabInfo | null>(null)

  // Computed property that derives configuration status from the loaded profile
  const isAppConfigured = computed(() => !!profile.value?.apiKey)

  const { loadCurrentTab } = useCurrentTab()

  /**
   * Initializes the app by loading all necessary data.
   * Should be called on component mount.
   */
  async function initApp() {
    isAppLoading.value = true
    try {
      // Load the active profile (configuration status is computed from this)
      profile.value = await getActiveProfile()

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
