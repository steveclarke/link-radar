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

  /**
   * Watch AI tag selections and sync to form's tagNames field
   *
   * Logic:
   * 1. Get currently selected AI tags (from aiState.value.selectedTagNames)
   * 2. Get manually-entered tags (tags in form that aren't from AI suggestions)
   * 3. Merge them: manual tags + AI tags (user is always in control)
   * 4. Update form's tagNames
   *
   * This ensures:
   * - AI suggestions automatically appear in main field when selected
   * - Manual tags are preserved alongside AI tags
   * - No duplicates (Set handles uniqueness)
   * - Real-time updates as user clicks tag chips
   */
  watch(
    () => Array.from(aiState.value.selectedTagNames),
    (selectedAiTags: string[]) => {
      // Tags in the form that aren't from current AI suggestions (manually typed)
      const manualTags = tagNamesRef.value.filter(
        tag => !aiState.value.suggestedTags.some(st => st.name === tag),
      )

      // Merge: keep manual tags + add selected AI tags
      tagNamesRef.value = [...manualTags, ...selectedAiTags]
    },
    { deep: true },
  )

  /**
   * Trigger AI analysis for current page
   *
   * @param url - Page URL to analyze
   */
  async function handleAnalyze(url: string): Promise<void> {
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
