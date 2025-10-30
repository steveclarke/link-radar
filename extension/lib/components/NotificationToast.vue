<script lang="ts" setup>
/**
 * Self-contained notification toast component for displaying success or error
 * messages. Appears at the top of the screen when a message is present.
 * Includes a close button for manual dismissal. Uses the useNotification
 * composable directly to access message state and clearMessage function.
 *
 * @component
 */

import { Icon } from "@iconify/vue"
import { useNotification } from "../composables/useNotification"

// Access the notification state and clearMessage function directly from the
// composable. This composable shares state across the app, so we see the same
// message that was set elsewhere
const { message, clearMessage } = useNotification()
</script>

<template>
  <div
    v-if="message"
    class="fixed top-4 left-4 right-4 px-3 py-2 rounded text-sm font-medium z-1000 flex items-center justify-between gap-3"
    :class="message.type === 'success' ? 'bg-green-100 text-green-800 border border-green-200' : 'bg-red-100 text-red-800 border border-red-200'"
  >
    <span class="flex-1">{{ message.text }}</span>
    <button
      type="button"
      class="shrink-0 w-5 h-5 flex items-center justify-center rounded hover:bg-black/10 transition-colors cursor-pointer border-none bg-transparent p-0"
      :class="message.type === 'success' ? 'text-green-800' : 'text-red-800'"
      title="Close notification"
      aria-label="Close notification"
      @click="clearMessage"
    >
      <Icon icon="material-symbols:close" class="w-4 h-4" />
    </button>
  </div>
</template>
