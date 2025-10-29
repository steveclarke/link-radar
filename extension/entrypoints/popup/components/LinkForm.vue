<script lang="ts" setup>
/**
 * LinkForm component that encapsulates all link-related form UI.
 * Manages form state and handles link CRUD operations.
 *
 * @component
 */
import type { TabInfo } from "../../../lib/types"
import { ref, watch } from "vue"
import { useLinkForm } from "../composables/useLinkForm"
import LinkActions from "./LinkActions.vue"
import NotesInput from "./NotesInput.vue"
import TagInput from "./TagInput.vue"
import UrlInput from "./UrlInput.vue"

const props = defineProps<{
  /** Current browser tab information */
  currentTabInfo: TabInfo | null
  /** Whether the app is configured and ready to use */
  isAppReady: boolean
}>()

const {
  url,
  notes,
  tagNames,
  isLinked,
  isFetching,
  isUpdating,
  isDeleting,
  handleCreateLink,
  handleUpdateLink,
  handleDeleteLink,
  fetchLink,
} = useLinkForm()

const isCheckingLink = ref(false)

// Check if link exists when tab info is available
watch(() => props.currentTabInfo, async (newTabInfo) => {
  if (!newTabInfo)
    return

  isCheckingLink.value = true
  try {
    // Set URL from current tab
    url.value = newTabInfo.url

    // Check if this URL is already saved as a link
    const existingLink = await fetchLink(newTabInfo.url)

    if (existingLink) {
      // Populate form fields with existing link data
      notes.value = existingLink.note
      tagNames.value = existingLink.tags.map(t => t.name)
    }
    else {
      // Clear form fields for new link
      notes.value = ""
      tagNames.value = []
    }
  }
  finally {
    isCheckingLink.value = false
  }
}, { immediate: true })

// Wrap handleCreateLink to pass tab title
function handleSave() {
  if (props.currentTabInfo) {
    handleCreateLink(props.currentTabInfo.title)
  }
}
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Loading state while checking if link exists -->
    <div v-if="isCheckingLink" class="text-center py-4">
      <p class="text-slate-600 text-sm">
        Checking link...
      </p>
    </div>

    <!-- Form content shows after checking -->
    <template v-else>
      <NotesInput v-model="notes" />
      <TagInput v-model="tagNames" />
      <UrlInput v-model="url" />
      <LinkActions
        :is-linked="isLinked"
        :is-checking-link="isFetching"
        :is-deleting="isDeleting"
        :is-updating="isUpdating"
        :api-key-configured="isAppReady"
        @save="handleSave"
        @update="handleUpdateLink"
        @delete="handleDeleteLink"
      />
    </template>
  </div>
</template>
