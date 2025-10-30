<script lang="ts" setup>
/**
 * API configuration section component for API key input.
 * Includes visibility toggle for showing/hiding the API key.
 * Uses v-model for two-way binding of API key value.
 *
 * @component
 */

import { Icon } from "@iconify/vue"

/**
 * Whether the API key should be shown in plain text (v-model)
 */
const showApiKey = defineModel<boolean>("showApiKey", { default: false })

/**
 * v-model for the API key string
 */
const apiKey = defineModel<string>({ default: "" })
</script>

<template>
  <div class="bg-white rounded-lg p-6 shadow-sm">
    <h2 class="m-0 mb-4 text-xl text-slate-900">
      API Configuration
    </h2>
    <p class="m-0 mb-5 text-sm text-slate-600 leading-normal">
      Enter your API key to enable link saving.
    </p>

    <div class="mb-5">
      <label for="api-key" class="block text-sm font-medium text-slate-800 mb-2">API Key</label>
      <div class="flex gap-2 items-stretch">
        <input
          id="api-key"
          v-model="apiKey"
          :type="showApiKey ? 'text' : 'password'"
          placeholder="Enter your API key"
          class="flex-1 px-3 py-2.5 border border-slate-300 rounded-md text-sm font-mono transition-colors focus:outline-none focus:border-brand-600 focus:ring-2 focus:ring-brand-200"
        >
        <button
          type="button"
          class="px-3 border border-slate-300 rounded-md bg-white cursor-pointer text-lg transition-colors hover:bg-slate-50 flex items-center justify-center"
          :title="showApiKey ? 'Hide API key' : 'Show API key'"
          @click="showApiKey = !showApiKey"
        >
          <Icon :icon="showApiKey ? 'material-symbols:visibility-off' : 'material-symbols:visibility'" class="w-5 h-5" />
        </button>
      </div>
    </div>
  </div>
</template>
