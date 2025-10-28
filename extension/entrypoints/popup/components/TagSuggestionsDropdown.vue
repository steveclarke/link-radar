<script lang="ts" setup>
import type { Tag } from "../../../lib/linkRadarClient"

defineProps<{
  suggestions: Tag[]
  selectedIndex: number
  isLoading: boolean
  error: string | null
  inputValue: string
  hasExactMatch: boolean
  show: boolean
}>()

const emit = defineEmits<{
  selectTag: [tag: Tag]
  createNew: []
  updateSelectedIndex: [index: number]
}>()
</script>

<template>
  <div
    v-if="show"
    id="tag-suggestions-listbox"
    role="listbox"
    class="suggestions-dropdown"
    aria-label="Tag suggestions"
  >
    <div v-if="isLoading" class="loading-spinner" role="status" aria-live="polite">
      <span class="spinner-icon" aria-hidden="true"></span>
      <span>Loading tags...</span>
    </div>
    <div v-else-if="error" class="error-message" role="alert">
      {{ error }}
    </div>
    <template v-else>
      <div
        v-for="(tag, index) in suggestions"
        :id="`tag-option-${index}`"
        :key="tag.id"
        role="option"
        :aria-selected="index === selectedIndex"
        class="suggestion-item"
        :class="{ selected: index === selectedIndex }"
        @mousedown.prevent="emit('selectTag', tag)"
        @mouseenter="emit('updateSelectedIndex', index)"
      >
        <span class="tag-name">{{ tag.name }}</span>
        <span class="usage-badge" :aria-label="`Used ${tag.usage_count} times`">
          {{ tag.usage_count }}
        </span>
      </div>

      <div
        v-if="inputValue.trim() && !hasExactMatch"
        :id="`tag-option-${suggestions.length}`"
        role="option"
        :aria-selected="selectedIndex === suggestions.length"
        class="suggestion-item create-new"
        :class="{ selected: selectedIndex === suggestions.length }"
        @mousedown.prevent="emit('createNew')"
        @mouseenter="emit('updateSelectedIndex', suggestions.length)"
      >
        <span class="tag-name">Create "{{ inputValue.trim() }}"</span>
      </div>

      <div
        v-if="!isLoading && suggestions.length === 0 && inputValue.trim()"
        class="no-tags"
        role="status"
      >
        No matching tags
      </div>
    </template>
  </div>
</template>

<style scoped>
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
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px;
  color: #666;
  font-size: 13px;
}

.spinner-icon {
  display: inline-block;
  width: 14px;
  height: 14px;
  border: 2px solid #e9ecef;
  border-top-color: #0d6efd;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.error-message {
  padding: 12px;
  text-align: center;
  color: #dc3545;
  font-size: 13px;
  background-color: #f8d7da;
  border-radius: 4px;
  margin: 4px;
}

.no-tags {
  padding: 12px;
  text-align: center;
  color: #999;
  font-size: 13px;
  font-style: italic;
}
</style>
