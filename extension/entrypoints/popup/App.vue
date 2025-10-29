<script lang="ts" setup>
import { onMounted } from "vue"
import NotificationToast from "../../lib/components/NotificationToast.vue"
import ApiKeyWarning from "./components/ApiKeyWarning.vue"
import AppHeader from "./components/AppHeader.vue"
import LinkActions from "./components/LinkActions.vue"
import NotesInput from "./components/NotesInput.vue"
import PageInfoDisplay from "./components/PageInfoDisplay.vue"
import TagInput from "./components/TagInput.vue"
import UrlInput from "./components/UrlInput.vue"
import { useFormHandlers } from "./composables/useFormHandlers"

const {
  // State
  apiKeyConfigured,
  tabInfo,
  url,
  notes,
  tagNames,
  isLinked,
  isFetching,
  isUpdating,
  isDeleting,
  // Handlers
  handleCreateLink,
  handleUpdateLink,
  handleDeleteLink,
  copyToClipboard,
  openSettings,
  initialize,
} = useFormHandlers()

onMounted(initialize)
</script>

<template>
  <div class="flex flex-col gap-4 p-4 box-border">
    <AppHeader @open-settings="openSettings" />
    <ApiKeyWarning />
    <PageInfoDisplay :tab-info="tabInfo" />
    <NotesInput v-model="notes" />
    <TagInput v-model="tagNames" />
    <UrlInput v-model="url" />
    <LinkActions
      :api-key-configured="apiKeyConfigured"
      :is-linked="isLinked"
      :is-checking-link="isFetching"
      :is-deleting="isDeleting"
      :is-updating="isUpdating"
      @copy="copyToClipboard"
      @delete="handleDeleteLink"
      @save="handleCreateLink"
      @update="handleUpdateLink"
    />
    <NotificationToast />
  </div>
</template>

<style>
html,
body {
  width: 400px;
  min-height: 300px;
  margin: 0;
  box-sizing: border-box;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  background: #f8fafc;
}
</style>
