import type { MessageState } from "../types"
import { ref } from "vue"

// Configuration constants
const ERROR_MESSAGE_TIMEOUT_MS = 15000
const SUCCESS_MESSAGE_TIMEOUT_MS = 3000

export function useNotification() {
  const message = ref<MessageState | null>(null)
  let timeoutId: ReturnType<typeof setTimeout> | null = null

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

  function showSuccess(text: string) {
    showMessage(text, "success")
  }

  function showError(text: string) {
    showMessage(text, "error")
  }

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
