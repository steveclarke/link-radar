<script lang="ts" setup>
/**
 * Component for tag suggestions with keyboard navigation support.
 * Shows existing tags with usage counts and provides option to create new tags.
 *
 * @component
 */
import type { Tag } from "../../../lib/types"

/**
 * Component props
 */
defineProps<{
  /** Array of tag suggestions to display */
  suggestions: Tag[]
  /** Index of the currently selected/highlighted suggestion (for keyboard navigation) */
  selectedIndex: number
  /** Whether tags are currently being loaded from the API */
  isLoading: boolean
  /** Error message to display if tag loading fails */
  error: string | null
  /** Current value of the tag input field (used for "Create new" option) */
  inputValue: string
  /** Whether an exact match exists in the suggestions list */
  hasExactMatch: boolean
  /** Whether to show the suggestions (controls visibility) */
  show: boolean
}>()

/**
 * Component events
 */
const emit = defineEmits<{
  /** Emitted when a user selects an existing tag from the suggestions */
  selectTag: [tag: Tag]
  /** Emitted when a user chooses to create a new tag with the current input value */
  createNew: []
  /** Emitted when the selected index changes (e.g., on mouse hover) */
  updateSelectedIndex: [index: number]
}>()
</script>

<template>
  <div
    v-if="show"
    id="tag-suggestions-listbox"
    role="listbox"
    class="absolute top-[calc(100%-32px)] left-0 right-0 max-h-[200px] overflow-y-auto bg-white border border-slate-300 rounded-md shadow-md z-1000 mt-1"
    aria-label="Tag suggestions"
  >
    <div v-if="isLoading" class="flex items-center justify-center gap-2 p-3 text-slate-600 text-[13px]" role="status" aria-live="polite">
      <span class="inline-block w-3.5 h-3.5 border-2 border-slate-200 border-t-brand-600 rounded-full animate-spin" aria-hidden="true"></span>
      <span>Loading tags...</span>
    </div>
    <div v-else-if="error" class="p-3 text-center text-red-600 text-[13px] bg-red-50 rounded m-1" role="alert">
      {{ error }}
    </div>
    <template v-else>
      <div
        v-for="(tag, index) in suggestions"
        :id="`tag-option-${index}`"
        :key="tag.id"
        role="option"
        :aria-selected="index === selectedIndex"
        class="flex items-center justify-between px-3 py-2 cursor-pointer text-sm transition-colors duration-150"
        :class="{ 'bg-brand-50': index === selectedIndex }"
        @mousedown.prevent="emit('selectTag', tag)"
        @mouseenter="emit('updateSelectedIndex', index)"
      >
        <span class="flex-1 text-slate-800">{{ tag.name }}</span>
        <span class="inline-flex items-center justify-center min-w-[24px] h-5 px-1.5 bg-slate-200 text-slate-600 rounded-full text-[11px] font-semibold" :aria-label="`Used ${tag.usage_count} times`">
          {{ tag.usage_count }}
        </span>
      </div>

      <div
        v-if="inputValue.trim() && !hasExactMatch"
        :id="`tag-option-${suggestions.length}`"
        role="option"
        :aria-selected="selectedIndex === suggestions.length"
        class="flex items-center justify-between px-3 py-2 cursor-pointer text-sm transition-colors duration-150 italic text-brand-600 border-t border-slate-200"
        :class="{ 'bg-brand-100': selectedIndex === suggestions.length }"
        @mousedown.prevent="emit('createNew')"
        @mouseenter="emit('updateSelectedIndex', suggestions.length)"
      >
        <span class="flex-1">Create "{{ inputValue.trim() }}"</span>
      </div>

      <div
        v-if="!isLoading && suggestions.length === 0 && inputValue.trim()"
        class="p-3 text-center text-slate-500 text-[13px] italic"
        role="status"
      >
        No matching tags
      </div>
    </template>
  </div>
</template>
