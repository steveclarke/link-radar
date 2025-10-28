import type { LinkData } from "../types"
import { ref } from "vue"

export interface LinkOperationResult {
  success: boolean
  error?: string
}

export function useLink() {
  // State
  const isLinked = ref(false)
  const linkId = ref<string | null>(null)
  const link = ref<{ id: string, tags: string[], note: string } | null>(null)

  // Loading states
  const isFetching = ref(false)
  const isCreating = ref(false)
  const isUpdating = ref(false)
  const isDeleting = ref(false)

  // Read
  async function fetchLink(url: string) {
    isFetching.value = true
    try {
      const response = await browser.runtime.sendMessage({
        type: "FETCH_LINK",
        url,
      })

      if (response.success) {
        const result = response.link || null
        link.value = result
        isLinked.value = !!result
        linkId.value = result?.id || null
        return result
      }
      else {
        console.error("Failed to fetch link:", response.error)
        link.value = null
        isLinked.value = false
        linkId.value = null
        return null
      }
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
  async function createLink(data: LinkData): Promise<LinkOperationResult> {
    isCreating.value = true
    try {
      const response = await browser.runtime.sendMessage({
        type: "CREATE_LINK",
        data,
      })
      if (response.success)
        return { success: true }
      return { success: false, error: response.error || "Unknown error" }
    }
    catch (error) {
      console.error("Error creating link:", error)
      return { success: false, error: "Error creating link" }
    }
    finally {
      isCreating.value = false
    }
  }

  // Update
  async function updateLink(id: string, data: { note: string, tags: string[] }): Promise<LinkOperationResult> {
    isUpdating.value = true
    try {
      const response = await browser.runtime.sendMessage({
        type: "UPDATE_LINK",
        linkId: id,
        data,
      })
      if (response.success)
        return { success: true }
      return { success: false, error: response.error || "Unknown error" }
    }
    catch (error) {
      console.error("Error updating link:", error)
      return { success: false, error: "Error updating link" }
    }
    finally {
      isUpdating.value = false
    }
  }

  // Delete
  async function deleteLink(id: string): Promise<LinkOperationResult> {
    isDeleting.value = true
    try {
      const response = await browser.runtime.sendMessage({
        type: "DELETE_LINK",
        linkId: id,
      })
      if (response.success)
        return { success: true }
      return { success: false, error: response.error || "Unknown error" }
    }
    catch (error) {
      console.error("Error deleting link:", error)
      return { success: false, error: "Error deleting link" }
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
