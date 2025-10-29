<script lang="ts" setup>
/**
 * Warning banner component displayed when API key is not configured.
 * Provides a link to open settings.
 *
 * @component
 */
import { Icon } from "@iconify/vue"
import { onMounted, ref } from "vue"
import { getActiveProfile } from "@/lib/settings"

/**
 * Whether the API key is configured for the active environment
 */
const isApiKeyConfigured = ref(true)

/**
 * Check if the API key is configured on mount
 */
onMounted(async () => {
  const profile = await getActiveProfile()
  isApiKeyConfigured.value = !!profile.apiKey
})

/**
 * Opens the extension's settings page.
 */
function openSettings() {
  browser.runtime.openOptionsPage()
}
</script>

<template>
  <div
    v-if="!isApiKeyConfigured"
    class="bg-yellow-100 text-yellow-800 px-3 py-2.5 rounded-md border border-yellow-200 text-[13px] leading-relaxed flex items-start gap-2"
  >
    <Icon icon="material-symbols:warning" class="w-4 h-4 mt-0.5 shrink-0" />
    <div>
      API key not configured.
      <a
        class="text-yellow-800 underline cursor-pointer font-medium hover:text-yellow-900"
        @click="openSettings"
      >Click here to set it up</a>
    </div>
  </div>
</template>
