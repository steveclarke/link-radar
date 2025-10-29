<script lang="ts" setup>
/**
 * Action button component for managing links.
 * Displays different button sets based on whether the current URL is already saved.
 * Buttons are automatically disabled when API key is not configured or operations are in progress.
 *
 * @component
 */
import { Icon } from "@iconify/vue"
import { computed } from "vue"
import CopyUrlButton from "./CopyUrlButton.vue"

/**
 * Component props
 */
const props = defineProps<{
  /** Whether the current URL is already saved as a link */
  isLinked: boolean
  /** Whether the component is currently checking if the link exists */
  isCheckingLink: boolean
  /** Whether a delete operation is in progress */
  isDeleting: boolean
  /** Whether an update operation is in progress */
  isUpdating: boolean
  /** Whether the API key is configured */
  apiKeyConfigured: boolean
}>()

/**
 * Component events
 */
const emit = defineEmits<{
  /** Emitted when the user clicks "Save This Link" to create a new link */
  save: []
  /** Emitted when the user clicks "Update" to update an existing link */
  update: []
  /** Emitted when the user clicks "Delete" to remove an existing link */
  delete: []
}>()

/**
 * Computed property that determines if the Save button should be disabled.
 * Disabled when API key is not configured or link check is in progress.
 */
const isSaveDisabled = computed(() => !props.apiKeyConfigured || props.isCheckingLink)

/**
 * Computed property that determines if the Update button should be disabled.
 * Disabled when API key is not configured or update operation is in progress.
 */
const isUpdateDisabled = computed(() => !props.apiKeyConfigured || props.isUpdating)

/**
 * Computed property that determines if the Delete button should be disabled.
 * Disabled when API key is not configured or delete operation is in progress.
 */
const isDeleteDisabled = computed(() => !props.apiKeyConfigured || props.isDeleting)
</script>

<template>
  <div class="flex justify-between items-center gap-3">
    <!-- Primary Action Button (Left) -->
    <button
      v-if="!isLinked"
      class="px-4 py-2 border-none rounded-md text-sm font-medium cursor-pointer transition-all duration-200 bg-brand-600 text-white hover:bg-brand-700 disabled:opacity-50 disabled:cursor-not-allowed"
      type="button"
      :disabled="isSaveDisabled"
      @click="emit('save')"
    >
      {{ isCheckingLink ? "Checking..." : "Save This Link" }}
    </button>
    <button
      v-else
      class="px-4 py-2 border-none rounded-md text-sm font-medium cursor-pointer transition-all duration-200 bg-brand-600 text-white hover:bg-brand-700 disabled:opacity-50 disabled:cursor-not-allowed"
      type="button"
      :disabled="isUpdateDisabled"
      @click="emit('update')"
    >
      {{ isUpdating ? "Updating..." : "Update" }}
    </button>

    <!-- Secondary Action Buttons (Right) -->
    <div class="flex gap-2">
      <!-- Delete button (only shown when linked) -->
      <button
        v-if="isLinked"
        class="w-9 h-9 p-0 border-none rounded-md cursor-pointer transition-all duration-200 bg-slate-200 hover:bg-slate-300 disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center"
        type="button"
        title="Delete link"
        aria-label="Delete link"
        :disabled="isDeleteDisabled"
        @click="emit('delete')"
      >
        <Icon
          icon="material-symbols:delete-outline"
          class="w-5 h-5 text-slate-600"
        />
      </button>

      <!-- Copy URL button (always shown) -->
      <CopyUrlButton />
    </div>
  </div>
</template>
