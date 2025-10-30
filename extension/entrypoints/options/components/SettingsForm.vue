<script lang="ts" setup>
/**
 * Settings form component that manages all form state and save logic.
 * Handles API configuration, popup behavior, and developer environment config.
 *
 * @component
 */

import type { Environment, EnvironmentConfigs } from "../../../lib/settings"
import { ref, toRaw, watch } from "vue"
import { useNotification } from "../../../lib/composables/useNotification"
import { useSettings } from "../../../lib/composables/useSettings"
import ApiConfigSection from "./ApiConfigSection.vue"
import EnvironmentConfig from "./EnvironmentConfig.vue"
import PopupBehaviorSection from "./PopupBehaviorSection.vue"

// Get reactive settings and update methods
const {
  isDeveloperMode,
  environment: savedEnvironment,
  environmentConfigs: savedEnvironmentConfigs,
  autoCloseDelay: savedAutoCloseDelay,
  updateEnvironment,
  updateEnvironmentConfigs,
  updateAutoCloseDelay,
} = useSettings()

const { showSuccess, showError } = useNotification()

// Local draft state (edited but not yet saved)
const draftEnvironment = ref<Environment>("production")
const draftEnvironmentConfigs = ref<EnvironmentConfigs>({
  production: { url: "", apiKey: "" },
  local: { url: "", apiKey: "" },
  custom: { url: "", apiKey: "" },
})
const draftAutoCloseDelay = ref(500)

// UI state
const showApiKeys = ref({
  production: false,
  local: false,
  custom: false,
})
const isSaving = ref(false)

/**
 * Reactively update draft state when saved settings change.
 *
 * Why we need the isSaving guard:
 * 1. User clicks "Save All Settings"
 * 2. We save configs → savedEnvironmentConfigs changes → this watch fires
 * 3. Watch would reset draft to old savedEnvironment (still "production")
 * 4. Then we save environment to "local" (too late - draft is reset!)
 *
 * The guard prevents watch from resetting draft during the multi-step save.
 * Once save completes, the watch will fire again and sync correctly.
 */
watch(
  [savedEnvironment, savedEnvironmentConfigs, savedAutoCloseDelay],
  () => {
    // Don't reset draft while we're actively saving to prevent race condition
    if (isSaving.value)
      return

    draftEnvironment.value = savedEnvironment.value
    // Deep clone prevents aliasing between draft and saved state refs
    // Without this, editing the draft would immediately update saved state
    // Use toRaw() to unwrap Vue reactive proxy before serializing
    draftEnvironmentConfigs.value = JSON.parse(JSON.stringify(toRaw(savedEnvironmentConfigs.value)))
    draftAutoCloseDelay.value = savedAutoCloseDelay.value
  },
  { immediate: true }, // Run on mount to initialize draft state
)

// Save all settings with validation
async function saveAllSettings() {
  // Always validate production API key (always visible in main form)
  if (!draftEnvironmentConfigs.value.production.apiKey.trim()) {
    showError("Please enter a production API key")
    return
  }

  // If in developer mode, validate the selected environment
  // Skip validation for 'local' - it's always configured from .env
  if (isDeveloperMode.value && draftEnvironment.value !== "local") {
    const currentConfig = draftEnvironmentConfigs.value[draftEnvironment.value]

    if (!currentConfig.apiKey.trim()) {
      showError(`Please enter an API key for ${draftEnvironment.value} environment`)
      return
    }

    // For custom environment, also validate URL
    if (draftEnvironment.value === "custom" && !currentConfig.url.trim()) {
      showError("Please enter a custom backend URL")
      return
    }
  }

  isSaving.value = true
  try {
    // Deep clone to avoid aliasing (draftEnvironmentConfigs and environmentConfigs
    // would become the same object reference without this)
    // Use toRaw() to unwrap Vue reactive proxy before serializing
    const configsToSave: EnvironmentConfigs = JSON.parse(JSON.stringify(toRaw(draftEnvironmentConfigs.value)))

    await updateEnvironmentConfigs(configsToSave)
    await updateAutoCloseDelay(draftAutoCloseDelay.value)
    await updateEnvironment(draftEnvironment.value)
    showSuccess("Settings saved successfully!")
  }
  catch (error) {
    console.error("Error saving settings:", error)
    const errorMessage = error instanceof Error ? error.message : "Unknown error"
    showError(`Failed to save settings: ${errorMessage}. Please try again.`)
  }
  finally {
    isSaving.value = false
  }
}
</script>

<template>
  <div>
    <div class="flex flex-col gap-6">
      <ApiConfigSection
        v-model="draftEnvironmentConfigs.production.apiKey"
        v-model:show-api-key="showApiKeys.production"
      />

      <PopupBehaviorSection v-model="draftAutoCloseDelay" />
    </div>

    <!-- Environment Configuration (only visible in developer mode) -->
    <div v-if="isDeveloperMode" class="mt-8 pt-8 border-t border-slate-200">
      <EnvironmentConfig
        v-model="draftEnvironment"
        v-model:environment-configs="draftEnvironmentConfigs"
        v-model:show-api-keys="showApiKeys"
      />
    </div>

    <!-- Save Button -->
    <div class="mt-8 flex justify-end">
      <button
        :disabled="isSaving"
        class="px-8 py-3 border-none rounded-md text-base font-medium bg-brand-600 text-white cursor-pointer transition-colors hover:bg-brand-700 disabled:opacity-60 disabled:cursor-not-allowed shadow-sm"
        @click="saveAllSettings"
      >
        {{ isSaving ? 'Saving...' : 'Save All Settings' }}
      </button>
    </div>
  </div>
</template>
