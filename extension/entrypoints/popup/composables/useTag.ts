/**
 * @fileoverview Composable for tag search operations.
 * Provides reactive state and methods for searching tags via the API.
 */

import type { Tag } from "../../../lib/types"
import { ref } from "vue"
import { searchTags as apiSearchTags } from "../../../lib/apiClient"

/**
 * Composable for managing tag search operations.
 * Provides reactive loading and error states along with a search method
 * for querying tags from the API. Returns empty array on error.
 */
export function useTag() {
  /** Whether a tag search operation is in progress */
  const isSearching = ref(false)

  /** Error message from the last search operation (null if no error) */
  const searchError = ref<string | null>(null)

  /**
   * Searches for tags matching the given query string.
   * Returns an empty array if the search fails or encounters an error.
   *
   * @param query - The search term to filter tags by
   * @returns Promise resolving to array of matching tags (empty array on error)
   */
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
