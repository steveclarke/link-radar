<script lang="ts" setup>
/**
 * Reusable environment option component for backend environment selection.
 * Displays a radio button option with status badge and expandable configuration panel.
 *
 * @component
 */
import type { BackendEnvironment } from "../../../lib/settings"
import { computed } from "vue"
import EnvironmentLabel from "../../../lib/components/EnvironmentLabel.vue"

const props = defineProps<{
  /** The environment type (production, local, custom) */
  environment: BackendEnvironment
  /** Whether this environment is currently selected */
  isSelected: boolean
  /** Whether this environment is configured with required fields */
  isConfigured: boolean
  /** The URL for this environment */
  url: string
}>()

const emit = defineEmits<{
  /** Emitted when this environment option is selected */
  select: []
}>()

/**
 * Computed status badge based on configuration state
 */
const statusBadge = computed(() => {
  if (props.isConfigured) {
    return {
      text: "Configured ✓",
      classes: "text-green-700 bg-green-50 border-green-200",
    }
  }
  return {
    text: "Setup Required",
    classes: "text-orange-700 bg-orange-50 border-orange-200",
  }
})
</script>

<template>
  <div class="border border-brand-300 rounded-lg p-4 bg-white">
    <label class="flex items-start gap-3 cursor-pointer group mb-3">
      <input
        type="radio"
        :checked="isSelected"
        class="mt-1 w-4 h-4 accent-brand-600 cursor-pointer"
        @change="emit('select')"
      >
      <div class="flex-1">
        <div class="flex items-center gap-2">
          <div class="font-medium text-brand-900 group-hover:text-brand-700">
            <EnvironmentLabel :environment="environment" />
          </div>
          <span
            class="text-xs px-2 py-0.5 rounded-full border"
            :class="statusBadge.classes"
          >
            {{ statusBadge.text }}
          </span>
        </div>
        <div class="text-xs text-brand-700 mt-0.5">
          {{ url }}
        </div>
      </div>
    </label>

    <!-- Config panel (shown when selected) - content provided via slot -->
    <div v-if="isSelected" class="ml-7 mt-3 space-y-3">
      <slot />
    </div>
  </div>
</template>
