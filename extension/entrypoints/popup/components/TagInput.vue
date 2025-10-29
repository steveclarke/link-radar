<script lang="ts" setup>
import type { Tag } from "../../../lib/linkRadarClient"
import { onClickOutside, useDebounceFn } from "@vueuse/core"

import { computed, ref, watch } from "vue"
import { searchTags } from "../../../lib/linkRadarClient"
import TagSuggestionsDropdown from "./TagSuggestionsDropdown.vue"

const tags = defineModel<string[]>({ default: () => [] })

// Configuration constants
const DEBOUNCE_DELAY_MS = 300 // Delay before triggering tag search
const BLUR_DELAY_MS = 200 // Delay to allow mousedown events to fire before blur processing

const inputValue = ref("")
const suggestions = ref<Tag[]>([])
const showSuggestions = ref(false)
const selectedIndex = ref(-1)
const isLoadingTags = ref(false)
const searchError = ref<string | null>(null)
const dropdownRef = ref<HTMLElement | null>(null)

// Filter suggestions to exclude already-added tags
const filteredSuggestions = computed(() => {
  const tagNamesLower = tags.value.map(t => t.toLowerCase())
  return suggestions.value.filter(tag => !tagNamesLower.includes(tag.name.toLowerCase()))
})

// Computed property to check if user's input matches any suggestion or already-added tag
const hasExactMatch = computed(() => {
  const trimmedInput = inputValue.value.trim()
  if (!trimmedInput)
    return true
  const normalizedInput = trimmedInput.toLowerCase()
  const matchesExistingTag = tags.value.some(tag => tag.toLowerCase() === normalizedInput)
  const matchesSuggestion = filteredSuggestions.value.some(tag => tag.name.toLowerCase() === normalizedInput)
  return matchesExistingTag || matchesSuggestion
})

// Reset selection when clicking outside
onClickOutside(dropdownRef, () => {
  selectedIndex.value = -1
})

function normalizeTags(rawTags: string[]): string[] {
  const seen = new Set<string>()
  const normalized: string[] = []

  for (const rawTag of rawTags) {
    const tag = rawTag.trim()
    const lowerTag = tag.toLowerCase()

    if (!tag || seen.has(lowerTag))
      continue

    seen.add(lowerTag)
    normalized.push(tag)
  }

  return normalized
}

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

function removeTag(tagToRemove: string) {
  tags.value = tags.value.filter(tag => tag !== tagToRemove)
}

// Debounced search function
const debouncedSearch = useDebounceFn(async (query: string) => {
  isLoadingTags.value = true
  searchError.value = null
  try {
    const results = await searchTags(query)
    suggestions.value = results
  }
  catch (error) {
    console.error("Error searching tags:", error)
    searchError.value = "Failed to load tag suggestions"
    suggestions.value = []
  }
  finally {
    isLoadingTags.value = false
  }
}, DEBOUNCE_DELAY_MS)

// Watch input value and trigger debounced search
watch(inputValue, (newValue) => {
  const trimmed = newValue.trim()
  if (trimmed) {
    showSuggestions.value = true
    searchError.value = null
    debouncedSearch(trimmed)
  }
  else {
    showSuggestions.value = false
    suggestions.value = []
    searchError.value = null
  }
})

function handleFocus() {
  selectedIndex.value = -1
  // Don't show dropdown immediately - wait for user to type
}

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

function addTag(tagName: string) {
  const incomingTags = normalizeTags([tagName])
  if (!incomingTags.length)
    return

  tags.value = normalizeTags([...tags.value, ...incomingTags])
  inputValue.value = ""
  selectedIndex.value = -1
}

function selectSuggestion(tag: Tag) {
  addTag(tag.name)
}

function handleBlur() {
  // Delay to allow mousedown events on suggestions to fire
  setTimeout(() => {
    showSuggestions.value = false
    addTagsFromInput()
  }, BLUR_DELAY_MS)
}
</script>

<template>
  <div ref="dropdownRef" class="relative flex flex-col gap-1.5">
    <label class="text-sm font-medium text-gray-800" for="tag-input">
      Tags
    </label>
    <div class="flex flex-wrap gap-2 p-2 border border-gray-300 rounded-md bg-white" role="list" aria-label="Selected tags">
      <span
        v-for="tag in tags"
        :key="tag"
        class="inline-flex items-center gap-1 bg-blue-100 text-blue-600 rounded-full px-2 py-1 text-xs font-medium"
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
        :aria-busy="isLoadingTags"
        aria-label="Add tags"
        placeholder="Add tags…"
        @keydown="handleKeyDown"
        @blur="handleBlur"
        @focus="handleFocus"
      >
    </div>

    <!-- Suggestions Dropdown -->
    <TagSuggestionsDropdown
      :suggestions="filteredSuggestions"
      :selected-index="selectedIndex"
      :is-loading="isLoadingTags"
      :error="searchError"
      :input-value="inputValue"
      :has-exact-match="hasExactMatch"
      :show="showSuggestions"
      @select-tag="selectSuggestion"
      @create-new="addTagsFromInput"
      @update-selected-index="(idx) => selectedIndex = idx"
    />

    <p class="m-0 text-xs text-gray-600">
      Separate tags with commas or Enter
    </p>
  </div>
</template>
