import type { Link, LinkParams, LinkResult, UpdateLinkParams } from "../../../lib/types"
import { ref } from "vue"
import {
  createLink as apiCreateLink,
  deleteLink as apiDeleteLink,
  updateLink as apiUpdateLink,
  fetchLinkByUrl,
} from "../../../lib/apiClient"

export function useLink() {
  // State
  const isLinked = ref(false)
  const linkId = ref<string | null>(null)
  const link = ref<Link | null>(null)

  // Loading states
  const isFetching = ref(false)
  const isCreating = ref(false)
  const isUpdating = ref(false)
  const isDeleting = ref(false)

  // Read
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

  // Create
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

  // Update
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

  // Delete
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

  function resetLinkState() {
    isLinked.value = false
    linkId.value = null
    link.value = null
  }

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
