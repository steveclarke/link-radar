<script lang="ts" setup>
import type { Tag } from "../../../lib/types"

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
    class="absolute top-[calc(100%-32px)] left-0 right-0 max-h-[200px] overflow-y-auto bg-white border border-gray-300 rounded-md shadow-md z-1000 mt-1"
    aria-label="Tag suggestions"
  >
    <div v-if="isLoading" class="flex items-center justify-center gap-2 p-3 text-gray-600 text-[13px]" role="status" aria-live="polite">
      <span class="inline-block w-3.5 h-3.5 border-2 border-gray-200 border-t-blue-600 rounded-full animate-spin" aria-hidden="true"></span>
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
        :class="{ 'bg-blue-50': index === selectedIndex }"
        @mousedown.prevent="emit('selectTag', tag)"
        @mouseenter="emit('updateSelectedIndex', index)"
      >
        <span class="flex-1 text-gray-800">{{ tag.name }}</span>
        <span class="inline-flex items-center justify-center min-w-[24px] h-5 px-1.5 bg-gray-200 text-gray-600 rounded-full text-[11px] font-semibold" :aria-label="`Used ${tag.usage_count} times`">
          {{ tag.usage_count }}
        </span>
      </div>

      <div
        v-if="inputValue.trim() && !hasExactMatch"
        :id="`tag-option-${suggestions.length}`"
        role="option"
        :aria-selected="selectedIndex === suggestions.length"
        class="flex items-center justify-between px-3 py-2 cursor-pointer text-sm transition-colors duration-150 italic text-blue-600 border-t border-gray-200"
        :class="{ 'bg-blue-100': selectedIndex === suggestions.length }"
        @mousedown.prevent="emit('createNew')"
        @mouseenter="emit('updateSelectedIndex', suggestions.length)"
      >
        <span class="flex-1">Create "{{ inputValue.trim() }}"</span>
      </div>

      <div
        v-if="!isLoading && suggestions.length === 0 && inputValue.trim()"
        class="p-3 text-center text-gray-500 text-[13px] italic"
        role="status"
      >
        No matching tags
      </div>
    </template>
  </div>
</template>
