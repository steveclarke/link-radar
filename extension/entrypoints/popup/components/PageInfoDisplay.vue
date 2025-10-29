<script lang="ts" setup>
/**
 * Component displaying current page information including favicon, title, and description.
 *
 * @component
 */

/**
 * Component props
 */
defineProps<{
  /** Information about the current tab/page */
  tabInfo: {
    /** Page title */
    title: string
    /** Page URL */
    url: string
    /** Optional favicon URL */
    favicon?: string
    /** Optional page meta description */
    description?: string
  } | null
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
