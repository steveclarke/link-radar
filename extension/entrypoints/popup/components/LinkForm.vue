<script lang="ts" setup>
/**
 * LinkForm component that manages link form state, operations, and UI.
 * Watches for tab changes, fetches link data, and handles CRUD operations.
 * Integrates AI analysis for suggested content and tags.
 *
 * @component
 */
import type { LinkParams, TabInfo } from "../../../lib/types"
import { ref, watch } from "vue"
import { useNotification } from "../../../lib/composables/useNotification"
import { useAiFormIntegration } from "../composables/useAiFormIntegration"
import { useAutoClose } from "../composables/useAutoClose"
import { useLink } from "../composables/useLink"
import AiAnalyzeButton from "./AiAnalyzeButton.vue"
import AiSuggestions from "./AiSuggestions.vue"
import LinkActions from "./LinkActions.vue"
import NotesInput from "./NotesInput.vue"
import TagInput from "./TagInput.vue"
import UrlInput from "./UrlInput.vue"

const props = defineProps<{
  /** Current browser tab information */
  currentTabInfo: TabInfo | null
  /** Whether the app is properly configured */
  isAppConfigured: boolean
}>()

// Composables
const { showSuccess, showError } = useNotification()
const { isLinked, linkId, isFetching, isUpdating, isDeleting, createLink, updateLink, deleteLink, resetLinkState, fetchLink } = useLink()
const { triggerAutoClose } = useAutoClose()

// Form state refs for AI integration
const url = ref("")
const notes = ref("")
const tagNames = ref<string[]>([])

// AI analysis integration
const { state: aiState, handleAnalyze, handleToggleTag, handleAddNote, reset: resetAiState } = useAiFormIntegration(tagNames, notes)

// Track visibility of AI suggestions panel (separate from state)
const showAiSuggestions = ref(false)

// Form state
const isCheckingLink = ref(false)

// Watch for tab changes and fetch/populate link data
watch(() => props.currentTabInfo, async (newTabInfo) => {
  if (!newTabInfo)
    return

  isCheckingLink.value = true
  try {
    // Reset AI analysis state and hide suggestions for new tab
    resetAiState()
    showAiSuggestions.value = false

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

/**
 * Handles creating a new link from the form data.
 * Shows success/error notification and triggers auto-close on success.
 */
async function handleCreateLink() {
  if (!props.currentTabInfo)
    return

  const linkParams: LinkParams = {
    title: props.currentTabInfo.title,
    url: url.value,
    note: notes.value,
    tag_names: tagNames.value,
  }

  const result = await createLink(linkParams)

  if (result.success) {
    showSuccess("Link saved successfully!")
    // Fetch the newly created link to get its ID and update state
    const newLink = await fetchLink(url.value)
    if (newLink) {
      // Update form with the saved link data
      notes.value = newLink.note
      tagNames.value = newLink.tags.map(t => t.name)
    }
    await triggerAutoClose()
  }
  else {
    showError(`Failed to save link: ${result.error || "Unknown error"}`)
  }
}

/**
 * Handles updating an existing link with new form data.
 * Shows success/error notification and triggers auto-close on success.
 */
async function handleUpdateLink() {
  if (!linkId.value)
    return

  const result = await updateLink(linkId.value, {
    note: notes.value,
    tag_names: tagNames.value,
  })

  if (result.success) {
    showSuccess("Link updated successfully!")
    // Re-fetch to keep state in sync
    const updatedLink = await fetchLink(url.value)
    if (updatedLink) {
      // Update form with the saved link data
      notes.value = updatedLink.note
      tagNames.value = updatedLink.tags.map(t => t.name)
    }
    await triggerAutoClose()
  }
  else {
    showError(`Failed to update link: ${result.error || "Unknown error"}`)
  }
}

/**
 * Handles deleting the current link.
 * Shows success/error notification and triggers auto-close on success.
 */
async function handleDeleteLink() {
  if (!linkId.value)
    return

  const result = await deleteLink(linkId.value)

  if (result.success) {
    showSuccess("Link deleted successfully!")
    resetLinkState()
    notes.value = ""
    tagNames.value = []
    await triggerAutoClose()
  }
  else {
    showError(`Failed to delete link: ${result.error || "Unknown error"}`)
  }
}

/**
 * Handles analysis click from AiAnalyzeButton.
 * Triggers AI analysis for current URL.
 */
async function onAnalyzeClick() {
  if (!props.currentTabInfo)
    return
  await handleAnalyze(props.currentTabInfo.url)
  showAiSuggestions.value = true
}

/**
 * Hide AI suggestions panel without resetting state
 */
function hideAiSuggestions() {
  showAiSuggestions.value = false
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
      <!-- AI Analysis Section (before all form fields) -->
      <AiAnalyzeButton
        :is-analyzing="aiState.isAnalyzing"
        :has-analyzed="aiState.suggestedTags.length > 0"
        :is-app-configured="isAppConfigured"
        @analyze="onAnalyzeClick"
      />

      <!-- AI Suggestions (shown after successful analysis) -->
      <AiSuggestions
        v-if="aiState.suggestedTags.length > 0 && showAiSuggestions"
        :suggested-note="aiState.suggestedNote"
        :suggested-tags="aiState.suggestedTags"
        :selected-tag-names="aiState.selectedTagNames"
        @toggle-tag="handleToggleTag"
        @add-note="handleAddNote"
        @close="hideAiSuggestions"
      />

      <UrlInput v-model="url" />
      <NotesInput v-model="notes" />
      <TagInput v-model="tagNames" />

      <!-- AI Error display -->
      <div v-if="aiState.error" class="text-sm text-red-600">
        {{ aiState.error }}
      </div>

      <LinkActions
        :is-linked="isLinked"
        :is-checking-link="isFetching"
        :is-deleting="isDeleting"
        :is-updating="isUpdating"
        :is-app-configured="isAppConfigured"
        @save="handleCreateLink"
        @update="handleUpdateLink"
        @delete="handleDeleteLink"
      />
    </template>
  </div>
</template>
