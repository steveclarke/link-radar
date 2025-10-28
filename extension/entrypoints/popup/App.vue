<script lang="ts" setup>
import { useClipboard } from "@vueuse/core"
import { onMounted, ref } from "vue"
import LinkActions from "./components/LinkActions.vue"
import TagInput from "./components/TagInput.vue"
import { useApiKey } from "./composables/useApiKey"
import { useBookmark } from "./composables/useBookmark"
import { useCurrentTab } from "./composables/useCurrentTab"
import { useLinkOperations } from "./composables/useLinkOperations"
import { useNotification } from "./composables/useNotification"

// Composables
const { message, showSuccess, showError } = useNotification()
const { apiKeyConfigured, checkApiKey, openSettings } = useApiKey()
const { pageInfo, loadCurrentPageInfo } = useCurrentTab()
const { isBookmarked, bookmarkId, isChecking: isCheckingBookmark, checkIfBookmarked, resetBookmarkState } = useBookmark()
const { isUpdating, isDeleting, saveLink: saveLinkApi, updateLink: updateLinkApi, deleteLink: deleteLinkApi, loadLinkDetails } = useLinkOperations()
const { copy, isSupported } = useClipboard()

// Local form state
const notes = ref("")
const tags = ref<string[]>([])

// Initialize on mount
onMounted(async () => {
  await checkApiKey()
  const tabInfo = await loadCurrentPageInfo()

  if (tabInfo && apiKeyConfigured.value) {
    await checkBookmarkStatus(tabInfo.url)
  }
})

async function checkBookmarkStatus(url: string) {
  const result = await checkIfBookmarked(url)

  if (result?.exists && result.linkId) {
    const details = await loadLinkDetails(result.linkId)
    if (details) {
      tags.value = details.tags
      notes.value = details.note
    }
  }
  else {
    tags.value = []
    notes.value = ""
  }
}

async function handleSaveLink() {
  if (!pageInfo.value)
    return

  const linkData = {
    title: pageInfo.value.title,
    url: pageInfo.value.url,
    note: notes.value,
    tags: tags.value,
    saved_at: new Date().toISOString(),
  }

  const result = await saveLinkApi(linkData)

  if (result.success) {
    showSuccess("Link saved successfully!")
    notes.value = ""
    tags.value = []
    await checkBookmarkStatus(pageInfo.value.url)
  }
  else {
    showError(`Failed to save link: ${result.error || "Unknown error"}`)
  }
}

async function handleUpdateLink() {
  if (!bookmarkId.value)
    return

  const result = await updateLinkApi(bookmarkId.value, {
    note: notes.value,
    tags: tags.value,
  })

  if (result.success) {
    showSuccess("Link updated successfully!")
    const details = await loadLinkDetails(bookmarkId.value)
    if (details) {
      tags.value = details.tags
      notes.value = details.note
    }
  }
  else {
    showError(`Failed to update link: ${result.error || "Unknown error"}`)
  }
}

async function handleDeleteLink() {
  if (!bookmarkId.value)
    return

  const result = await deleteLinkApi(bookmarkId.value)

  if (result.success) {
    showSuccess("Link deleted successfully!")
    resetBookmarkState()
    notes.value = ""
    tags.value = []
  }
  else {
    showError(`Failed to delete link: ${result.error || "Unknown error"}`)
  }
}

async function copyToClipboard() {
  if (!pageInfo.value || !isSupported.value)
    return

  try {
    await copy(pageInfo.value.url)
    showSuccess("URL copied to clipboard!")
  }
  catch (error) {
    console.error("Error copying to clipboard:", error)
    showError("Failed to copy URL")
  }
}
</script>

<template>
  <div class="page-info">
    <div class="header">
      <h1>Link Radar</h1>
      <button class="settings-button" title="Settings" @click="openSettings">
        ⚙️
      </button>
    </div>

    <div v-if="!apiKeyConfigured" class="warning-banner">
      ⚠️ API key not configured.
      <a class="warning-link" @click="openSettings">Click here to set it up</a>
    </div>

    <div v-if="pageInfo" class="current-page">
      <h2>Current Page</h2>
      <div class="page-details">
        <img v-if="pageInfo.favicon" :src="pageInfo.favicon" class="favicon" alt="Site icon">
        <div class="page-text">
          <div class="page-title">
            {{ pageInfo.title }}
          </div>
          <div class="page-url">
            {{ pageInfo.url }}
          </div>
        </div>
      </div>
    </div>

    <div class="notes-section">
      <label for="notes">Add a note (optional):</label>
      <textarea id="notes" v-model="notes" placeholder="Add your thoughts about this link..." />
    </div>
    <TagInput v-model="tags" />

    <LinkActions
      :api-key-configured="apiKeyConfigured"
      :is-bookmarked="isBookmarked"
      :is-checking-bookmark="isCheckingBookmark"
      :is-deleting="isDeleting"
      :is-updating="isUpdating"
      @copy="copyToClipboard"
      @delete="handleDeleteLink"
      @save="handleSaveLink"
      @update="handleUpdateLink"
    />

    <div v-if="message" class="message" :class="[`message-${message.type}`]">
      {{ message.text }}
    </div>
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
  background: #f8f9fa;
}
</style>

<style scoped>
.page-info {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 16px;
  box-sizing: border-box;
}

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 12px;
}

h1 {
  margin: 0;
  font-size: 24px;
  color: #1a1a1a;
}

.settings-button {
  padding: 6px 10px;
  border: none;
  border-radius: 6px;
  background: #f8f9fa;
  cursor: pointer;
  font-size: 18px;
  transition: background-color 0.2s;
  line-height: 1;
}

.settings-button:hover {
  background: #e9ecef;
}

.vue-badge {
  font-size: 12px;
  background: linear-gradient(135deg, #42b883 0%, #35495e 100%);
  color: white;
  padding: 4px 8px;
  border-radius: 12px;
  font-weight: 600;
  letter-spacing: 0.5px;
}

h2 {
  margin: 0 0 8px 0;
  font-size: 16px;
  color: #333;
}

.current-page {
  background: white;
  border-radius: 8px;
  padding: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.page-details {
  display: flex;
  align-items: flex-start;
  gap: 8px;
}

.favicon {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
  margin-top: 2px;
}

.page-text {
  flex: 1;
  min-width: 0;
}

.page-title {
  font-weight: 500;
  color: #1a1a1a;
  margin-bottom: 4px;
  line-height: 1.3;
  word-wrap: break-word;
}

.page-url {
  font-size: 12px;
  color: #666;
  word-break: break-all;
  line-height: 1.2;
}

.warning-banner {
  background: #fff3cd;
  color: #856404;
  padding: 10px 12px;
  border-radius: 6px;
  border: 1px solid #ffeaa7;
  font-size: 13px;
  line-height: 1.4;
}

.warning-link {
  color: #856404;
  text-decoration: underline;
  cursor: pointer;
  font-weight: 500;
}

.warning-link:hover {
  color: #533f03;
}

.notes-section {
  background: white;
  border-radius: 8px;
  padding: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.notes-section label {
  display: block;
  font-size: 14px;
  font-weight: 500;
  color: #333;
  margin-bottom: 8px;
}

.notes-section textarea {
  width: 100%;
  min-height: 60px;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 14px;
  font-family: inherit;
  resize: vertical;
  box-sizing: border-box;
}

.notes-section textarea:focus {
  outline: none;
  border-color: #007bff;
  box-shadow: 0 0 0 2px rgba(0, 123, 255, 0.25);
}

.message {
  position: fixed;
  top: 16px;
  left: 16px;
  right: 16px;
  padding: 8px 12px;
  border-radius: 4px;
  font-size: 14px;
  font-weight: 500;
  z-index: 1000;
}

.message-success {
  background: #d4edda;
  color: #155724;
  border: 1px solid #c3e6cb;
}

.message-error {
  background: #f8d7da;
  color: #721c24;
  border: 1px solid #f5c6cb;
}
</style>
