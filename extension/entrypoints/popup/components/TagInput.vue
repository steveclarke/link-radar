<script lang="ts" setup>
import type { Tag } from "../../../lib/linkRadarClient"
import { onClickOutside, useDebounceFn } from "@vueuse/core"

import { computed, ref, watch } from "vue"
import { searchTags } from "../../../lib/linkRadarClient"
import TagSuggestionsDropdown from "./TagSuggestionsDropdown.vue"

const props = defineProps<{
  modelValue: string[]
}>()

const emit = defineEmits<{
  (event: "update:modelValue", value: string[]): void
}>()

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

const tags = computed(() => props.modelValue ?? [])

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

function emitUpdatedTags(updatedTags: string[]) {
  emit("update:modelValue", updatedTags)
}

function addTagsFromInput() {
  if (!inputValue.value)
    return

  const incomingTags = normalizeTags(inputValue.value.split(","))
  if (!incomingTags.length) {
    inputValue.value = ""
    return
  }

  const combined = normalizeTags([...tags.value, ...incomingTags])
  emitUpdatedTags(combined)
  inputValue.value = ""
}

function removeTag(tagToRemove: string) {
  emitUpdatedTags(tags.value.filter(tag => tag !== tagToRemove))
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
    emitUpdatedTags(updatedTags)
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

  const combined = normalizeTags([...tags.value, ...incomingTags])
  emitUpdatedTags(combined)
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
  <div ref="dropdownRef" class="tag-input">
    <label class="tag-label" for="tag-input">
      Tags
    </label>
    <div class="pill-container" role="list" aria-label="Selected tags">
      <span
        v-for="tag in tags"
        :key="tag"
        class="pill"
        role="listitem"
      >
        {{ tag }}
        <button
          class="remove-button"
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
        class="tag-field"
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

    <p class="helper-text">
      Separate tags with commas or Enter
    </p>
  </div>
</template>

<style scoped>
.tag-input {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.tag-label {
  font-size: 14px;
  font-weight: 500;
  color: #333;
}

.pill-container {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: #fff;
}

.pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: #e7f1ff;
  color: #0d6efd;
  border-radius: 999px;
  padding: 4px 8px;
  font-size: 12px;
  font-weight: 500;
}

.remove-button {
  border: none;
  background: transparent;
  color: inherit;
  cursor: pointer;
  font-size: 12px;
  line-height: 1;
  padding: 0;
}

.remove-button:hover {
  opacity: 0.8;
}

.tag-field {
  flex: 1;
  min-width: 120px;
  border: none;
  outline: none;
  font-size: 14px;
  font-family: inherit;
  padding: 2px;
}

.helper-text {
  margin: 0;
  font-size: 12px;
  color: #666;
}

/* Position relative needed for dropdown positioning */
.tag-input {
  position: relative;
}
</style>
