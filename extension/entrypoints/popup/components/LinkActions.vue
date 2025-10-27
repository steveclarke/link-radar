<script lang="ts" setup>
import { computed } from "vue"

const props = defineProps<{
  isBookmarked: boolean
  isCheckingBookmark: boolean
  isDeleting: boolean
  isUpdating: boolean
  apiKeyConfigured: boolean
}>()

const emit = defineEmits<{
  (event: "save"): void
  (event: "update"): void
  (event: "delete"): void
  (event: "copy"): void
}>()

const isSaveDisabled = computed(() => !props.apiKeyConfigured || props.isCheckingBookmark)
const isUpdateDisabled = computed(() => !props.apiKeyConfigured || props.isUpdating)
const isDeleteDisabled = computed(() => !props.apiKeyConfigured || props.isDeleting)

function handleSave() {
  if (isSaveDisabled.value)
    return
  emit("save")
}

function handleUpdate() {
  if (isUpdateDisabled.value)
    return
  emit("update")
}

function handleDelete() {
  if (isDeleteDisabled.value)
    return
  emit("delete")
}

function handleCopy() {
  emit("copy")
}
</script>

<template>
  <div class="actions">
    <template v-if="!isBookmarked">
      <button
        class="save-button"
        type="button"
        :disabled="isSaveDisabled"
        @click="handleSave"
      >
        {{ isCheckingBookmark ? "Checking..." : "Save This Link" }}
      </button>
      <button class="copy-button" type="button" @click="handleCopy">
        Copy URL
      </button>
    </template>
    <template v-else>
      <button
        class="update-button"
        type="button"
        :disabled="isUpdateDisabled"
        @click="handleUpdate"
      >
        {{ isUpdating ? "Updating..." : "Update" }}
      </button>
      <button
        class="delete-button"
        type="button"
        :disabled="isDeleteDisabled"
        @click="handleDelete"
      >
        {{ isDeleting ? "Deleting..." : "Delete" }}
      </button>
      <button class="copy-button" type="button" @click="handleCopy">
        Copy URL
      </button>
    </template>
  </div>
</template>

<style scoped>
.actions {
  display: flex;
  gap: 8px;
}

button {
  flex: 1;
  padding: 8px 12px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s, opacity 0.2s;
}

.save-button {
  background: #007bff;
  color: #fff;
}

.save-button:hover:not(:disabled) {
  background: #0056b3;
}

.save-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.update-button {
  background: #17a2b8;
  color: #fff;
}

.update-button:hover:not(:disabled) {
  background: #138496;
}

.update-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.delete-button {
  background: #dc3545;
  color: #fff;
}

.delete-button:hover:not(:disabled) {
  background: #c82333;
}

.delete-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.copy-button {
  background: #6c757d;
  color: #fff;
}

.copy-button:hover {
  background: #545b62;
}
</style>
