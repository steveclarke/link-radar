import { ref } from "vue"

export interface LinkCheckResult {
  exists: boolean
  linkId: string | null
}

export function useLink() {
  const isLinked = ref(false)
  const linkId = ref<string | null>(null)
  const isChecking = ref(false)

  async function checkIfLinked(url: string): Promise<LinkCheckResult | null> {
    isChecking.value = true

    try {
      const response = await chrome.runtime.sendMessage({
        type: "CHECK_LINK_EXISTS",
        url,
      })

      if (response.success) {
        isLinked.value = response.exists
        linkId.value = response.linkId || null

        return {
          exists: response.exists,
          linkId: response.linkId || null,
        }
      }
      else {
        console.error("Failed to check link status:", response.error)
        return null
      }
    }
    catch (error) {
      console.error("Error checking link:", error)
      return null
    }
    finally {
      isChecking.value = false
    }
  }

  function resetLinkState() {
    isLinked.value = false
    linkId.value = null
  }

  function setLinked(linkId: string) {
    isLinked.value = true
    linkId.value = linkId
  }

  return {
    isLinked,
    linkId,
    isChecking,
    checkIfLinked,
    resetLinkState,
    setLinked,
  }
}

