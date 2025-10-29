/**
 * @fileoverview Composable for managing all form handlers and business logic.
 * Consolidates link operations, notifications, and UI state management.
 */

import type { LinkParams } from "../../../lib/types"
import { useClipboard } from "@vueuse/core"
import { ref } from "vue"
import { useNotification } from "../../../lib/composables/useNotification"
import { DEFAULT_AUTO_CLOSE_DELAY, getActiveProfile, getAutoCloseDelay } from "../../../lib/settings"
import { useAutoClose } from "./useAutoClose"
import { useCurrentTab } from "./useCurrentTab"
import { useLink } from "./useLink"

/**
 * Composable that manages all form handlers and state for the popup.
 * Provides a centralized location for all business logic related to
 * link management, notifications, and clipboard operations.
 */
export function useFormHandlers() {
  // Composables
  const { showSuccess, showError } = useNotification()
  const { tabInfo, loadCurrentTab } = useCurrentTab()
  const { isLinked, linkId, isFetching, isUpdating, isDeleting, fetchLink, createLink, updateLink, deleteLink, resetLinkState } = useLink()
  const { copy, isSupported } = useClipboard()
  const { triggerAutoClose } = useAutoClose()

  // Local form state
  const apiKeyConfigured = ref(false)
  const url = ref("")
  const notes = ref("")
  const tagNames = ref<string[]>([])
  const autoCloseDelay = ref(DEFAULT_AUTO_CLOSE_DELAY)
  const isLoading = ref(false)

  /**
   * Initializes the form by loading configuration and current tab info.
   * Should be called on component mount.
   */
  async function initialize() {
    isLoading.value = true
    try {
      const profile = await getActiveProfile()
      apiKeyConfigured.value = !!profile.apiKey
      autoCloseDelay.value = await getAutoCloseDelay()
      const currentTab = await loadCurrentTab()

      if (currentTab) {
        url.value = currentTab.url
        if (apiKeyConfigured.value) {
          await fetchCurrentLink(currentTab.url)
        }
      }
    }
    finally {
      isLoading.value = false
    }
  }

  /**
   * Fetches the link data for a given URL and updates form state.
   *
   * @param url - The URL to fetch link data for
   */
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

  /**
   * Handles creating a new link from the current tab and form data.
   * Shows success/error notification and triggers auto-close on success.
   */
  async function handleCreateLink() {
    if (!tabInfo.value)
      return

    const linkParams: LinkParams = {
      title: tabInfo.value.title,
      url: url.value,
      note: notes.value,
      tag_names: tagNames.value,
    }

    const result = await createLink(linkParams)

    if (result.success) {
      showSuccess("Link saved successfully!")
      notes.value = ""
      tagNames.value = []
      await fetchCurrentLink(url.value)
      triggerAutoClose(autoCloseDelay.value)
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
      if (tabInfo.value)
        await fetchCurrentLink(tabInfo.value.url)
      triggerAutoClose(autoCloseDelay.value)
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
      if (tabInfo.value) {
        url.value = tabInfo.value.url
      }
      triggerAutoClose(autoCloseDelay.value)
    }
    else {
      showError(`Failed to delete link: ${result.error || "Unknown error"}`)
    }
  }

  /**
   * Copies the current tab's URL to the clipboard.
   * Shows success/error notification.
   */
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

  /**
   * Opens the extension's settings/options page.
   */
  function openSettings() {
    browser.runtime.openOptionsPage()
  }

  return {
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
    isLoading,
    // Handlers
    handleCreateLink,
    handleUpdateLink,
    handleDeleteLink,
    copyToClipboard,
    openSettings,
    initialize,
  }
}
