/**
 * @fileoverview Composable for managing user notifications and messages.
 * Provides reactive state and methods for displaying success and error messages
 * with automatic timeout-based dismissal.
 */

import type { MessageState } from "../../../lib/types"
import { ref } from "vue"

/**
 * Duration in milliseconds for error messages to display before auto-dismissal.
 * Error messages stay longer (15 seconds) to ensure users have time to read them.
 */
const ERROR_MESSAGE_TIMEOUT_MS = 15000

/**
 * Duration in milliseconds for success messages to display before auto-dismissal.
 * Success messages dismiss quickly (3 seconds) to avoid cluttering the UI.
 */
const SUCCESS_MESSAGE_TIMEOUT_MS = 3000

/**
 * Composable for managing user notifications with automatic timeout-based dismissal.
 * Error messages persist longer than success messages to ensure visibility.
 * Prevents message overlap by clearing existing timeouts when showing new messages.
 */
export function useNotification() {
  /** Current message state (null if no message is displayed) */
  const message = ref<MessageState | null>(null)

  /** Timeout ID for auto-dismissal (null if no timeout is active) */
  let timeoutId: ReturnType<typeof setTimeout> | null = null

  /**
   * Displays a message with the specified type and auto-dismissal.
   * Clears any existing message and timeout before showing the new message.
   *
   * @param text - The message text to display
   * @param type - The message type ("success" or "error")
   */
  function showMessage(text: string, type: "success" | "error") {
    // Clear existing timeout if any
    if (timeoutId !== null) {
      clearTimeout(timeoutId)
    }

    message.value = { text, type }

    // Error messages stay longer than success messages
    const timeout = type === "error" ? ERROR_MESSAGE_TIMEOUT_MS : SUCCESS_MESSAGE_TIMEOUT_MS

    timeoutId = setTimeout(() => {
      message.value = null
      timeoutId = null
    }, timeout)
  }

  /**
   * Displays a success message with auto-dismissal.
   *
   * @param text - The success message text to display
   */
  function showSuccess(text: string) {
    showMessage(text, "success")
  }

  /**
   * Displays an error message with auto-dismissal.
   *
   * @param text - The error message text to display
   */
  function showError(text: string) {
    showMessage(text, "error")
  }

  /**
   * Manually clears the current message and cancels any pending timeout.
   * Useful for implementing manual dismissal (e.g., close button).
   */
  function clearMessage() {
    if (timeoutId !== null) {
      clearTimeout(timeoutId)
      timeoutId = null
    }
    message.value = null
  }

  return {
    message,
    showMessage,
    showSuccess,
    showError,
    clearMessage,
  }
}
