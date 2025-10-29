<script lang="ts" setup>
/**
 * Popup behavior configuration section component.
 * Allows users to configure auto-close delay with both slider and number input.
 * Uses v-model for two-way binding of delay value.
 *
 * @component
 */

import { computed } from "vue"

/**
 * v-model for the auto-close delay in milliseconds
 */
const autoCloseDelay = defineModel<number>({ default: 1500 })

/**
 * Computed label for the auto-close delay display
 */
const delayLabel = computed(() => {
  return autoCloseDelay.value === 0 ? "Disabled" : `${autoCloseDelay.value}ms`
})
</script>

<template>
  <div class="bg-white rounded-lg p-6 shadow-sm">
    <h3 class="m-0 mb-4 text-xl text-slate-900">
      Popup Behavior
    </h3>
    <p class="m-0 mb-5 text-sm text-slate-600 leading-normal">
      Control how long the popup stays open after saving, updating, or deleting a link.
      Set to 0 to disable auto-close (popup stays open).
    </p>

    <div class="mb-4">
      <label for="auto-close-delay" class="block text-sm font-medium text-slate-800 mb-2">
        Auto-close delay: <span class="font-semibold text-brand-600">{{ delayLabel }}</span>
      </label>
      <div class="flex gap-3 items-center">
        <input
          id="auto-close-delay"
          v-model.number="autoCloseDelay"
          type="range"
          min="0"
          max="2000"
          step="500"
          class="flex-1 h-2 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-brand-600"
        >
        <input
          v-model.number="autoCloseDelay"
          type="number"
          min="0"
          max="2000"
          placeholder="ms"
          class="w-24 px-3 py-2 border border-slate-300 rounded-md text-sm text-right transition-colors focus:outline-none focus:border-brand-600 focus:ring-2 focus:ring-brand-200"
        >
      </div>
      <p class="mt-2 text-xs text-slate-500">
        Recommended values: 0 (disabled), 500ms (quick), 1000ms (medium), 1500ms (slower), 2000ms (slowest)
      </p>
    </div>
  </div>
</template>
