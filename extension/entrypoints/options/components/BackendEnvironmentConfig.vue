<script lang="ts" setup>
/**
 * Backend environment configuration component.
 * Allows selecting between production, local dev, and custom environments,
 * each with their own URL and API key settings.
 */
import type { BackendEnvironment, EnvironmentProfiles } from "../../../lib/settings"
import { Icon } from "@iconify/vue"
import { BACKEND_URL, DEV_BACKEND_URL } from "../../../lib/settings"
import EnvironmentLabel from "../../popup/components/EnvironmentLabel.vue"

/**
 * Component props
 */
defineProps<{
  /** Whether to show/hide API keys */
  showApiKeys: {
    production: boolean
    local: boolean
    custom: boolean
  }
}>()

/**
 * Component events
 */
defineEmits<{
  /** Emitted when API key visibility should be toggled */
  toggleApiKey: [environment: BackendEnvironment]
}>()

/** Currently selected backend environment with two-way binding */
const selectedEnvironment = defineModel<BackendEnvironment>({ required: true })

/** Environment profiles with two-way binding */
const localProfiles = defineModel<EnvironmentProfiles>("profiles", { required: true })

/**
 * Check if a profile is configured (has required fields)
 */
function isProfileConfigured(environment: BackendEnvironment): boolean {
  const profile = localProfiles.value[environment]
  if (environment === "custom") {
    return !!profile.url && !!profile.apiKey
  }
  // Production and local need at least an API key (URL comes from env vars)
  return !!profile.apiKey
}

/**
 * Get configuration status badge for an environment
 */
function getConfigStatus(environment: BackendEnvironment): { text: string, classes: string } {
  if (isProfileConfigured(environment)) {
    return {
      text: "Configured ✓",
      classes: "text-green-700 bg-green-50 border-green-200",
    }
  }
  return {
    text: "Setup Required",
    classes: "text-orange-700 bg-orange-50 border-orange-200",
  }
}
</script>

<template>
  <div class="bg-brand-50 border border-brand-200 rounded-lg p-6">
    <div class="flex items-start gap-3">
      <div class="text-2xl">
        <Icon icon="material-symbols:info" class="w-6 h-6 text-brand-600" />
      </div>
      <div class="flex-1">
        <h3 class="m-0 mb-4 text-lg font-semibold text-brand-900">
          Backend Environment
        </h3>

        <!-- Environment Selection -->
        <div class="mb-4">
          <label class="block text-sm font-medium text-brand-900 mb-3">
            Select Backend Environment:
          </label>
          <div class="space-y-4">
            <!-- Production Environment -->
            <div class="border border-brand-300 rounded-lg p-4 bg-white">
              <label class="flex items-start gap-3 cursor-pointer group mb-3">
                <input
                  v-model="selectedEnvironment"
                  type="radio"
                  value="production"
                  class="mt-1 w-4 h-4 accent-brand-600 cursor-pointer"
                >
                <div class="flex-1">
                  <div class="flex items-center gap-2">
                    <div class="font-medium text-brand-900 group-hover:text-brand-700">
                      <EnvironmentLabel environment="production" />
                    </div>
                    <span class="text-xs px-2 py-0.5 rounded-full border" :class="getConfigStatus('production').classes">
                      {{ getConfigStatus('production').text }}
                    </span>
                  </div>
                  <div class="text-xs text-brand-700 mt-0.5">
                    {{ BACKEND_URL }}
                  </div>
                </div>
              </label>

              <!-- Production Config Panel -->
              <div v-if="selectedEnvironment === 'production'" class="ml-7 mt-3 space-y-3">
                <div class="text-xs text-brand-600 bg-brand-50 p-3 rounded border border-brand-200">
                  <p class="m-0">
                    <strong>Production environment uses the API key configured in the main settings section above.</strong>
                    Scroll up to the "API Configuration" section to set or change your production API key.
                  </p>
                </div>
              </div>
            </div>

            <!-- Local Development Environment -->
            <div class="border border-brand-300 rounded-lg p-4 bg-white">
              <label class="flex items-start gap-3 cursor-pointer group mb-3">
                <input
                  v-model="selectedEnvironment"
                  type="radio"
                  value="local"
                  class="mt-1 w-4 h-4 accent-brand-600 cursor-pointer"
                >
                <div class="flex-1">
                  <div class="flex items-center gap-2">
                    <div class="font-medium text-brand-900 group-hover:text-brand-700">
                      <EnvironmentLabel environment="local" />
                    </div>
                    <span class="text-xs px-2 py-0.5 rounded-full border" :class="getConfigStatus('local').classes">
                      {{ getConfigStatus('local').text }}
                    </span>
                  </div>
                  <div class="text-xs text-brand-700 mt-0.5">
                    {{ DEV_BACKEND_URL }}
                  </div>
                </div>
              </label>

              <!-- Local Dev Config Panel (Read-only) -->
              <div v-if="selectedEnvironment === 'local'" class="ml-7 mt-3 space-y-3">
                <div class="text-xs text-brand-600 bg-brand-50 p-3 rounded border border-brand-200">
                  <p class="m-0">
                    <strong>Local development uses defaults from environment variables.</strong>
                    URL and API key are configured at build time for zero-config development.
                  </p>
                </div>
                <div>
                  <label class="block text-xs font-medium text-brand-800 mb-1">API Key (from .env)</label>
                  <input
                    v-model="localProfiles.local.apiKey"
                    type="text"
                    readonly
                    class="w-full px-3 py-2 border border-brand-300 bg-brand-50 rounded-md text-sm font-mono text-brand-600"
                  >
                </div>
              </div>
            </div>

            <!-- Custom Environment -->
            <div class="border border-brand-300 rounded-lg p-4 bg-white">
              <label class="flex items-start gap-3 cursor-pointer group mb-3">
                <input
                  v-model="selectedEnvironment"
                  type="radio"
                  value="custom"
                  class="mt-1 w-4 h-4 accent-brand-600 cursor-pointer"
                >
                <div class="flex-1">
                  <div class="flex items-center gap-2">
                    <div class="font-medium text-brand-900 group-hover:text-brand-700">
                      <EnvironmentLabel environment="custom" />
                    </div>
                    <span class="text-xs px-2 py-0.5 rounded-full border" :class="getConfigStatus('custom').classes">
                      {{ getConfigStatus('custom').text }}
                    </span>
                  </div>
                  <div class="text-xs text-brand-700 mt-0.5">
                    Specify your own backend URL (e.g., staging environment)
                  </div>
                </div>
              </label>

              <!-- Custom Config Panel -->
              <div v-if="selectedEnvironment === 'custom'" class="ml-7 mt-3 space-y-3">
                <div>
                  <label class="block text-xs font-medium text-brand-800 mb-1">Backend URL</label>
                  <input
                    v-model="localProfiles.custom.url"
                    type="url"
                    placeholder="https://api.example.com/api/v1"
                    class="w-full px-3 py-2 border border-brand-300 rounded-md text-sm font-mono transition-colors focus:outline-none focus:border-brand-600 focus:ring-2 focus:ring-brand-200"
                  >
                </div>
                <div>
                  <label class="block text-xs font-medium text-brand-800 mb-1">API Key</label>
                  <div class="flex gap-2">
                    <input
                      v-model="localProfiles.custom.apiKey"
                      :type="showApiKeys.custom ? 'text' : 'password'"
                      placeholder="Enter custom API key"
                      class="flex-1 px-3 py-2 border border-brand-300 rounded-md text-sm font-mono transition-colors focus:outline-none focus:border-brand-600 focus:ring-2 focus:ring-brand-200"
                    >
                    <button
                      type="button"
                      class="px-3 border border-brand-300 rounded-md bg-white cursor-pointer transition-colors hover:bg-brand-100 flex items-center justify-center"
                      :title="showApiKeys.custom ? 'Hide API key' : 'Show API key'"
                      @click="$emit('toggleApiKey', 'custom')"
                    >
                      <Icon :icon="showApiKeys.custom ? 'material-symbols:visibility-off' : 'material-symbols:visibility'" class="w-5 h-5" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
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
