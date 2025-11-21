<script lang="ts" setup>
/**
 * Suggested Tags Component
 *
 * Displays AI-suggested tags as toggleable chips with 4 visual states:
 * 1. Green + Solid: Existing tag, selected (added to main field)
 * 2. Green + Outline: Existing tag, unselected (not in main field)
 * 3. Blue + Solid: New tag, selected (added to main field, will be created)
 * 4. Blue + Outline: New tag, unselected (not in main field)
 *
 * Visual communication:
 * - Green = tag exists in user's collection
 * - Blue = new tag will be created
 * - Solid = selected (in main TagInput)
 * - Outline = not selected (not in main TagInput)
 *
 * All chips start unselected (outline style) - explicit opt-in approach.
 * User clicks to toggle selection on/off.
 */

import type { SuggestedTag } from "../../../lib/types/ai-analysis"

const props = defineProps<{
  /** Array of AI-suggested tags with exists flags */
  tags: SuggestedTag[]

  /** Set of currently selected tag names (for determining chip state) */
  selectedTagNames: Set<string>
}>()

const emit = defineEmits<{
  /** Emitted when user clicks a tag chip to toggle selection */
  toggleTag: [tagName: string]
}>()

/**
 * Check if tag is currently selected
 * @param tagName - Tag name to check
 * @returns true if tag is in selectedTagNames Set
 */
function isSelected(tagName: string): boolean {
  return props.selectedTagNames.has(tagName)
}

/**
 * Get chip CSS classes based on state
 * @param tag - Tag object with name and exists flag
 * @returns Object with CSS classes for current state
 */
function getChipClasses(tag: SuggestedTag) {
  const selected = isSelected(tag.name)

  return {
    // Base chip styles
    "inline-flex items-center px-3 py-1 rounded-full text-sm font-medium cursor-pointer transition-colors": true,

    // Existing tag, selected (green solid)
    "bg-green-600 text-white": tag.exists && selected,

    // Existing tag, unselected (green outline)
    "border-2 border-green-600 text-green-700 bg-white hover:bg-green-50": tag.exists && !selected,

    // New tag, selected (blue solid)
    "bg-blue-600 text-white": !tag.exists && selected,

    // New tag, unselected (blue outline)
    "border-2 border-blue-600 text-blue-700 bg-white hover:bg-blue-50": !tag.exists && !selected,
  }
}

function handleToggle(tagName: string) {
  emit("toggleTag", tagName)
}
</script>

<template>
  <div>
    <div class="text-xs text-slate-600 mb-2">
      Tags (click to select):
    </div>

    <div class="flex flex-wrap gap-2">
      <button
        v-for="tag in tags"
        :key="tag.name"
        type="button"
        :class="getChipClasses(tag)"
        @click="handleToggle(tag.name)"
      >
        {{ tag.name }}
      </button>
    </div>
  </div>
</template>
