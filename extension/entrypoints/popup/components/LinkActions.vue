<script lang="ts" setup>
import { computed } from "vue"

const props = defineProps<{
  isLinked: boolean
  isCheckingLink: boolean
  isDeleting: boolean
  isUpdating: boolean
  apiKeyConfigured: boolean
}>()

const emit = defineEmits<{
  save: []
  update: []
  delete: []
  copy: []
}>()

const isSaveDisabled = computed(() => !props.apiKeyConfigured || props.isCheckingLink)
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
