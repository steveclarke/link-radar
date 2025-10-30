/**
 * @fileoverview Composable for managing link operations (CRUD).
 * Provides reactive state and methods for creating, reading, updating, and deleting links.
 */

import type { Link, LinkParams, LinkResult, UpdateLinkParams } from "../../../lib/types"
import { computed, ref } from "vue"
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
 * Uses a single source of truth (link ref) with computed convenience properties.
 */
export function useLink() {
  // State - Single source of truth
  /** Full link data from the API (null if not fetched or doesn't exist) */
  const link = ref<Link | null>(null)

  // Computed convenience properties derived from link
  /** Whether the current URL exists as a saved link (computed from link) */
  const isLinked = computed(() => !!link.value)

  /** ID of the current link (null if not linked, computed from link) */
  const linkId = computed(() => link.value?.id ?? null)

  // Loading states
  /** Whether a fetch operation is in progress */
  const isFetching = ref(false)

  /** Whether an update operation is in progress */
  const isUpdating = ref(false)

  /** Whether a delete operation is in progress */
  const isDeleting = ref(false)

  /**
   * Fetches a link by URL from the API.
   * Updates the link state if found, or resets state if not found.
   * The isLinked and linkId computed properties will automatically update.
   *
   * @param url - The URL to search for
   * @returns Promise resolving to Link if found, null otherwise
   */
  async function fetchLink(url: string) {
    isFetching.value = true
    try {
      const result = await fetchLinkByUrl(url)
      link.value = result
      return result
    }
    catch (error) {
      console.error("Error fetching link:", error)
      link.value = null
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
    try {
      await apiCreateLink(data)
      return { success: true }
    }
    catch (error) {
      console.error("Error creating link:", error)
      const errorMessage = error instanceof Error ? error.message : "Error creating link"
      return { success: false, error: errorMessage }
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
   * The isLinked and linkId computed properties will automatically reset.
   */
  function resetLinkState() {
    link.value = null
  }

  return {
    // State (single source of truth + computed conveniences)
    link,
    isLinked,
    linkId,
    // Loading
    isFetching,
    isUpdating,
    isDeleting,
    // Operations
    fetchLink,
    createLink,
    updateLink,
    deleteLink,
    // Helpers
    resetLinkState,
  }
}
