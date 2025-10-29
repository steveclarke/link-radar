<script lang="ts" setup>
/**
 * Textarea input component for adding notes to a link.
 * Uses v-model for two-way binding.
 *
 * @component
 */

/**
 * v-model for the notes text
 */
const model = defineModel<string>({ default: "" })
</script>

<template>
  <div class="flex flex-col gap-1.5">
    <label for="notes" class="block text-sm font-medium text-slate-800">
      Add a note (optional):
    </label>
    <textarea
      id="notes"
      v-model="model"
      class="w-full min-h-[60px] p-2 border border-slate-300 rounded text-sm resize-vertical box-border bg-white focus:outline-none focus:border-brand-600 focus:ring-2 focus:ring-brand-200"
      placeholder="Add your thoughts about this link..."
    />
  </div>
</template>
