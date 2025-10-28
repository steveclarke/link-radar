import type { LinkData } from "../types"
import { ref } from "vue"

export interface LinkDetails {
  tags: string[]
  note: string
}

export interface SaveLinkResult {
  success: boolean
  error?: string
}

export interface UpdateLinkResult {
  success: boolean
  error?: string
}

export interface DeleteLinkResult {
  success: boolean
  error?: string
}

export function useLinkOperations() {
  const isSaving = ref(false)
  const isUpdating = ref(false)
  const isDeleting = ref(false)

  async function saveLink(linkData: LinkData): Promise<SaveLinkResult> {
    isSaving.value = true

    try {
      const response = await chrome.runtime.sendMessage({
        type: "SAVE_LINK",
        data: linkData,
      })

      if (response.success) {
        return { success: true }
      }
      else {
        return {
          success: false,
          error: response.error || "Unknown error",
        }
      }
    }
    catch (error) {
      console.error("Error saving link:", error)
      return {
        success: false,
        error: "Error saving link",
      }
    }
    finally {
      isSaving.value = false
    }
  }

  async function updateLink(linkId: string, data: { note: string, tags: string[] }): Promise<UpdateLinkResult> {
    isUpdating.value = true

    try {
      const response = await chrome.runtime.sendMessage({
        type: "UPDATE_LINK",
        linkId,
        data,
      })

      if (response.success) {
        return { success: true }
      }
      else {
        return {
          success: false,
          error: response.error || "Unknown error",
        }
      }
    }
    catch (error) {
      console.error("Error updating link:", error)
      return {
        success: false,
        error: "Error updating link",
      }
    }
    finally {
      isUpdating.value = false
    }
  }

  async function deleteLink(linkId: string): Promise<DeleteLinkResult> {
    isDeleting.value = true

    try {
      const response = await chrome.runtime.sendMessage({
        type: "DELETE_LINK",
        linkId,
      })

      if (response.success) {
        return { success: true }
      }
      else {
        return {
          success: false,
          error: response.error || "Unknown error",
        }
      }
    }
    catch (error) {
      console.error("Error deleting link:", error)
      return {
        success: false,
        error: "Error deleting link",
      }
    }
    finally {
      isDeleting.value = false
    }
  }

  async function loadLinkDetails(linkId: string): Promise<LinkDetails | null> {
    try {
      const response = await chrome.runtime.sendMessage({
        type: "GET_LINK_DETAILS",
        linkId,
      })

      if (response.success) {
        return {
          tags: response.link.tags ?? [],
          note: response.link.note ?? "",
        }
      }
      else {
        console.error("Failed to load link details:", response.error)
        return null
      }
    }
    catch (error) {
      console.error("Error loading link details:", error)
      return null
    }
  }

  return {
    isSaving,
    isUpdating,
    isDeleting,
    saveLink,
    updateLink,
    deleteLink,
    loadLinkDetails,
  }
}
