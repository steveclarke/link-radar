/**
 * AI Analysis Composable
 *
 * Manages the complete lifecycle of AI analysis:
 * - Triggering analysis (extract content → call API → handle response)
 * - Loading and error states
 * - Tag selection state (Set for O(1) lookups)
 * - Suggestions display
 * - Reset on tab change
 *
 * Used by AiAnalyzeButton and AiSuggestions components.
 * Provides reactive state and actions for the AI analysis feature.
 *
 * Pattern: Follows useLink and useNotification composable patterns in codebase
 */

import type { AnalysisState } from "../../../lib/types/ai-analysis"
import { useAsyncState } from "@vueuse/core"
import { computed, reactive } from "vue"
import { analyzeLink } from "../../../lib/apiClient"
import { extractPageContent } from "../../../lib/contentExtractor"
import { isSafeToAnalyze } from "../../../lib/urlValidation"

/**
 * Custom error class for analysis failures with structured error codes
 */
class AnalysisError extends Error {
  constructor(
    public code: "TIMEOUT" | "PRIVACY" | "EXTRACTION" | "API_ERROR",
    message: string,
  ) {
    super(message)
    this.name = "AnalysisError"
  }
}

/**
 * Composable for AI analysis state and operations
 *
 * Provides:
 * - state: Reactive analysis state (loading, error, suggestions, selections)
 * - analyze(): Trigger analysis for current page
 * - toggleTag(): Toggle tag selection on/off
 * - getSelectedTags(): Get array of selected tag names
 * - reset(): Clear all state (call on tab change)
 *
 * @returns Analysis state and operations
 *
 * @example Basic usage in component
 *   const { state, analyze, toggleTag, getSelectedTags } = useAiAnalysis()
 *
 *   // Trigger analysis
 *   await analyze(currentUrl)
 *
 *   // Toggle tag selection
 *   toggleTag('JavaScript')
 *
 *   // Get selected tags for main input
 *   const selected = getSelectedTags() // => ['JavaScript', 'TypeScript']
 */
export function useAiAnalysis() {
  /**
   * Timeout for AI analysis (backend takes 3-5 seconds, allow 15s total for network delays)
   */
  const ANALYSIS_TIMEOUT_MS = 15_000

  /**
   * User's tag selections (separate from API response)
   */
  const selectedTagNames = reactive(new Set<string>())

  /**
   * Async state management using VueUse
   * Handles loading/error states automatically for the analysis operation
   */
  const {
    state: apiResponse,
    isLoading: isAnalyzing,
    error: analysisError,
    execute: performAnalysis,
  } = useAsyncState(
    async (url: string) => {
      // Privacy check (client-side, immediate feedback)
      if (!isSafeToAnalyze(url)) {
        throw new AnalysisError("PRIVACY", "Cannot analyze localhost or private URLs")
      }

      // Extract page content
      let extracted
      try {
        extracted = extractPageContent()
      }
      catch {
        throw new AnalysisError("EXTRACTION", "Failed to extract page content")
      }

      // Create a promise that rejects after ANALYSIS_TIMEOUT_MS (15 seconds)
      // This ensures we don't wait forever if the backend hangs or network is slow
      // Promise<never> means this promise will only ever fail, never succeed
      const timeoutPromise = new Promise<never>((_resolve, reject: (reason: Error) => void) =>
        setTimeout(
          () => reject(new AnalysisError("TIMEOUT", "Analysis timed out")),
          ANALYSIS_TIMEOUT_MS,
        ),
      )

      // Make the API call
      const analysisPromise = analyzeLink({
        url,
        content: extracted.content,
        title: extracted.title,
        description: extracted.description,
        author: extracted.author,
      })

      // Promise.race([promise1, promise2]) = whichever settles first wins
      // If API responds in 3 seconds: returns API response
      // If API takes 20 seconds: timeout rejects first with AnalysisError('TIMEOUT', ...)
      return Promise.race([analysisPromise, timeoutPromise])
    },
    null,
    { immediate: false, throwError: true },
  )

  /**
   * Combine API response with user selections into AnalysisState
   * useAsyncState handles isAnalyzing and error, we just map the API data
   */
  const state = computed<AnalysisState>(() => ({
    isAnalyzing: isAnalyzing.value,
    error: analysisError.value ? formatAnalysisError(analysisError.value as Error) : null,
    suggestedNote: apiResponse.value?.data?.suggested_note || null,
    suggestedTags: apiResponse.value?.data?.suggested_tags || [],
    selectedTagNames,
  }))

  /**
   * Convert AnalysisError to user-friendly message based on error code
   */
  function formatAnalysisError(error: Error): string {
    if (error instanceof AnalysisError) {
      switch (error.code) {
        case "TIMEOUT":
          return "Analysis timed out. Try again?"
        case "PRIVACY":
          return "Cannot analyze localhost or private URLs"
        case "EXTRACTION":
          return "Failed to extract page content"
        case "API_ERROR":
          return "Analysis failed. Please try again."
      }
    }
    return "Analysis failed. Please try again."
  }

  /**
   * Trigger AI analysis for the given URL
   *
   * Clears previous tag selections and runs analysis with timeout protection.
   *
   * @param url - Page URL to analyze
   *
   * @example
   *   await analyze('https://example.com')
   */
  async function analyze(url: string): Promise<void> {
    selectedTagNames.clear()
    // execute(delay, ...args) - 0ms means execute immediately, then pass url to async function
    await performAnalysis(0, url)
  }

  /**
   * Toggle tag selection on/off
   *
   * If tag is selected: deselect it (remove from Set)
   * If tag is not selected: select it (add to Set)
   *
   * Uses Set (not Array) for performance: Set.has() is O(1) - constant time lookup,
   * always instant regardless of how many tags are selected. With an Array, checking
   * if an item exists (includes()) would be O(n) - slower as the collection grows.
   *
   * Since toggleTag() gets called frequently during UI interactions, we need fast lookups.
   *
   * @param tagName - Name of tag to toggle
   *
   * @example
   *   toggleTag('JavaScript') // Selects 'JavaScript'
   *   toggleTag('JavaScript') // Deselects 'JavaScript'
   */
  function toggleTag(tagName: string): void {
    if (selectedTagNames.has(tagName)) {
      selectedTagNames.delete(tagName)
    }
    else {
      selectedTagNames.add(tagName)
    }

    // Trigger Vue reactivity by reassigning the Set
    // This is necessary because Set mutations don't trigger Vue's reactivity
    const newSet = new Set(selectedTagNames)
    selectedTagNames.clear()
    newSet.forEach(name => selectedTagNames.add(name))
  }

  /**
   * Get currently selected tag names as array
   *
   * Converts Set to Array for easy consumption by parent components.
   * Used to populate main TagInput field with selected suggestions.
   *
   * @returns Array of selected tag names
   *
   * @example
   *   const selected = getSelectedTags()
   *   // => ['JavaScript', 'TypeScript', 'Web Development']
   */
  function getSelectedTags(): string[] {
    return Array.from(state.value.selectedTagNames)
  }

  /**
   * Reset analysis state
   *
   * Clears all state back to initial values:
   * - No loading, no error
   * - No suggestions
   * - No selections
   *
   * Call this when:
   * - User navigates to different tab
   * - User closes popup
   * - Starting fresh analysis session
   *
   * @example
   *   // In LinkForm, watch for tab changes
   *   watch(() => props.currentTabInfo, () => {
   *     reset() // Clear AI state for new tab
   *   })
   */
  function reset(): void {
    selectedTagNames.clear()
  }

  return {
    state,
    analyze,
    toggleTag,
    getSelectedTags,
    reset,
  }
}
