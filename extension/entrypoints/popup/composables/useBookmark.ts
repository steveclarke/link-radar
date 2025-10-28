import { ref } from "vue"

export interface BookmarkCheckResult {
  exists: boolean
  linkId: string | null
}

export function useBookmark() {
  const isBookmarked = ref(false)
  const bookmarkId = ref<string | null>(null)
  const isChecking = ref(false)

  async function checkIfBookmarked(url: string): Promise<BookmarkCheckResult | null> {
    isChecking.value = true

    try {
      const response = await chrome.runtime.sendMessage({
        type: "CHECK_LINK_EXISTS",
        url,
      })

      if (response.success) {
        isBookmarked.value = response.exists
        bookmarkId.value = response.linkId || null

        return {
          exists: response.exists,
          linkId: response.linkId || null,
        }
      }
      else {
        console.error("Failed to check bookmark status:", response.error)
        return null
      }
    }
    catch (error) {
      console.error("Error checking bookmark:", error)
      return null
    }
    finally {
      isChecking.value = false
    }
  }

  function resetBookmarkState() {
    isBookmarked.value = false
    bookmarkId.value = null
  }

  function setBookmarked(linkId: string) {
    isBookmarked.value = true
    bookmarkId.value = linkId
  }

  return {
    isBookmarked,
    bookmarkId,
    isChecking,
    checkIfBookmarked,
    resetBookmarkState,
    setBookmarked,
  }
}
