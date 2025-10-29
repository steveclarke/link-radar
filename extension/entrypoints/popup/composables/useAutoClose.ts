/**
 * @fileoverview Composable for handling auto-close functionality after operations.
 * Provides a reusable way to close the popup window after a specified delay.
 */

import { useTimeoutFn } from "@vueuse/core"

/**
 * Composable for auto-closing the popup window.
 *
 * @returns Function to trigger auto-close with a specified delay
 */
export function useAutoClose() {
  /**
   * Triggers the auto-close mechanism if delay is greater than 0.
   * Closes the browser popup window after the specified delay.
   *
   * @param delay - Delay in milliseconds before closing (0 or negative means no auto-close)
   */
  function triggerAutoClose(delay: number) {
    if (delay > 0) {
      useTimeoutFn(() => window.close(), delay, { immediate: true })
    }
  }

  return {
    triggerAutoClose,
  }
}
