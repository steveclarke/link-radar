<script lang="ts" setup>
import { useClipboard } from "@vueuse/core"
import { onMounted, ref } from "vue"
import { STORAGE_KEYS } from "../../lib/config"
import LinkActions from "./components/LinkActions.vue"
import TagInput from "./components/TagInput.vue"

interface TabInfo {
  title: string
  url: string
  favicon?: string
}

const pageInfo = ref<TabInfo | null>(null)
const notes = ref("")
const tags = ref<string[]>([])
const message = ref<{ text: string, type: "success" | "error" } | null>(null)
const apiKeyConfigured = ref(false)
const isBookmarked = ref(false)
const bookmarkId = ref<string | null>(null)
const isCheckingBookmark = ref(false)
const isDeleting = ref(false)
const isUpdating = ref(false)

// Use VueUse clipboard composable
const { copy, isSupported } = useClipboard()

async function checkApiKey() {
  try {
    const result = await chrome.storage.sync.get(STORAGE_KEYS.API_KEY)
    apiKeyConfigured.value = !!result[STORAGE_KEYS.API_KEY]
  }
  catch (error) {
    console.error("Error checking API key:", error)
    apiKeyConfigured.value = false
  }
}

async function loadCurrentPageInfo() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true })

    if (!tab || !tab.url) {
      showError("Unable to access current page")
      return
    }

    pageInfo.value = {
      title: tab.title || "Untitled",
      url: tab.url,
      favicon: tab.favIconUrl,
    }

    // Check if this page is already bookmarked
    await checkIfBookmarked(tab.url)
  }
  catch (error) {
    console.error("Error getting tab info:", error)
    showError("Error loading page information")
  }
}

async function checkIfBookmarked(url: string) {
  if (!apiKeyConfigured.value) {
    // Don't check if API key is not configured
    return
  }

  isCheckingBookmark.value = true
  try {
    const response = await chrome.runtime.sendMessage({
      type: "CHECK_LINK_EXISTS",
      url,
    })

    if (response.success) {
      isBookmarked.value = response.exists
      bookmarkId.value = response.linkId || null

      if (response.exists && response.linkId) {
        await loadLinkDetails(response.linkId)
      }
      else {
        tags.value = []
        notes.value = ""
      }
    }
    else {
      console.error("Failed to check bookmark status:", response.error)
    }
  }
  catch (error) {
    console.error("Error checking bookmark:", error)
  }
  finally {
    isCheckingBookmark.value = false
  }
}

function openSettings() {
  chrome.runtime.openOptionsPage()
}

async function loadLinkDetails(linkId: string) {
  try {
    const response = await chrome.runtime.sendMessage({
      type: "GET_LINK_DETAILS",
      linkId,
    })

    if (response.success) {
      tags.value = response.link.tags ?? []
      notes.value = response.link.note ?? ""
    }
    else {
      console.error("Failed to load link details:", response.error)
    }
  }
  catch (error) {
    console.error("Error loading link details:", error)
  }
}

async function saveLink() {
  if (!pageInfo.value)
    return

  const linkData = {
    title: pageInfo.value.title,
    url: pageInfo.value.url,
    note: notes.value,
    tags: tags.value,
    saved_at: new Date().toISOString(),
  }

  try {
    const response = await chrome.runtime.sendMessage({
      type: "SAVE_LINK",
      data: linkData,
    })

    if (response.success) {
      showSuccess("Link saved successfully!")
      notes.value = ""
      tags.value = []
      // Update bookmark status
      isBookmarked.value = true
      await checkIfBookmarked(pageInfo.value.url)
    }
    else {
      showError(`Failed to save link: ${response.error || "Unknown error"}`)
    }
  }
  catch (error) {
    console.error("Error saving link:", error)
    showError("Error saving link")
  }
}

async function deleteBookmark() {
  if (!bookmarkId.value || !pageInfo.value)
    return

  isDeleting.value = true
  try {
    const response = await chrome.runtime.sendMessage({
      type: "DELETE_LINK",
      linkId: bookmarkId.value,
    })

    if (response.success) {
      showSuccess("Bookmark deleted successfully!")
      isBookmarked.value = false
      bookmarkId.value = null
      notes.value = ""
      tags.value = []
    }
    else {
      showError(`Failed to delete bookmark: ${response.error || "Unknown error"}`)
    }
  }
  catch (error) {
    console.error("Error deleting bookmark:", error)
    showError("Error deleting bookmark")
  }
  finally {
    isDeleting.value = false
  }
}

async function updateLink() {
  if (!bookmarkId.value)
    return

  isUpdating.value = true
  try {
    const response = await chrome.runtime.sendMessage({
      type: "UPDATE_LINK",
      linkId: bookmarkId.value,
      data: {
        note: notes.value,
        tags: tags.value,
      },
    })

    if (response.success) {
      showSuccess("Bookmark updated successfully!")
      await loadLinkDetails(bookmarkId.value)
    }
    else {
      showError(`Failed to update bookmark: ${response.error || "Unknown error"}`)
    }
  }
  catch (error) {
    console.error("Error updating bookmark:", error)
    showError("Error updating bookmark")
  }
  finally {
    isUpdating.value = false
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

function showSuccess(text: string) {
  showMessage(text, "success")
}

function showError(text: string) {
  showMessage(text, "error")
}

function showMessage(text: string, type: "success" | "error") {
  message.value = { text, type }
  // Error messages stay for 15 seconds, success messages for 3 seconds
  const timeout = type === "error" ? 15000 : 3000
  setTimeout(() => {
    message.value = null
  }, timeout)
}

onMounted(() => {
  checkApiKey()
  loadCurrentPageInfo()
})
</script>

<template>
  <div class="page-info">
    <div class="header">
      <div class="header-left">
        <h1>Link Radar</h1>
        <span class="vue-badge">⚡ Vue 3</span>
      </div>
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

    <LinkActions
      :api-key-configured="apiKeyConfigured"
      :is-bookmarked="isBookmarked"
      :is-checking-bookmark="isCheckingBookmark"
      :is-deleting="isDeleting"
      :is-updating="isUpdating"
      @copy="copyToClipboard"
      @delete="deleteBookmark"
      @save="saveLink"
      @update="updateLink"
    />

    <div class="notes-section">
      <label for="notes">Add a note (optional):</label>
      <textarea
        id="notes"
        v-model="notes"
        placeholder="Add your thoughts about this link..."
      />
    </div>
    <TagInput v-model="tags" />

    <div v-if="message" class="message" :class="[`message-${message.type}`]">
      {{ message.text }}
    </div>
  </div>
</template>

<style>
html, body {
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
