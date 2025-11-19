<script lang="ts" setup>
/**
 * AI Suggestions Container Component
 *
 * Displays AI analysis results in a dedicated section:
 * - Section header with robot emoji
 * - SuggestedNote component (note + add button)
 * - SuggestedTags component (toggleable chips)
 * - Privacy notice (content sent to OpenAI)
 *
 * Only shown after successful analysis (parent controls visibility).
 *
 * @component
 */
import type { SuggestedTag } from "../../../lib/types/ai-analysis"
import SuggestedNote from "./SuggestedNote.vue"
import SuggestedTags from "./SuggestedTags.vue"

interface Props {
  /** AI-generated note text (1-2 sentences) */
  suggestedNote: string | null

  /** Array of AI-suggested tags with exists flags */
  suggestedTags: SuggestedTag[]

  /** Set of currently selected tag names (for determining chip state) */
  selectedTagNames: Set<string>
}

interface Emits {
  /** Emitted when user clicks a tag chip to toggle selection */
  (e: "toggleTag", tagName: string): void

  /** Emitted when user clicks "[+ Add to Notes]" button */
  (e: "addNote", note: string): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

/**
 * Determine if tag is currently selected based on parent state
 * This is a simple check - actual state is managed by parent via watch
 */
/**
 * Handle adding note from child component
 */
function handleAddNote() {
  if (props.suggestedNote) {
    emit("addNote", props.suggestedNote)
  }
}

/**
 * Handle tag toggle from child component
 */
function handleToggleTag(tagName: string) {
  emit("toggleTag", tagName)
}
</script>

<template>
  <!-- Suggestions section (non-modal, inline) -->
  <div class="bg-purple-50 border border-purple-200 rounded-md p-4 space-y-4">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <h3 class="text-sm font-semibold text-slate-700">
        🤖 AI Suggestions
      </h3>
      <span class="text-xs text-slate-500">
        ⚠️ Content sent to OpenAI
      </span>
    </div>

    <!-- Suggested Note -->
    <SuggestedNote
      v-if="suggestedNote"
      :note="suggestedNote"
      @add-note="handleAddNote"
    />

    <!-- Suggested Tags -->
    <SuggestedTags
      v-if="suggestedTags.length > 0"
      :tags="suggestedTags"
      :selected-tag-names="selectedTagNames"
      @toggle-tag="handleToggleTag"
    />
  </div>
</template>
