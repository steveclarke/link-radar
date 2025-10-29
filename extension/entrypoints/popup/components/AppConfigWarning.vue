<script lang="ts" setup>
/**
 * Warning banner component displayed when app configuration is incomplete.
 * Provides a link to open settings.
 *
 * @component
 */
import { Icon } from "@iconify/vue"

defineProps<{
  /** Whether the app is properly configured */
  isAppConfigured: boolean
}>()

/**
 * Opens the extension's settings page.
 */
function openSettings() {
  browser.runtime.openOptionsPage()
}
</script>

<template>
  <div
    v-if="!isAppConfigured"
    class="bg-yellow-100 text-yellow-800 px-3 py-2.5 rounded-md border border-yellow-200 text-[13px] leading-relaxed flex items-start gap-2"
  >
    <Icon icon="material-symbols:warning" class="w-4 h-4 mt-0.5 shrink-0" />
    <div>
      App configuration incomplete.
      <a
        class="text-yellow-800 underline cursor-pointer font-medium hover:text-yellow-900"
        @click="openSettings"
      >Click here to configure</a>
    </div>
  </div>
</template>
