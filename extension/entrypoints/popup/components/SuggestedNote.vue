<script lang="ts" setup>
/**
 * Suggested Note Component
 *
 * Displays AI-generated note with "[+ Add to Notes]" button.
 * Clicking button emits event to parent (LinkForm) which inserts into NotesInput.
 *
 * Note insertion is all-or-nothing: replaces entire notes field content.
 * User can then edit the inserted text freely.
 */

defineProps<{
  /** AI-generated note text (1-2 sentences) */
  note: string
}>()

const emit = defineEmits<{
  /** Emitted when user clicks add button */
  addNote: []
}>()

function handleAddNote() {
  emit("addNote")
}
</script>

<template>
  <div class="space-y-2">
    <div class="text-sm text-slate-700 leading-relaxed">
      {{ note }}
    </div>

    <button
      type="button"
      class="text-xs text-blue-600 hover:text-blue-700 font-medium"
      @click="handleAddNote"
    >
      [+ Add to Notes]
    </button>
  </div>
</template>
