<script lang="ts" setup>
import { computed } from "vue"
import { ENVIRONMENT_BADGE_CONFIGS, useEnvironment } from "../composables/useEnvironment"
import EnvironmentIcon from "./EnvironmentIcon.vue"

// Props
interface Props {
  showProduction?: boolean
}

const { showProduction = false } = defineProps<Props>()

// Get reactive environment from composable (automatically syncs across tabs)
const { environment, environmentConfig } = useEnvironment()

// Computed environment badge properties
const environmentBadge = computed(() => ENVIRONMENT_BADGE_CONFIGS[environment.value])

// Computed backend URL from current environment config
const activeBackendUrl = computed(() => environmentConfig.value?.url || "")
</script>

<template>
  <div
    v-if="showProduction || environment !== 'production'"
    class="px-2 py-0.5 rounded-full text-xs font-medium border flex items-center gap-1"
    :class="[
      environmentBadge.bgColor,
      environmentBadge.textColor,
      environmentBadge.borderColor,
    ]"
    :title="`Backend: ${activeBackendUrl}`"
  >
    <EnvironmentIcon :environment="environment" />
    {{ environmentBadge.label }}
  </div>
</template>
