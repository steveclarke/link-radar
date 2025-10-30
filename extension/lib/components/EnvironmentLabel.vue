<script lang="ts" setup>
import type { Environment } from "../settings"
import { computed } from "vue"
import { getEnvironmentConfig } from "../../entrypoints/popup/composables/useEnvironmentConfig"
import EnvironmentIcon from "./EnvironmentIcon.vue"

/**
 * Presentational component that displays an environment icon with its label text.
 * Used in static contexts like the Options page where we show available environment choices.
 */

interface Props {
  /** The environment type to display */
  environment: Environment
}

const props = defineProps<Props>()

// Get configuration for the current environment
const config = computed(() => getEnvironmentConfig(props.environment))
</script>

<template>
  <div class="flex items-center gap-1.5">
    <EnvironmentIcon :environment="environment" />
    {{ config.label }}
  </div>
</template>
