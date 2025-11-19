<script lang="ts" setup>
/**
 * AI Analyze Button Component
 *
 * Button with 3 states:
 * 1. Idle: "✨ Analyze with AI" (enabled, clickable)
 * 2. Analyzing: "Analyzing..." with spinner (disabled)
 * 3. Analyzed: "↻ Analyze Again" (enabled, allows regeneration)
 *
 * Emits 'analyze' event when clicked.
 * Parent component (LinkForm) handles actual analysis via useAiFormIntegration.
 *
 * @component
 */

interface Props {
  /** true when analysis is in progress */
  isAnalyzing: boolean

  /** true when suggestions have been loaded (show "Analyze Again" text) */
  hasAnalyzed: boolean

  /** Whether app is properly configured */
  isAppConfigured: boolean
}

interface Emits {
  /** Emitted when button is clicked (trigger analysis or regenerate) */
  (e: "analyze"): void
}

defineProps<Props>()
const emit = defineEmits<Emits>()

function handleAnalyzeClick() {
  emit("analyze")
}
</script>

<template>
  <button
    type="button"
    class="w-full flex items-center justify-center gap-2 px-4 py-2 text-sm font-medium rounded-md transition-all"
    :class="{
      'bg-linear-to-r from-purple-500 to-indigo-600 text-white hover:from-purple-600 hover:to-indigo-700': !isAnalyzing,
      'bg-amber-50 text-amber-700 border border-amber-200 cursor-not-allowed': isAnalyzing,
    }"
    :disabled="isAnalyzing || !isAppConfigured"
    @click="handleAnalyzeClick"
  >
    <!-- Spinner when analyzing -->
    <svg v-if="isAnalyzing" class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2" class="opacity-25" />
      <path fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" class="opacity-75" />
    </svg>

    <!-- Text based on state -->
    <span v-if="isAnalyzing">
      Analyzing...
    </span>
    <span v-else-if="hasAnalyzed">
      ↻ Analyze Again
    </span>
    <span v-else>
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
      </svg>
      Analyze with AI
    </span>
  </button>
</template>
