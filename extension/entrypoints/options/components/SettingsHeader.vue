<script lang="ts" setup>
/**
 * Settings page header component with title, environment badge, and developer mode toggle.
 * Accesses global isDeveloperMode state from useSettings.
 *
 * @component
 */

import { useSettings } from "../../../lib/composables/useSettings"
import EnvironmentBadge from "../../../lib/components/EnvironmentBadge.vue"

// Access global isDeveloperMode state (writable computed ref)
const { isDeveloperMode } = useSettings()
</script>

<template>
  <div class="mb-8 flex items-start justify-between">
    <div>
      <div class="flex items-center gap-3 mb-2">
        <h1 class="m-0 text-[32px] text-slate-900">
          Link Radar Settings
        </h1>
        <EnvironmentBadge />
      </div>
      <p class="m-0 text-base text-slate-600">
        Configure your Link Radar extension
      </p>
    </div>
    <div class="flex items-center gap-3">
      <span class="text-sm font-medium text-slate-700">
        Developer Mode
      </span>
      <button
        type="button"
        class="relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-brand-600 focus:ring-offset-2"
        :class="isDeveloperMode ? 'bg-brand-600' : 'bg-slate-200'"
        role="switch"
        :aria-checked="isDeveloperMode"
        @click="isDeveloperMode = !isDeveloperMode"
      >
        <span
          class="pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out"
          :class="isDeveloperMode ? 'translate-x-5' : 'translate-x-0'"
        />
      </button>
    </div>
  </div>
</template>
