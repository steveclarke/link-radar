<script lang="ts" setup>
import type { BackendEnvironment } from "../../../lib/settings"
import { computed, onMounted, onUnmounted, ref } from "vue"
import { getActiveBackendUrl, getBackendEnvironment, STORAGE_KEYS } from "../../../lib/settings"
import { getEnvironmentConfig } from "../composables/useEnvironmentConfig"
import EnvironmentIcon from "./EnvironmentIcon.vue"

// Props
interface Props {
  showProduction?: boolean
}

const { showProduction = false } = defineProps<Props>()

// State
const backendEnvironment = ref<BackendEnvironment>("production")
const activeBackendUrl = ref("")

// Computed environment badge properties using composable
const environmentBadge = computed(() => getEnvironmentConfig(backendEnvironment.value))

/**
 * Loads the current environment settings from browser storage.
 */
async function loadEnvironment() {
  backendEnvironment.value = await getBackendEnvironment()
  activeBackendUrl.value = await getActiveBackendUrl()
}

/**
 * Handles browser storage changes to keep the badge in sync.
 * Listens for changes to backend environment and environment profiles (which contain custom URL).
 */
function handleStorageChange(changes: Record<string, chrome.storage.StorageChange>) {
  // Check if backend environment or environment profiles changed
  // Environment profiles contain the custom URL
  if (changes[STORAGE_KEYS.BACKEND_ENVIRONMENT] || changes[STORAGE_KEYS.ENVIRONMENT_PROFILES]) {
    loadEnvironment()
  }
}

// Load environment on mount
onMounted(() => {
  loadEnvironment()
  // Listen for storage changes to keep badge reactive
  // Settings are stored in sync storage, so we need to listen there
  browser.storage.sync.onChanged.addListener(handleStorageChange)
})

// Clean up listener on unmount
onUnmounted(() => {
  browser.storage.sync.onChanged.removeListener(handleStorageChange)
})
</script>

<template>
  <div
    v-if="showProduction || backendEnvironment !== 'production'"
    class="px-2 py-0.5 rounded-full text-xs font-medium border flex items-center gap-1"
    :class="[
      environmentBadge.bgColor,
      environmentBadge.textColor,
      environmentBadge.borderColor,
    ]"
    :title="`Backend: ${activeBackendUrl}`"
  >
    <EnvironmentIcon :environment="backendEnvironment" />
    {{ environmentBadge.label }}
  </div>
</template>
