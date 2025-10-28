<script lang="ts" setup>
import type { Tag } from "../../../lib/linkRadarClient"
import { onClickOutside, useDebounceFn } from "@vueuse/core"

import { computed, ref, watch } from "vue"
import { searchTags } from "../../../lib/linkRadarClient"

const props = defineProps<{
  modelValue: string[]
}>()

const emit = defineEmits<{
  (event: "update:modelValue", value: string[]): void
}>()

const inputValue = ref("")
const suggestions = ref<Tag[]>([])
const showSuggestions = ref(false)
const selectedIndex = ref(-1)
const isLoadingTags = ref(false)
const dropdownRef = ref<HTMLElement | null>(null)

const tags = computed(() => props.modelValue ?? [])

// Filter suggestions to exclude already-added tags
const filteredSuggestions = computed(() => {
  const tagNamesLower = tags.value.map(t => t.toLowerCase())
  return suggestions.value.filter(tag => !tagNamesLower.includes(tag.name.toLowerCase()))
})

// Computed property to check if user's input matches any suggestion or already-added tag
const hasExactMatch = computed(() => {
  if (!inputValue.value.trim())
    return true
  const normalizedInput = inputValue.value.trim().toLowerCase()
  const matchesExistingTag = tags.value.some(tag => tag.toLowerCase() === normalizedInput)
  const matchesSuggestion = filteredSuggestions.value.some(tag => tag.name.toLowerCase() === normalizedInput)
  return matchesExistingTag || matchesSuggestion
})

// Close dropdown when clicking outside
onClickOutside(dropdownRef, () => {
  showSuggestions.value = false
  selectedIndex.value = -1
})

function normalizeTags(rawTags: string[]): string[] {
  const seen = new Set<string>()
  const normalized: string[] = []

  for (const rawTag of rawTags) {
    const tag = rawTag.trim()
    if (!tag || seen.has(tag))
      continue

    seen.add(tag)
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
  try {
    const results = await searchTags(query)
    suggestions.value = results
  }
  catch (error) {
    console.error("Error searching tags:", error)
    suggestions.value = []
  }
  finally {
    isLoadingTags.value = false
  }
}, 300)

// Watch input value and trigger debounced search
watch(inputValue, (newValue) => {
  const trimmed = newValue.trim()
  if (trimmed) {
    showSuggestions.value = true
    debouncedSearch(trimmed)
  }
  else {
    showSuggestions.value = false
    suggestions.value = []
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
  // Delay to allow click events on suggestions to fire
  setTimeout(() => {
    if (!showSuggestions.value) {
      addTagsFromInput()
    }
  }, 200)
}
</script>

<template>
  <div ref="dropdownRef" class="tag-input">
    <label class="tag-label" for="tag-input">
      Tags
    </label>
    <div class="pill-container">
      <span
        v-for="tag in tags"
        :key="tag"
        class="pill"
      >
        {{ tag }}
        <button class="remove-button" type="button" @click="removeTag(tag)">
          ×
        </button>
      </span>
      <input
        id="tag-input"
        v-model="inputValue"
        class="tag-field"
        type="text"
        placeholder="Add tags…"
        @keydown="handleKeyDown"
        @blur="handleBlur"
        @focus="handleFocus"
      >
    </div>

    <!-- Suggestions Dropdown -->
    <div v-if="showSuggestions" class="suggestions-dropdown">
      <div v-if="isLoadingTags" class="loading-spinner">
        Loading...
      </div>
      <template v-else>
        <div
          v-for="(tag, index) in filteredSuggestions"
          :key="tag.id"
          class="suggestion-item"
          :class="{ selected: index === selectedIndex }"
          @click="selectSuggestion(tag)"
          @mouseenter="selectedIndex = index"
        >
          <span class="tag-name">{{ tag.name }}</span>
          <span class="usage-badge">{{ tag.usage_count }}</span>
        </div>
        <div
          v-if="inputValue.trim() && !hasExactMatch"
          class="suggestion-item create-new"
          :class="{ selected: selectedIndex === filteredSuggestions.length }"
          @click="addTagsFromInput"
          @mouseenter="selectedIndex = filteredSuggestions.length"
        >
          <span class="tag-name">Create "{{ inputValue.trim() }}"</span>
        </div>
        <div v-if="!isLoadingTags && filteredSuggestions.length === 0 && inputValue.trim()" class="no-tags">
          No matching tags
        </div>
      </template>
    </div>

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

/* Autocomplete Dropdown Styles */
.tag-input {
  position: relative;
}

.suggestions-dropdown {
  position: absolute;
  top: calc(100% - 32px);
  left: 0;
  right: 0;
  max-height: 200px;
  overflow-y: auto;
  background: white;
  border: 1px solid #ddd;
  border-radius: 6px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  z-index: 1000;
  margin-top: 4px;
}

.suggestion-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 12px;
  cursor: pointer;
  font-size: 14px;
  transition: background-color 0.15s;
}

.suggestion-item:hover,
.suggestion-item.selected {
  background-color: #f0f7ff;
}

.tag-name {
  flex: 1;
  color: #333;
}

.usage-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  height: 20px;
  padding: 0 6px;
  background: #e9ecef;
  color: #6c757d;
  border-radius: 10px;
  font-size: 11px;
  font-weight: 600;
}

.create-new {
  font-style: italic;
  color: #0d6efd;
  border-top: 1px solid #eee;
}

.create-new:hover,
.create-new.selected {
  background-color: #e7f1ff;
}

.loading-spinner {
  padding: 12px;
  text-align: center;
  color: #666;
  font-size: 13px;
}

.no-tags {
  padding: 12px;
  text-align: center;
  color: #999;
  font-size: 13px;
  font-style: italic;
}
</style>
