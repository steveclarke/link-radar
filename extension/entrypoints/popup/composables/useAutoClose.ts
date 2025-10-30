/**
 * Composable for handling auto-close functionality after operations.
 * Provides a reusable way to close the popup window after a specified delay.
 */
import { useTimeoutFn } from "@vueuse/core"
import { getAutoCloseDelay } from "../../../lib/settings"

export function useAutoClose() {
  /**
   * Triggers the auto-close mechanism based on user settings.
   * Closes the browser popup window after the configured delay.
   * If delay is 0 or negative, no auto-close occurs.
   */
  async function triggerAutoClose() {
    const delay = await getAutoCloseDelay()
    if (delay > 0) {
      useTimeoutFn(() => window.close(), delay, { immediate: true })
    }
  }

  return {
    triggerAutoClose,
  }
}
