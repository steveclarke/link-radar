<script lang="ts" setup>
import type { BackendEnvironment } from "../settings"
import { Icon } from "@iconify/vue"
import { computed } from "vue"
import { getEnvironmentConfig } from "../../entrypoints/popup/composables/useEnvironmentConfig"

/**
 * Reusable environment icon component that displays a colored circle
 * representing the current backend environment (production, local, custom).
 */

interface Props {
  /** The backend environment type to display */
  environment: BackendEnvironment
  /** Icon size classes (Tailwind), defaults to w-3 h-3 */
  size?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: "w-3 h-3",
})

// Get configuration for the current environment
const config = computed(() => getEnvironmentConfig(props.environment))
</script>

<template>
  <Icon
    :icon="config.icon"
    :style="{ color: config.iconColor }"
    :class="size"
  />
</template>
