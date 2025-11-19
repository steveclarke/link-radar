/**
 * AI Form Integration Composable
 *
 * Wraps useAiAnalysis and adds form-specific integration:
 * - Tag syncing: AI-selected tags automatically merge with manual tags in TagInput
 * - Note insertion: Selected note can be inserted into NotesInput
 * - State management: Resets AI state on tab changes
 *
 * Keeps LinkForm clean by encapsulating all AI-form orchestration logic here.
 * useAiAnalysis remains pure (AI logic only, reusable in other components).
 *
 * Pattern: Follows lightweight integration composable pattern for feature integration
 */

import type { Ref } from "vue"
import { watch } from "vue"
import { useAiAnalysis } from "./useAiAnalysis"

/**
 * AI Form Integration Composable
 *
 * Manages integration between AI analysis and form state.
 * Automatically syncs selected tags to main form field and handles note insertion.
 *
 * @param tagNamesRef - Reference to form's tagNames array
 * @param notesRef - Reference to form's notes string
 * @returns AI state and handlers for LinkForm to use
 *
 * @example
 *   const { state, handleAnalyze, handleToggleTag, handleAddNote, reset } = useAiFormIntegration(
 *     tagNames,
 *     notes
 *   )
 */
export function useAiFormIntegration(
  tagNamesRef: Ref<string[]>,
  notesRef: Ref<string>,
) {
  // Get AI analysis composable (pure AI logic)
  const { state: aiState, analyze, toggleTag, reset: resetAiState } = useAiAnalysis()

  // Track tags that existed BEFORE AI analysis (never remove these)
  let tagsBeforeAnalysis: string[] = []

  /**
   * Watch AI tag selections and add them to form's tagNames field
   *
   * Simple one-way sync: AI → Form
   * - When user clicks AI tag, add it to form
   * - When user unclicks AI tag, remove it from form
   * - NEVER removes tags that existed before analysis
   */
  watch(
    () => Array.from(aiState.value.selectedTagNames),
    (selectedAiTags: string[]) => {
      const currentTags = tagNamesRef.value

      // Keep all tags that:
      // 1. Existed before analysis (protected)
      // 2. Were manually added after analysis (not in AI suggestions)
      const protectedTags = currentTags.filter((tag) => {
        if (tagsBeforeAnalysis.includes(tag)) {
          return true
        }
        const isAiSuggestion = aiState.value.suggestedTags.some(st => st.name === tag)
        return !isAiSuggestion
      })

      // Merge: protected tags + selected AI tags (remove duplicates)
      const mergedTags = [...new Set([...protectedTags, ...selectedAiTags])]
      tagNamesRef.value = mergedTags
    },
    { deep: true },
  )

  /**
   * Trigger AI analysis for current page
   *
   * @param url - Page URL to analyze
   */
  async function handleAnalyze(url: string): Promise<void> {
    // Snapshot tags before analysis (these are protected from removal)
    tagsBeforeAnalysis = [...tagNamesRef.value]
    await analyze(url)
  }

  /**
   * Toggle AI tag selection and update form field
   *
   * @param tagName - Tag name to toggle
   */
  function handleToggleTag(tagName: string): void {
    toggleTag(tagName)
    // Watch above handles syncing to form automatically
  }

  /**
   * Insert AI-suggested note into form's notes field
   *
   * Replaces entire notes field with AI suggestion (user can edit after).
   *
   * @param note - Note text to insert
   */
  function handleAddNote(note: string): void {
    notesRef.value = note
  }

  /**
   * Reset AI state (call when tab changes)
   */
  function reset(): void {
    tagsBeforeAnalysis = []
    resetAiState()
  }

  return {
    state: aiState,
    handleAnalyze,
    handleToggleTag,
    handleAddNote,
    reset,
  }
}
