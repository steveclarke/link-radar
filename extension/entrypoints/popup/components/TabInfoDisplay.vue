<script lang="ts" setup>
/**
 * Component displaying current tab information including favicon, title, and description.
 *
 * @component
 */
import type { TabInfo } from "../../../lib/types"

defineProps<{
  /** Current browser tab information */
  tabInfo: TabInfo | null
}>()
</script>

<template>
  <div v-if="tabInfo" class="bg-white rounded-lg p-3 shadow-sm">
    <div class="flex items-start gap-2">
      <img
        v-if="tabInfo.favicon"
        :src="tabInfo.favicon"
        class="w-4 h-4 shrink-0 mt-0.5"
        alt="Site icon"
      >
      <div class="flex-1 min-w-0">
        <div class="font-medium text-slate-900 mb-1 leading-snug wrap-break-word">
          {{ tabInfo.title }}
        </div>
        <div v-if="tabInfo.description" class="text-xs text-slate-600 leading-tight">
          {{ tabInfo.description }}
        </div>
      </div>
    </div>
  </div>
</template>
