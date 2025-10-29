<script lang="ts" setup>
/**
 * Settings page orchestrator component for the Link Radar browser extension.
 * Provides UI for configuring environment profiles, auto-close delay, and developer mode settings.
 * Uses composables for business logic and components for UI sections.
 *
 * @component
 */
import { onMounted } from "vue"
import NotificationToast from "../../lib/components/NotificationToast.vue"
import ApiConfigSection from "./components/ApiConfigSection.vue"
import BackendEnvironmentConfig from "./components/BackendEnvironmentConfig.vue"
import PopupBehaviorSection from "./components/PopupBehaviorSection.vue"
import SettingsHeader from "./components/SettingsHeader.vue"
import { useOptionsSettings } from "./composables/useOptionsSettings"

const {
  // State
  profiles,
  showApiKeys,
  autoCloseDelay,
  developerMode,
  backendEnvironment,
  isSaving,
  // Methods
  loadSettings,
  saveSettings,
} = useOptionsSettings()

onMounted(loadSettings)
</script>

<template>
  <div class="max-w-5xl mx-auto p-6 font-sans">
    <SettingsHeader v-model="developerMode" />

    <div class="flex flex-col gap-6">
      <ApiConfigSection
        v-model="profiles.production.apiKey"
        v-model:show-api-key="showApiKeys.production"
      />

      <PopupBehaviorSection v-model="autoCloseDelay" />
    </div>

    <!-- Global Save Button -->
    <div class="mt-8 flex justify-end">
      <button
        :disabled="isSaving"
        class="px-8 py-3 border-none rounded-md text-base font-medium bg-brand-600 text-white cursor-pointer transition-colors hover:bg-brand-700 disabled:opacity-60 disabled:cursor-not-allowed shadow-sm"
        @click="saveSettings"
      >
        {{ isSaving ? 'Saving...' : 'Save All Settings' }}
      </button>
    </div>

    <!-- Backend Environment Configuration (only visible in developer mode) -->
    <div v-if="developerMode" class="mt-8 pt-8 border-t border-slate-200">
      <BackendEnvironmentConfig
        v-model="backendEnvironment"
        v-model:profiles="profiles"
        v-model:show-api-keys="showApiKeys"
      />
    </div>

    <NotificationToast />
  </div>
</template>
