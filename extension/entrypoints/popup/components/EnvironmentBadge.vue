<script lang="ts" setup>
import type { BackendEnvironment } from "../../../lib/settings"
import { computed, onMounted, ref } from "vue"
import { getActiveBackendUrl, getBackendEnvironment } from "../../../lib/settings"
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

// Load environment on mount
onMounted(async () => {
  backendEnvironment.value = await getBackendEnvironment()
  activeBackendUrl.value = await getActiveBackendUrl()
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
