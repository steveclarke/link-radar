<script lang="ts" setup>
import type { Environment } from "../settings"
import { Icon } from "@iconify/vue"
import { computed } from "vue"
import { ENVIRONMENT_BADGE_CONFIGS } from "../composables/useEnvironment"

/**
 * Reusable environment icon component that displays a colored circle
 * representing the current environment (production, local, custom).
 */

interface Props {
  /** The environment type to display */
  environment: Environment
  /** Icon size classes (Tailwind), defaults to w-3 h-3 */
  size?: string
}

const { size = "w-3 h-3", environment } = defineProps<Props>()

// Get configuration for the current environment
const config = computed(() => ENVIRONMENT_BADGE_CONFIGS[environment])
</script>

<template>
  <Icon
    :icon="config.icon"
    :style="{ color: config.iconColor }"
    :class="size"
  />
</template>
