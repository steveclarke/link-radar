/**
 * Composable that manages link form state and operations.
 * Handles form state (url, notes, tags) and CRUD operations.
 */
import type { LinkParams } from "../../../lib/types"
import { ref } from "vue"
import { useNotification } from "../../../lib/composables/useNotification"
import { useAutoClose } from "./useAutoClose"
import { useLink } from "./useLink"

export function useLinkForm() {
  // Composables
  const { showSuccess, showError } = useNotification()
  const { isLinked, linkId, isFetching, isUpdating, isDeleting, createLink, updateLink, deleteLink, resetLinkState, fetchLink } = useLink()
  const { triggerAutoClose } = useAutoClose()

  // Local form state
  const url = ref("")
  const notes = ref("")
  const tagNames = ref<string[]>([])

  /**
   * Handles creating a new link from the form data.
   * Shows success/error notification and triggers auto-close on success.
   * Re-fetches the link after creation to update state with the new link ID.
   *
   * @param tabTitle - The title from the current tab
   */
  async function handleCreateLink(tabTitle: string) {
    const linkParams: LinkParams = {
      title: tabTitle,
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
   * Re-fetches the link after update to keep state in sync.
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

  return {
    // State
    url,
    notes,
    tagNames,
    isLinked,
    linkId,
    isFetching,
    isUpdating,
    isDeleting,
    // Handlers
    handleCreateLink,
    handleUpdateLink,
    handleDeleteLink,
    // Helpers
    fetchLink,
    resetLinkState,
  }
}
