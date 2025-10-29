<script lang="ts" setup>
import type { LinkParams } from "../../lib/types"
import { Icon } from "@iconify/vue"
import { useClipboard, useTimeoutFn } from "@vueuse/core"
import { onMounted, ref } from "vue"
import { getApiKey, getAutoCloseDelay } from "../../lib/settings"
import EnvironmentBadge from "./components/EnvironmentBadge.vue"
import LinkActions from "./components/LinkActions.vue"
import TagInput from "./components/TagInput.vue"
import { useCurrentTab } from "./composables/useCurrentTab"
import { useLink } from "./composables/useLink"
import { useNotification } from "./composables/useNotification"

// Composables
const { message, showSuccess, showError } = useNotification()
const { tabInfo, loadCurrentTab } = useCurrentTab()
const { isLinked, linkId, isFetching, isUpdating, isDeleting, fetchLink, createLink, updateLink, deleteLink, resetLinkState } = useLink()
const { copy, isSupported } = useClipboard()

// Local form state
const apiKeyConfigured = ref(false)
const notes = ref("")
const tagNames = ref<string[]>([])
const autoCloseDelay = ref(500)

// Initialize on mount
onMounted(async () => {
  const key = await getApiKey()
  apiKeyConfigured.value = !!key
  autoCloseDelay.value = await getAutoCloseDelay()
  const currentTab = await loadCurrentTab()

  if (currentTab && apiKeyConfigured.value) {
    await fetchCurrentLink(currentTab.url)
  }
})

async function fetchCurrentLink(url: string) {
  const result = await fetchLink(url)
  if (result) {
    // Extract tag names from Tag objects for the form
    tagNames.value = result.tags.map(tag => tag.name)
    notes.value = result.note
  }
  else {
    tagNames.value = []
    notes.value = ""
  }
}

async function handleCreateLink() {
  if (!tabInfo.value)
    return

  const linkParams: LinkParams = {
    title: tabInfo.value.title,
    url: tabInfo.value.url,
    note: notes.value,
    tag_names: tagNames.value,
  }

  const result = await createLink(linkParams)

  if (result.success) {
    showSuccess("Link saved successfully!")
    notes.value = ""
    tagNames.value = []
    await fetchCurrentLink(tabInfo.value.url)
    if (autoCloseDelay.value > 0) {
      useTimeoutFn(() => window.close(), autoCloseDelay.value, { immediate: true })
    }
  }
  else {
    showError(`Failed to save link: ${result.error || "Unknown error"}`)
  }
}

async function handleUpdateLink() {
  if (!linkId.value)
    return

  const result = await updateLink(linkId.value, {
    note: notes.value,
    tag_names: tagNames.value,
  })

  if (result.success) {
    showSuccess("Link updated successfully!")
    if (tabInfo.value)
      await fetchCurrentLink(tabInfo.value.url)
    if (autoCloseDelay.value > 0) {
      useTimeoutFn(() => window.close(), autoCloseDelay.value, { immediate: true })
    }
  }
  else {
    showError(`Failed to update link: ${result.error || "Unknown error"}`)
  }
}

async function handleDeleteLink() {
  if (!linkId.value)
    return

  const result = await deleteLink(linkId.value)

  if (result.success) {
    showSuccess("Link deleted successfully!")
    resetLinkState()
    notes.value = ""
    tagNames.value = []
    if (autoCloseDelay.value > 0) {
      useTimeoutFn(() => window.close(), autoCloseDelay.value, { immediate: true })
    }
  }
  else {
    showError(`Failed to delete link: ${result.error || "Unknown error"}`)
  }
}

async function copyToClipboard() {
  if (!tabInfo.value || !isSupported.value)
    return

  try {
    await copy(tabInfo.value.url)
    showSuccess("URL copied to clipboard!")
  }
  catch (error) {
    console.error("Error copying to clipboard:", error)
    showError("Failed to copy URL")
  }
}

function openSettings() {
  browser.runtime.openOptionsPage()
}
</script>

<template>
  <div class="flex flex-col gap-4 p-4 box-border">
    <div class="flex items-center justify-between gap-3">
      <div class="flex items-center gap-2">
        <h1 class="m-0 text-2xl text-gray-900">
          Link Radar
        </h1>
        <EnvironmentBadge />
      </div>
      <button class="px-2.5 py-1.5 border-none rounded-md bg-gray-100 cursor-pointer text-lg transition-colors duration-200 leading-none hover:bg-gray-200 flex items-center justify-center" title="Settings" @click="openSettings">
        <Icon icon="material-symbols:settings" class="w-5 h-5" />
      </button>
    </div>

    <div v-if="!apiKeyConfigured" class="bg-yellow-100 text-yellow-800 px-3 py-2.5 rounded-md border border-yellow-200 text-[13px] leading-relaxed flex items-start gap-2">
      <Icon icon="material-symbols:warning" class="w-4 h-4 mt-0.5 shrink-0" />
      <div>
        API key not configured.
        <a class="text-yellow-800 underline cursor-pointer font-medium hover:text-yellow-900" @click="openSettings">Click here to set it up</a>
      </div>
    </div>

    <div v-if="tabInfo" class="bg-white rounded-lg p-3 shadow-sm">
      <h2 class="m-0 mb-2 text-base text-gray-800">
        Current Page
      </h2>
      <div class="flex items-start gap-2">
        <img v-if="tabInfo.favicon" :src="tabInfo.favicon" class="w-4 h-4 shrink-0 mt-0.5" alt="Site icon">
        <div class="flex-1 min-w-0">
          <div class="font-medium text-gray-900 mb-1 leading-snug wrap-break-word">
            {{ tabInfo.title }}
          </div>
          <div class="text-xs text-gray-600 break-all leading-tight">
            {{ tabInfo.url }}
          </div>
        </div>
      </div>
    </div>

    <div class="bg-white rounded-lg p-3 shadow-sm">
      <label for="notes" class="block text-sm font-medium text-gray-800 mb-2">Add a note (optional):</label>
      <textarea id="notes" v-model="notes" class="w-full min-h-[60px] p-2 border border-gray-300 rounded text-sm resize-vertical box-border focus:outline-none focus:border-brand-600 focus:ring-2 focus:ring-brand-200" placeholder="Add your thoughts about this link..." />
    </div>
    <TagInput v-model="tagNames" />

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

    <div v-if="message" class="fixed top-4 left-4 right-4 px-3 py-2 rounded text-sm font-medium z-1000" :class="message.type === 'success' ? 'bg-green-100 text-green-800 border border-green-200' : 'bg-red-100 text-red-800 border border-red-200'">
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
