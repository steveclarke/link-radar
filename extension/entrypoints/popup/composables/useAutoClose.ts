/**
 * Composable for handling auto-close functionality after operations.
 * Provides a reusable way to close the popup window after a specified delay.
 */
import { useTimeoutFn } from "@vueuse/core"
import { useSettings } from "../../../lib/composables/useSettings"

export function useAutoClose() {
  // Get reactive auto-close delay from settings
  const { autoCloseDelay } = useSettings()

  /**
   * Triggers the auto-close mechanism based on user settings.
   * Closes the browser popup window after the configured delay.
   * If delay is 0 or negative, no auto-close occurs.
   */
  function triggerAutoClose() {
    if (autoCloseDelay.value > 0) {
      useTimeoutFn(() => window.close(), autoCloseDelay.value, { immediate: true })
    }
  }

  return {
    triggerAutoClose,
  }
}
