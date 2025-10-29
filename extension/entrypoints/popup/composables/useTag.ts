import type { Tag } from "../../../lib/types"
import { ref } from "vue"
import { searchTags as apiSearchTags } from "../../../lib/apiClient"

export function useTag() {
  const isSearching = ref(false)
  const searchError = ref<string | null>(null)

  async function searchTags(query: string): Promise<Tag[]> {
    isSearching.value = true
    searchError.value = null
    try {
      return await apiSearchTags(query)
    }
    catch (error) {
      console.error("Error searching tags:", error)
      searchError.value = error instanceof Error ? error.message : "Failed to search tags"
      return []
    }
    finally {
      isSearching.value = false
    }
  }

  return {
    searchTags,
    isSearching,
    searchError,
  }
}
