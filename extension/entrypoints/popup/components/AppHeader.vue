<script lang="ts" setup>
/**
 * App header component displaying the logo, title, environment badge, and settings button.
 *
 * @component
 */
import { Icon } from "@iconify/vue"
import EnvironmentBadge from "../../../lib/components/EnvironmentBadge.vue"

/**
 * Opens the extension's settings/options page.
 */
function openSettings() {
  browser.runtime.openOptionsPage()
}
</script>

<template>
  <div class="flex items-center justify-between gap-3">
    <div class="flex items-center gap-2">
      <h1 class="m-0 text-2xl text-slate-900">
        Link Radar
      </h1>
      <EnvironmentBadge />
    </div>
    <button
      class="px-2.5 py-1.5 border-none rounded-md bg-slate-100 cursor-pointer text-lg transition-colors duration-200 leading-none hover:bg-slate-200 flex items-center justify-center"
      title="Settings"
      @click="openSettings"
    >
      <Icon icon="material-symbols:settings" class="w-5 h-5" />
    </button>
  </div>
</template>
