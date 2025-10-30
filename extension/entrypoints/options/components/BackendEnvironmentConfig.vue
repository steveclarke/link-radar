<script lang="ts" setup>
/**
 * Environment configuration component.
 * Allows selecting between production, local dev, and custom environments,
 * each with their own URL and API key settings.
 */
import type { Environment, EnvironmentConfigs } from "../../../lib/settings"
import { Icon } from "@iconify/vue"
import { BACKEND_URL, DEV_BACKEND_URL } from "../../../lib/settings"
import { useOptionsSettings } from "../composables/useOptionsSettings"
import EnvironmentOption from "./EnvironmentOption.vue"

/** Currently selected environment with two-way binding */
const selectedEnvironment = defineModel<Environment>({ required: true })

/** Environment configurations with two-way binding */
const configs = defineModel<EnvironmentConfigs>("environmentConfigs", { required: true })

/** Whether to show/hide API keys (v-model) */
const showApiKeys = defineModel<{
  production: boolean
  local: boolean
  custom: boolean
}>("showApiKeys", { required: true })

// Get business logic from composable
const { isConfigured } = useOptionsSettings()
</script>

<template>
  <div class="bg-brand-50 border border-brand-200 rounded-lg p-6">
    <div class="flex items-start gap-3">
      <div class="text-2xl">
        <Icon icon="material-symbols:info" class="w-6 h-6 text-brand-600" />
      </div>
      <div class="flex-1">
        <h3 class="m-0 mb-4 text-lg font-semibold text-brand-900">
          Environment Configuration
        </h3>

        <!-- Environment Selection -->
        <div class="mb-4">
          <label class="block text-sm font-medium text-brand-900 mb-3">
            Select Environment:
          </label>
          <div class="space-y-4">
            <!-- Production Environment -->
            <EnvironmentOption
              environment="production"
              :is-selected="selectedEnvironment === 'production'"
              :is-configured="isConfigured('production', configs)"
              :url="BACKEND_URL"
              @select="selectedEnvironment = 'production'"
            >
              <div class="text-xs text-brand-600 bg-brand-50 p-3 rounded border border-brand-200">
                <p class="m-0">
                  <strong>Production environment uses the API key configured in the main settings section above.</strong>
                  Scroll up to the "API Configuration" section to set or change your production API key.
                </p>
              </div>
            </EnvironmentOption>

            <!-- Local Development Environment -->
            <EnvironmentOption
              environment="local"
              :is-selected="selectedEnvironment === 'local'"
              :is-configured="isConfigured('local', configs)"
              :url="DEV_BACKEND_URL"
              @select="selectedEnvironment = 'local'"
            >
              <div class="text-xs text-brand-600 bg-brand-50 p-3 rounded border border-brand-200">
                <p class="m-0">
                  <strong>Local development uses defaults from environment variables.</strong>
                  URL and API key are configured at build time for zero-config development.
                </p>
              </div>
              <div>
                <label class="block text-xs font-medium text-brand-800 mb-1">API Key (from .env)</label>
                <input
                  v-model="configs.local.apiKey"
                  type="text"
                  readonly
                  class="w-full px-3 py-2 border border-brand-300 bg-brand-50 rounded-md text-sm font-mono text-brand-600"
                >
              </div>
            </EnvironmentOption>

            <!-- Custom Environment -->
            <EnvironmentOption
              environment="custom"
              :is-selected="selectedEnvironment === 'custom'"
              :is-configured="isConfigured('custom', configs)"
              url="Specify your own backend URL (e.g., staging environment)"
              @select="selectedEnvironment = 'custom'"
            >
              <div>
                <label class="block text-xs font-medium text-brand-800 mb-1">Backend URL</label>
                <input
                  v-model="configs.custom.url"
                  type="url"
                  placeholder="https://api.example.com/api/v1"
                  class="w-full px-3 py-2 border border-brand-300 rounded-md text-sm font-mono transition-colors focus:outline-none focus:border-brand-600 focus:ring-2 focus:ring-brand-200"
                >
              </div>
              <div>
                <label class="block text-xs font-medium text-brand-800 mb-1">API Key</label>
                <div class="flex gap-2">
                  <input
                    v-model="configs.custom.apiKey"
                    :type="showApiKeys.custom ? 'text' : 'password'"
                    placeholder="Enter custom API key"
                    class="flex-1 px-3 py-2 border border-brand-300 rounded-md text-sm font-mono transition-colors focus:outline-none focus:border-brand-600 focus:ring-2 focus:ring-brand-200"
                  >
                  <button
                    type="button"
                    class="px-3 border border-brand-300 rounded-md bg-white cursor-pointer transition-colors hover:bg-brand-100 flex items-center justify-center"
                    :title="showApiKeys.custom ? 'Hide API key' : 'Show API key'"
                    @click="showApiKeys.custom = !showApiKeys.custom"
                  >
                    <Icon :icon="showApiKeys.custom ? 'material-symbols:visibility-off' : 'material-symbols:visibility'" class="w-5 h-5" />
                  </button>
                </div>
              </div>
            </EnvironmentOption>
          </div>
        </div>

        <div class="pt-4 mt-4 border-t border-brand-300">
          <p class="m-0 text-xs text-brand-700 italic">
            <strong>Note:</strong> Each environment has its own URL and API key configuration.
            Switching environments automatically uses the correct settings.
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
