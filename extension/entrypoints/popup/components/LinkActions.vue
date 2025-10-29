<script lang="ts" setup>
/**
 * Action button component for managing links.
 * Displays different button sets based on whether the current URL is already saved.
 * Buttons are automatically disabled when API key is not configured or operations are in progress.
 *
 * @component
 */
import { computed } from "vue"

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
  /** Whether the API key has been configured (required for save/update/delete) */
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
  /** Emitted when the user clicks "Copy URL" to copy the current URL to clipboard */
  copy: []
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

/**
 * Handles the Save button click.
 * Emits the 'save' event if the button is not disabled.
 */
function handleSave() {
  if (isSaveDisabled.value)
    return
  emit("save")
}

/**
 * Handles the Update button click.
 * Emits the 'update' event if the button is not disabled.
 */
function handleUpdate() {
  if (isUpdateDisabled.value)
    return
  emit("update")
}

/**
 * Handles the Delete button click.
 * Emits the 'delete' event if the button is not disabled.
 */
function handleDelete() {
  if (isDeleteDisabled.value)
    return
  emit("delete")
}

/**
 * Handles the Copy URL button click.
 * Emits the 'copy' event (always enabled).
 */
function handleCopy() {
  emit("copy")
}
</script>

<template>
  <div class="flex gap-2">
    <template v-if="!isLinked">
      <button
        class="flex-1 px-3 py-2 border-none rounded-md text-sm font-medium cursor-pointer transition-all duration-200 bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
        type="button"
        :disabled="isSaveDisabled"
        @click="handleSave"
      >
        {{ isCheckingLink ? "Checking..." : "Save This Link" }}
      </button>
      <button class="flex-1 px-3 py-2 border-none rounded-md text-sm font-medium cursor-pointer transition-colors duration-200 bg-gray-600 text-white hover:bg-gray-700" type="button" @click="handleCopy">
        Copy URL
      </button>
    </template>
    <template v-else>
      <button
        class="flex-1 px-3 py-2 border-none rounded-md text-sm font-medium cursor-pointer transition-all duration-200 bg-cyan-600 text-white hover:bg-cyan-700 disabled:opacity-50 disabled:cursor-not-allowed"
        type="button"
        :disabled="isUpdateDisabled"
        @click="handleUpdate"
      >
        {{ isUpdating ? "Updating..." : "Update" }}
      </button>
      <button
        class="flex-1 px-3 py-2 border-none rounded-md text-sm font-medium cursor-pointer transition-all duration-200 bg-red-600 text-white hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed"
        type="button"
        :disabled="isDeleteDisabled"
        @click="handleDelete"
      >
        {{ isDeleting ? "Deleting..." : "Delete" }}
      </button>
      <button class="flex-1 px-3 py-2 border-none rounded-md text-sm font-medium cursor-pointer transition-colors duration-200 bg-gray-600 text-white hover:bg-gray-700" type="button" @click="handleCopy">
        Copy URL
      </button>
    </template>
  </div>
</template>
