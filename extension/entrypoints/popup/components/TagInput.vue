<script lang="ts" setup>
/**
 * Tag input component with autocomplete suggestions, keyboard navigation,
 * and multi-tag support. Includes real-time search with debouncing, tag
 * deduplication/normalization, and ARIA accessibility attributes.
 *
 * @component
 */
import type { Tag } from "../../../lib/types"
import { onClickOutside, useDebounceFn, useTimeoutFn } from "@vueuse/core"

import { computed, ref, watch } from "vue"
import { useTag } from "../composables/useTag"
import TagSuggestions from "./TagSuggestions.vue"

/** Array of tag names that are bound to the parent component */
const tags = defineModel<string[]>({ default: () => [] })

// Configuration constants
/** Delay in milliseconds before triggering tag search API call */
const DEBOUNCE_DELAY_MS = 300
/** Delay in milliseconds to allow mousedown events to fire before blur processing */
const BLUR_DELAY_MS = 200

const { searchTags, isSearching, searchError } = useTag()

/** Current value in the input field */
const inputValue = ref("")
/** Raw tag suggestions from the API */
const suggestions = ref<Tag[]>([])
/** Whether to show the suggestions dropdown */
const showSuggestions = ref(false)
/** Index of the currently selected suggestion (-1 means none selected) */
const selectedIndex = ref(-1)
/** Template ref to the dropdown container element for click-outside detection */
const dropdownRef = ref<HTMLElement>()

/**
 * Normalizes a string for case-insensitive comparison.
 * Trims whitespace and converts to lowercase.
 */
function normalizeForComparison(str: string): string {
  return str.trim().toLowerCase()
}

/**
 * Checks if a tag exists in an array (case-insensitive).
 */
function hasTag(tagName: string, tagArray: string[]): boolean {
  const normalized = normalizeForComparison(tagName)
  return tagArray.some(tag => normalizeForComparison(tag) === normalized)
}

/**
 * Checks if a tag exists in Tag objects array (case-insensitive).
 */
function hasTagInSuggestions(tagName: string, suggestions: Tag[]): boolean {
  const normalized = normalizeForComparison(tagName)
  return suggestions.some(tag => normalizeForComparison(tag.name) === normalized)
}

/**
 * Filters suggestions to exclude tags that have already been added.
 * Performs case-insensitive comparison.
 */
const filteredSuggestions = computed(() => {
  return suggestions.value.filter(tag => !hasTag(tag.name, tags.value))
})

/**
 * Checks if the user's input exactly matches any existing suggestion or already-added tag.
 * Used to determine whether to show the "Create new tag" option in the dropdown.
 * Returns true if input is empty (no need to create), or if an exact match exists.
 */
const hasExactMatch = computed(() => {
  const trimmedInput = inputValue.value.trim()
  if (!trimmedInput)
    return true
  return hasTag(trimmedInput, tags.value) || hasTagInSuggestions(trimmedInput, suggestions.value)
})

// Reset selection when clicking outside the dropdown
onClickOutside(dropdownRef, () => {
  selectedIndex.value = -1
})

/**
 * Normalizes and deduplicates an array of tag strings.
 * - Trims whitespace from each tag
 * - Removes empty strings
 * - Removes duplicates (case-insensitive comparison)
 * - Preserves the original casing of the first occurrence
 *
 * @param rawTags - Array of tag strings to normalize
 * @returns Normalized array with duplicates removed
 */
function normalizeTags(rawTags: string[]): string[] {
  const seen = new Set<string>()
  const normalized: string[] = []

  for (const rawTag of rawTags) {
    const tag = rawTag.trim()
    const normalizedTag = normalizeForComparison(tag)

    if (!tag || seen.has(normalizedTag))
      continue

    seen.add(normalizedTag)
    normalized.push(tag)
  }

  return normalized
}

/**
 * Adds tags from the current input value.
 * Supports comma-separated tags, normalizes them, and clears the input.
 * Does nothing if input is empty.
 */
function addTagsFromInput() {
  if (!inputValue.value)
    return

  const incomingTags = normalizeTags(inputValue.value.split(","))
  if (!incomingTags.length) {
    inputValue.value = ""
    return
  }

  tags.value = normalizeTags([...tags.value, ...incomingTags])
  inputValue.value = ""
}

/**
 * Removes a specific tag from the tags array.
 *
 * @param tagToRemove - The exact tag string to remove
 */
function removeTag(tagToRemove: string) {
  tags.value = tags.value.filter(tag => tag !== tagToRemove)
}

/**
 * Debounced search function that queries the API for tag suggestions.
 * Waits DEBOUNCE_DELAY_MS after the user stops typing before making the API call.
 */
const debouncedSearch = useDebounceFn(async (query: string) => {
  const results = await searchTags(query)
  suggestions.value = results
}, DEBOUNCE_DELAY_MS)

/**
 * Timeout function for blur event handling.
 * Automatically cleans up on component unmount to prevent memory leaks.
 */
const { start: startBlurTimeout } = useTimeoutFn(() => {
  showSuggestions.value = false
  addTagsFromInput()
}, BLUR_DELAY_MS, { immediate: false })

/**
 * Watches the input value and triggers tag search when user types.
 * Shows suggestions dropdown when input has text, hides it when empty.
 */
watch(inputValue, (newValue) => {
  const normalized = normalizeForComparison(newValue)
  if (normalized) {
    showSuggestions.value = true
    debouncedSearch(normalized)
  }
  else {
    showSuggestions.value = false
    suggestions.value = []
  }
})

/**
 * Handles focus event on the input field.
 * Resets selection but doesn't show dropdown until user types.
 */
function handleFocus() {
  selectedIndex.value = -1
}

/**
 * Handles keyboard events for tag input and suggestion navigation.
 * Supports:
 * - Backspace: Delete last tag when input is empty
 * - Enter/Comma: Add tag from input or select suggestion
 * - Arrow Up/Down: Navigate suggestions
 * - Escape: Close suggestions dropdown
 *
 * @param event - Keyboard event from the input element
 */
function handleKeyDown(event: KeyboardEvent) {
  // Handle backspace to delete last tag when input is empty
  if (event.key === "Backspace" && !inputValue.value && tags.value.length > 0) {
    event.preventDefault()
    const updatedTags = [...tags.value]
    updatedTags.pop()
    tags.value = updatedTags
    return
  }

  if (!showSuggestions.value) {
    if (event.key === "Enter" || event.key === ",") {
      event.preventDefault()
      addTagsFromInput()
    }
    return
  }

  // Handle keyboard navigation in dropdown
  if (event.key === "ArrowDown") {
    event.preventDefault()
    const maxIndex = hasExactMatch.value ? filteredSuggestions.value.length - 1 : filteredSuggestions.value.length
    selectedIndex.value = Math.min(selectedIndex.value + 1, maxIndex)
  }
  else if (event.key === "ArrowUp") {
    event.preventDefault()
    selectedIndex.value = Math.max(selectedIndex.value - 1, -1)
  }
  else if (event.key === "Escape") {
    event.preventDefault()
    showSuggestions.value = false
    selectedIndex.value = -1
  }
  else if (event.key === "Enter" || event.key === ",") {
    event.preventDefault()
    if (selectedIndex.value >= 0 && selectedIndex.value < filteredSuggestions.value.length) {
      // Add selected suggestion
      addTag(filteredSuggestions.value[selectedIndex.value].name)
    }
    else if (selectedIndex.value === filteredSuggestions.value.length && !hasExactMatch.value) {
      // Add as new tag (create new option selected)
      addTagsFromInput()
    }
    else {
      // No selection or exact match exists, add from input
      addTagsFromInput()
    }
  }
}

/**
 * Adds a single tag by name, normalizes it, and clears the input.
 * Resets the selection index after adding.
 *
 * @param tagName - The tag name to add
 */
function addTag(tagName: string) {
  const incomingTags = normalizeTags([tagName])
  if (!incomingTags.length)
    return

  tags.value = normalizeTags([...tags.value, ...incomingTags])
  inputValue.value = ""
  selectedIndex.value = -1
}

/**
 * Handles selection of a tag from the suggestions dropdown.
 *
 * @param tag - The Tag object selected from suggestions
 */
function handleSelectSuggestion(tag: Tag) {
  addTag(tag.name)
}

/**
 * Handles blur event on the input field.
 * Delays processing to allow mousedown events on suggestions to fire first,
 * then hides suggestions and adds any pending input as tags.
 */
function handleBlur() {
  startBlurTimeout()
}
</script>

<template>
  <div ref="dropdownRef" class="relative flex flex-col gap-1.5">
    <label class="text-sm font-medium text-slate-800" for="tag-input">
      Tags
    </label>
    <div class="flex flex-wrap gap-2 p-2 border border-slate-300 rounded-md bg-white" role="list" aria-label="Selected tags">
      <span
        v-for="tag in tags"
        :key="tag"
        class="inline-flex items-center gap-1 bg-brand-100 text-brand-600 rounded-full px-2 py-1 text-xs font-medium"
        role="listitem"
      >
        {{ tag }}
        <button
          class="border-none bg-transparent text-inherit cursor-pointer text-xs leading-none p-0 hover:opacity-80"
          type="button"
          :aria-label="`Remove ${tag} tag`"
          @click="removeTag(tag)"
        >
          ×
        </button>
      </span>
      <input
        id="tag-input"
        v-model="inputValue"
        class="flex-1 min-w-[120px] border-none outline-none text-sm p-0.5"
        type="text"
        role="combobox"
        :aria-expanded="showSuggestions"
        :aria-controls="showSuggestions ? 'tag-suggestions-listbox' : undefined"
        :aria-activedescendant="selectedIndex >= 0 ? `tag-option-${selectedIndex}` : undefined"
        aria-autocomplete="list"
        :aria-busy="isSearching"
        aria-label="Add tags"
        placeholder="Add tags…"
        @keydown="handleKeyDown"
        @blur="handleBlur"
        @focus="handleFocus"
      >
    </div>

    <!-- Suggestions -->
    <TagSuggestions
      :suggestions="filteredSuggestions"
      :selected-index="selectedIndex"
      :is-loading="isSearching"
      :error="searchError"
      :input-value="inputValue"
      :has-exact-match="hasExactMatch"
      :show="showSuggestions"
      @select-tag="handleSelectSuggestion"
      @create-new="addTagsFromInput"
      @update-selected-index="(idx) => selectedIndex = idx"
    />

    <p class="m-0 text-xs text-slate-600">
      Separate tags with commas or Enter
    </p>
  </div>
</template>
