<script lang="ts" setup>
/**
 * Copy URL button component that handles clipboard copying internally.
 * Displays a copy icon button that copies the current tab's URL to the clipboard
 * and shows success/error notifications.
 *
 * @component
 */
import { Icon } from "@iconify/vue"
import { useClipboard } from "@vueuse/core"
import { useNotification } from "../../../lib/composables/useNotification"
import { useCurrentTab } from "../composables/useCurrentTab"

/**
 * Get shared tab information from global state
 */
const { tabInfo } = useCurrentTab()

/**
 * Clipboard composable for copying text to clipboard
 */
const { copy, isSupported } = useClipboard()

/**
 * Notification composable for showing success/error messages
 */
const { showSuccess, showError } = useNotification()

/**
 * Copies the current tab's URL to the clipboard.
 * Shows success/error notification based on the result.
 */
async function handleCopy() {
  if (!tabInfo.value || !isSupported.value)
    return

  try {
    await copy(tabInfo.value.url)
    showSuccess("URL copied to clipboard!")
  }
  catch (error) {
    console.error("Error copying to clipboard:", error)
    showError("Failed to copy URL")
  }
}
</script>

<template>
  <button
    class="w-9 h-9 p-0 border-none rounded-md cursor-pointer transition-all duration-200 bg-slate-200 hover:bg-slate-300 flex items-center justify-center"
    type="button"
    title="Copy URL to clipboard"
    aria-label="Copy URL to clipboard"
    :disabled="!tabInfo || !isSupported"
    @click="handleCopy"
  >
    <Icon
      icon="material-symbols:content-copy"
      class="w-5 h-5 text-slate-600"
    />
  </button>
</template>
