<script lang="ts" setup>
import { computed, ref } from "vue"

const props = defineProps<{
  modelValue: string[]
}>()

const emit = defineEmits<{
  (event: "update:modelValue", value: string[]): void
}>()

const inputValue = ref("")

const tags = computed(() => props.modelValue ?? [])

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

function handleKeyDown(event: KeyboardEvent) {
  if (event.key === "Enter" || event.key === ",") {
    event.preventDefault()
    addTagsFromInput()
  }
}

function handleBlur() {
  addTagsFromInput()
}
</script>

<template>
  <div class="tag-input">
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
      >
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
</style>
