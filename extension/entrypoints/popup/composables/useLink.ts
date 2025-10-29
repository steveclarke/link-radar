/**
 * @fileoverview Composable for managing link operations (CRUD).
 * Provides reactive state and methods for creating, reading, updating, and deleting links.
 */

import type { Link, LinkParams, LinkResult, UpdateLinkParams } from "../../../lib/types"
import { ref } from "vue"
import {
  createLink as apiCreateLink,
  deleteLink as apiDeleteLink,
  updateLink as apiUpdateLink,
  fetchLinkByUrl,
} from "../../../lib/apiClient"

/**
 * Composable for managing link CRUD operations.
 * Provides reactive state tracking for link existence, loading states,
 * and methods to perform operations via the API.
 */
export function useLink() {
  // State
  /** Whether the current URL exists as a saved link */
  const isLinked = ref(false)

  /** ID of the current link (null if not linked) */
  const linkId = ref<string | null>(null)

  /** Full link data from the API (null if not fetched or doesn't exist) */
  const link = ref<Link | null>(null)

  // Loading states
  /** Whether a fetch operation is in progress */
  const isFetching = ref(false)

  /** Whether a create operation is in progress */
  const isCreating = ref(false)

  /** Whether an update operation is in progress */
  const isUpdating = ref(false)

  /** Whether a delete operation is in progress */
  const isDeleting = ref(false)

  /**
   * Fetches a link by URL from the API.
   * Updates the link state if found, or resets state if not found.
   *
   * @param url - The URL to search for
   * @returns Promise resolving to Link if found, null otherwise
   */
  async function fetchLink(url: string) {
    isFetching.value = true
    try {
      const result = await fetchLinkByUrl(url)
      link.value = result
      isLinked.value = !!result
      linkId.value = result?.id || null
      return result
    }
    catch (error) {
      console.error("Error fetching link:", error)
      link.value = null
      isLinked.value = false
      linkId.value = null
      return null
    }
    finally {
      isFetching.value = false
    }
  }

  /**
   * Creates a new link via the API.
   *
   * @param data - Link parameters including url, title, and optional tag_names
   * @returns Promise resolving to LinkResult indicating success or error
   */
  async function createLink(data: LinkParams): Promise<LinkResult> {
    isCreating.value = true
    try {
      await apiCreateLink(data)
      return { success: true }
    }
    catch (error) {
      console.error("Error creating link:", error)
      const errorMessage = error instanceof Error ? error.message : "Error creating link"
      return { success: false, error: errorMessage }
    }
    finally {
      isCreating.value = false
    }
  }

  /**
   * Updates an existing link via the API.
   *
   * @param id - The ID of the link to update
   * @param data - Update parameters (partial link data including title and/or tag_names)
   * @returns Promise resolving to LinkResult indicating success or error
   */
  async function updateLink(id: string, data: UpdateLinkParams): Promise<LinkResult> {
    isUpdating.value = true
    try {
      await apiUpdateLink(id, data)
      return { success: true }
    }
    catch (error) {
      console.error("Error updating link:", error)
      const errorMessage = error instanceof Error ? error.message : "Error updating link"
      return { success: false, error: errorMessage }
    }
    finally {
      isUpdating.value = false
    }
  }

  /**
   * Deletes a link via the API.
   *
   * @param id - The ID of the link to delete
   * @returns Promise resolving to LinkResult indicating success or error
   */
  async function deleteLink(id: string): Promise<LinkResult> {
    isDeleting.value = true
    try {
      await apiDeleteLink(id)
      return { success: true }
    }
    catch (error) {
      console.error("Error deleting link:", error)
      const errorMessage = error instanceof Error ? error.message : "Error deleting link"
      return { success: false, error: errorMessage }
    }
    finally {
      isDeleting.value = false
    }
  }

  /**
   * Resets all link state to initial values.
   * Useful after deleting a link or navigating to a new URL.
   */
  function resetLinkState() {
    isLinked.value = false
    linkId.value = null
    link.value = null
  }

  /**
   * Sets the link state to linked with the given ID.
   * Useful after successfully creating a link.
   *
   * @param id - The ID of the newly created link
   */
  function setLinked(id: string) {
    isLinked.value = true
    linkId.value = id
  }

  return {
    // State
    isLinked,
    linkId,
    link,
    // Loading
    isFetching,
    isCreating,
    isUpdating,
    isDeleting,
    // Operations
    fetchLink,
    createLink,
    updateLink,
    deleteLink,
    // Helpers
    resetLinkState,
    setLinked,
  }
}
