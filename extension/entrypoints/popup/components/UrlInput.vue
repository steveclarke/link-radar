<script lang="ts" setup>
/**
 * URL input component for editing the link URL before saving.
 * Uses v-model for two-way binding.
 *
 * @component
 */

/**
 * v-model for the URL string
 */
const model = defineModel<string>({ default: "" })
</script>

<template>
  <div class="flex flex-col gap-1.5">
    <label for="url" class="block text-sm font-medium text-slate-800">
      URL
    </label>
    <input
      id="url"
      v-model="model"
      type="text"
      class="w-full p-2 border border-slate-300 rounded text-sm box-border break-all bg-white focus:outline-none focus:border-brand-600 focus:ring-2 focus:ring-brand-200"
      placeholder="https://example.com"
    >
  </div>
</template>
