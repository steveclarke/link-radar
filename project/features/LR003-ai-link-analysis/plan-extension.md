# LR003 - AI-Powered Link Analysis: Extension Implementation Plan

## Overview

This plan implements the browser extension UI for AI-powered link analysis. Users click "Analyze with AI" button, extension extracts page content, calls backend API, and displays suggestions in a non-destructive UI section.

**Key Components:**
- Content extraction using @mozilla/readability (DOM manipulation)
- Privacy protection with ip-address npm package (client-side filtering)
- Composable for analysis state management (cancellable async operations)
- 5 new Vue components (button, suggestions container, note display, tag chips)
- Real-time tag syncing (selected chips → main TagInput field)

**Sequencing Logic:**
1. Prerequisites (install packages, verify types)
2. Foundation layer (types, API client, utilities)
3. Composable (state management and business logic)
4. UI components (button → suggestions → integration)
5. Manual testing (verify with real pages)

**References:**
- Technical Spec: [spec.md](spec.md) sections 5 (Extension), 7.1 (Privacy), 7.2 (Error Handling)
- Requirements: [requirements.md](requirements.md) sections 4.3 (Content Extraction), 5 (UX)
- Vision: [vision.md](vision.md) for user flow

## Table of Contents

1. [Phase 1: Prerequisites & Dependencies](#phase-1-prerequisites--dependencies)
2. [Phase 2: Type Definitions & API Client](#phase-2-type-definitions--api-client)
3. [Phase 3: Privacy & Content Extraction](#phase-3-privacy--content-extraction)
4. [Phase 4: Composable State Management](#phase-4-composable-state-management)
5. [Phase 5: UI Components](#phase-5-ui-components)
6. [Phase 6: Integration](#phase-6-integration)
7. [Phase 7: Manual Testing](#phase-7-manual-testing)

---

## Phase 1: Prerequisites & Dependencies

**Purpose:** Install required npm packages and verify TypeScript definitions are available.

**Justification:** Ensures @mozilla/readability and ip-address libraries are available before implementation. (spec.md#6.2)

### Tasks

- [ ] Install @mozilla/readability: `cd extension && pnpm add @mozilla/readability`
- [ ] Install ip-address: `cd extension && pnpm add ip-address`
- [ ] Verify package.json updated with both dependencies
- [ ] Verify TypeScript definitions are available (both packages include types)
- [ ] Run `pnpm install` to ensure lockfile is updated
- [ ] Test imports work: Create temporary test file that imports both packages, then delete it

**Package Versions:** Use latest stable versions (package manager will select appropriate versions).

**Validation:** Both packages should import without TypeScript errors:
```typescript
import { Readability } from '@mozilla/readability'
import { Address4, Address6 } from 'ip-address'
```

---

## Phase 2: Type Definitions & API Client

**Purpose:** Define TypeScript interfaces for AI analysis and add API client function.

**Justification:** Type-safe contracts ensure consistency between extension and backend API. (spec.md#5.1, spec.md#5.2)

### File: `extension/lib/types/ai-analysis.ts`

This file is **novel** - defines new types for AI analysis feature. Full implementation detail provided:

```typescript
/**
 * AI Analysis Type Definitions
 * 
 * These types define the contracts for AI-powered link analysis:
 * - Request payload sent to backend
 * - Response structure from backend
 * - Client-side state management
 * - Content extraction results
 * 
 * All types match backend API contracts defined in spec.md#3.2 and spec.md#3.3
 */

/**
 * Analysis request payload sent to backend
 * 
 * Matches backend POST /api/v1/links/analyze request contract (spec.md#3.2)
 */
export interface AnalyzeRequest {
  /** Page URL (HTTP/HTTPS only) */
  url: string
  
  /** Main article text extracted via Readability (max 50,000 chars) */
  content: string
  
  /** Page title (from og:title, <title>, or h1) */
  title: string
  
  /** Meta description (from og:description or meta description tag) */
  description: string
  
  /** Author information (from meta author or og:article:author) - optional */
  author?: string
}

/**
 * Individual tag suggestion from AI
 * 
 * Each tag includes:
 * - name: Tag text (Title Case preferred, e.g., "JavaScript")
 * - exists: Whether tag exists in user's collection (for visual styling)
 */
export interface SuggestedTag {
  /** Tag name in Title Case or lowercase */
  name: string
  
  /** true if tag exists in user's Tag collection, false if new */
  exists: boolean
}

/**
 * Analysis response from backend
 * 
 * Matches backend response contract (spec.md#3.3)
 * Wrapped in `data` object per existing API conventions
 */
export interface AnalyzeResponse {
  data: {
    /** AI-generated note (1-2 sentences explaining value) */
    suggested_note: string
    
    /** AI-generated tag suggestions (typically 3-7 tags) */
    suggested_tags: SuggestedTag[]
  }
}

/**
 * Extracted page content from Readability
 * 
 * Intermediate structure used between content extraction and API call
 * Contains all metadata needed for analysis
 */
export interface ExtractedContent {
  /** Main article text from Readability.parse() */
  content: string
  
  /** Page title (og:title > <title> > h1) */
  title: string
  
  /** Meta description (og:description > meta description) */
  description: string
  
  /** Author info from meta tags (optional) */
  author?: string
  
  /** Full page URL for context */
  url: string
}

/**
 * Analysis state for UI management
 * 
 * Tracks the complete lifecycle of an analysis request:
 * - Loading state (isAnalyzing)
 * - Error state (error)
 * - Success state (suggestions)
 * - User selections (selectedTagNames)
 * 
 * Used by useAiAnalysis composable and consumed by UI components
 */
export interface AnalysisState {
  /** true when analysis API call is in progress */
  isAnalyzing: boolean
  
  /** Error message if analysis failed, null if no error */
  error: string | null
  
  /** AI-suggested note text, null if no suggestion yet */
  suggestedNote: string | null
  
  /** Array of AI-suggested tags with existence indicators */
  suggestedTags: SuggestedTag[]
  
  /** Set of tag names user has selected (for O(1) toggle checks) */
  selectedTagNames: Set<string>
}
```

### File: `extension/lib/types/index.ts`

Add export for new types (follows existing pattern):

```typescript
export * from "./dataExport"
export * from "./link"
export * from "./notification"
export * from "./tab"
export * from "./tag"
export * from "./ai-analysis"  // NEW: Export AI analysis types
```

### File: `extension/lib/apiClient.ts`

Add analyzeLink function (follows existing authenticatedFetch pattern):

```typescript
/**
 * Analyze page content and get AI suggestions for tags and notes
 * 
 * Calls POST /api/v1/links/analyze with extracted page content.
 * Returns structured suggestions (note + tags with existence indicators).
 * 
 * @param request - Extracted content from current page
 * @returns Analysis response with suggested_note and suggested_tags
 * @throws Error if API request fails (network error, timeout, validation error)
 * 
 * @example
 *   const response = await analyzeLink({
 *     url: "https://example.com/article",
 *     content: "Article text...",
 *     title: "Article Title",
 *     description: "Description",
 *     author: "Author"
 *   })
 *   console.log(response.data.suggested_note)
 *   console.log(response.data.suggested_tags)
 */
export async function analyzeLink(request: AnalyzeRequest): Promise<AnalyzeResponse> {
  const payload = {
    url: request.url,
    content: request.content,
    title: request.title,
    description: request.description,
    author: request.author,
  }

  return authenticatedFetch("/links/analyze", {
    method: "POST",
    body: JSON.stringify(payload),
  })
}
```

### Tasks

- [ ] Create `extension/lib/types/ai-analysis.ts` with all type definitions above
- [ ] Add JSDoc comments for all interfaces and properties (included above)
- [ ] Add `export * from "./ai-analysis"` to `extension/lib/types/index.ts`
- [ ] Import AnalyzeRequest and AnalyzeResponse types in `apiClient.ts`
- [ ] Add `analyzeLink()` function to `apiClient.ts` after existing functions
- [ ] Verify TypeScript compilation: `cd extension && pnpm run build`
- [ ] Verify types are exported and accessible from `lib/types/index.ts`

**Implementation Notes:**
- All types include JSDoc comments for IDE autocomplete
- AnalysisState uses Set<string> for O(1) tag selection lookups
- Type contracts match backend API exactly (spec.md#3.2, spec.md#3.3)

---

## Phase 3: Privacy & Content Extraction

**Purpose:** Implement client-side privacy protection and content extraction utilities.

**Justification:** Defense-in-depth privacy (extension + backend validation) and leverages browser DOM access for content extraction. (spec.md#5.3, spec.md#7.1)

### File: `extension/lib/privacy.ts`

This file is **novel** - first use of ip-address library for privacy protection. Full implementation detail provided:

```typescript
/**
 * Privacy Protection Utilities
 * 
 * Client-side filtering to prevent analysis of sensitive URLs:
 * - localhost addresses (localhost, 127.0.0.1, ::1)
 * - Private IPv4 ranges (10.x, 172.16.x, 192.168.x)
 * - Private IPv6 ranges (fc00::/7, fe80::/10)
 * 
 * This is defense-in-depth: extension checks first (UX), backend validates second (security).
 * Provides immediate user feedback and prevents sensitive content from leaving browser.
 * 
 * Uses ip-address npm package for reliable IPv4/IPv6 validation.
 */

import { Address4, Address6 } from 'ip-address'

/**
 * Check if URL is safe to analyze (not localhost or private IP)
 * 
 * Validation checks:
 * 1. Hostname is not localhost (string match)
 * 2. Hostname is not 127.0.0.1 or ::1 (loopback addresses)
 * 3. IPv4 address is not in private ranges (uses Address4.isValid() and isPublic())
 * 4. IPv6 address is not in private ranges (uses Address6.isValid() and isPublic())
 * 
 * @param url - Full URL to validate
 * @returns true if safe to analyze, false if blocked (localhost/private)
 * 
 * @example Safe URLs
 *   isSafeToAnalyze("https://example.com") // => true
 *   isSafeToAnalyze("https://8.8.8.8/page") // => true (public IP)
 * 
 * @example Blocked URLs
 *   isSafeToAnalyze("http://localhost/admin") // => false
 *   isSafeToAnalyze("http://127.0.0.1/") // => false
 *   isSafeToAnalyze("http://192.168.1.1/") // => false (private IP)
 *   isSafeToAnalyze("http://10.0.0.1/") // => false (private IP)
 */
export function isSafeToAnalyze(url: string): boolean {
  try {
    const urlObj = new URL(url)
    const hostname = urlObj.hostname
    
    // Check for localhost string match
    if (hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1') {
      return false
    }
    
    // Try parsing as IPv4
    try {
      const ipv4 = new Address4(hostname)
      if (ipv4.isValid()) {
        // isPublic() returns true for public IPs, false for private ranges
        return ipv4.isPublic()
      }
    } catch {
      // Not IPv4, continue to IPv6 check
    }
    
    // Try parsing as IPv6
    try {
      const ipv6 = new Address6(hostname)
      if (ipv6.isValid()) {
        // isPublic() returns true for public IPs, false for private ranges
        return ipv6.isPublic()
      }
    } catch {
      // Not IPv6, continue
    }
    
    // Hostname is not an IP address (likely a domain name)
    // Allow it - backend will do final validation via DNS resolution
    return true
  } catch {
    // URL parsing failed - allow it and let backend handle validation
    // This prevents client-side parsing issues from blocking legitimate URLs
    return true
  }
}
```

### File: `extension/lib/contentExtractor.ts`

This file is **novel** - first use of @mozilla/readability library. Full implementation detail provided:

```typescript
/**
 * Content Extraction Utilities
 * 
 * Extracts page content and metadata using @mozilla/readability.
 * Readability is Mozilla's article extraction library - parses page DOM
 * and returns clean article text, removing ads, sidebars, and navigation.
 * 
 * Extraction strategy:
 * - Clone DOM before passing to Readability (it modifies the document)
 * - Use fallback chains for title and description
 * - Extract author from meta tags when available
 * - Truncate content to 50,000 characters (backend limit per spec.md#3.2)
 * 
 * Handles edge cases:
 * - Pages with no readable content (returns empty string)
 * - Missing metadata (uses sensible defaults)
 * - Multiple meta tag formats (og: tags, standard meta tags)
 */

import { Readability } from '@mozilla/readability'

/**
 * Result of content extraction
 * 
 * Contains all data needed for AI analysis:
 * - Cleaned article text
 * - Page title (with fallback chain)
 * - Meta description (optional)
 * - Author info (optional)
 */
export interface ExtractionResult {
  /** Main article text from Readability (truncated to 50K chars) */
  content: string
  
  /** Page title (og:title > <title> > h1 > "Untitled") */
  title: string
  
  /** Meta description (og:description > meta description > empty string) */
  description: string
  
  /** Author from meta tags (optional) */
  author?: string
}

/**
 * Maximum content length before truncation (matches backend limit)
 * Backend validates at 50,000 chars (spec.md#3.2)
 * Extension truncates before sending for network efficiency
 */
const MAX_CONTENT_LENGTH = 50_000

/**
 * Extract page content using Readability
 * 
 * Process:
 * 1. Clone document (Readability modifies DOM)
 * 2. Parse with Readability to extract article text
 * 3. Extract metadata from DOM (title, description, author)
 * 4. Truncate content to MAX_CONTENT_LENGTH
 * 5. Return structured result
 * 
 * @returns Extraction result with content and metadata
 * 
 * @example Basic usage
 *   const extracted = extractPageContent()
 *   console.log(extracted.title)
 *   console.log(extracted.content.length)
 * 
 * @example Handling extraction failures
 *   const extracted = extractPageContent()
 *   if (extracted.content === '') {
 *     console.log('No readable content found')
 *   }
 */
export function extractPageContent(): ExtractionResult {
  // Clone document for Readability (it modifies the DOM)
  const documentClone = document.cloneNode(true) as Document
  
  // Extract main article content
  const reader = new Readability(documentClone)
  const article = reader.parse()
  
  // Extract metadata from original document
  const metadata = extractMetadata()
  
  // Get article text (or empty string if extraction failed)
  let content = article?.textContent || ''
  
  // Truncate content to backend limit (spec.md#3.2)
  if (content.length > MAX_CONTENT_LENGTH) {
    content = content.substring(0, MAX_CONTENT_LENGTH)
  }
  
  return {
    content,
    title: metadata.title,
    description: metadata.description,
    author: metadata.author,
  }
}

/**
 * Extract metadata from page using meta tags
 * 
 * Fallback chains:
 * - Title: og:title > <title> > first <h1> > "Untitled"
 * - Description: og:description > meta description > ""
 * - Author: meta author > og:article:author > undefined
 * 
 * @returns Extracted metadata with fallbacks applied
 */
function extractMetadata() {
  // Title fallback chain
  const ogTitle = document.querySelector('meta[property="og:title"]')
    ?.getAttribute('content')
  const titleTag = document.title
  const firstH1 = document.querySelector('h1')?.textContent
  const title = (ogTitle || titleTag || firstH1 || 'Untitled').trim()
  
  // Description fallback chain
  const ogDescription = document.querySelector('meta[property="og:description"]')
    ?.getAttribute('content')
  const metaDescription = document.querySelector('meta[name="description"]')
    ?.getAttribute('content')
  const description = (ogDescription || metaDescription || '').trim()
  
  // Author (optional, no fallback)
  const metaAuthor = document.querySelector('meta[name="author"]')
    ?.getAttribute('content')
  const ogAuthor = document.querySelector('meta[property="og:article:author"]')
    ?.getAttribute('content')
  const author = (metaAuthor || ogAuthor)?.trim()
  
  return { title, description, author }
}
```

### Tasks

- [ ] Create `extension/lib/privacy.ts` with `isSafeToAnalyze()` function
- [ ] Create `extension/lib/contentExtractor.ts` with `extractPageContent()` function
- [ ] Import Address4 and Address6 from 'ip-address' package
- [ ] Import Readability from '@mozilla/readability' package
- [ ] Verify MAX_CONTENT_LENGTH constant matches spec (50,000 per spec.md#3.2, line 780)
- [ ] Add JSDoc comments for all functions (included above)
- [ ] Test privacy checks manually with test URLs (localhost, 192.168.1.1, public domains)
- [ ] Test content extraction on various pages (articles, blogs, documentation)
- [ ] Verify truncation works correctly (test with very long pages)
- [ ] Confirm TypeScript compilation passes

**Implementation Notes:**
- **Privacy**: Client-side check provides immediate feedback, backend still validates (defense-in-depth)
- **Content Truncation**: Extension truncates at 50K (per spec.md line 780), backend validates as safety check (per spec.md line 781)
- **DOM Cloning**: Required because Readability modifies the document
- **Fallback Chains**: Ensure we always have title even if metadata is poor

---

## Phase 4: Composable State Management

**Purpose:** Create composable for managing AI analysis state and business logic.

**Justification:** Centralizes analysis lifecycle, error handling, and tag selection state. Follows existing composable pattern from useLink, useNotification. (spec.md#5.5)

### File: `extension/lib/composables/useAiAnalysis.ts`

This file is **novel** - manages complex async state with cancellation and real-time tag syncing. Full implementation detail provided:

```typescript
/**
 * AI Analysis Composable
 * 
 * Manages the complete lifecycle of AI analysis:
 * - Triggering analysis (extract content → call API → handle response)
 * - Loading and error states
 * - Tag selection state (Set for O(1) lookups)
 * - Suggestions display
 * - Reset on tab change
 * 
 * Used by AiAnalyzeButton and AiSuggestions components.
 * Provides reactive state and actions for the AI analysis feature.
 * 
 * Pattern: Follows useLink and useNotification composable patterns in codebase
 */

import { ref } from 'vue'
import type { AnalysisState, SuggestedTag } from '../types/ai-analysis'
import { analyzeLink } from '../apiClient'
import { extractPageContent } from '../contentExtractor'
import { isSafeToAnalyze } from '../privacy'

/**
 * Composable for AI analysis state and operations
 * 
 * Provides:
 * - state: Reactive analysis state (loading, error, suggestions, selections)
 * - analyze(): Trigger analysis for current page
 * - toggleTag(): Toggle tag selection on/off
 * - getSelectedTags(): Get array of selected tag names
 * - reset(): Clear all state (call on tab change)
 * 
 * @returns Analysis state and operations
 * 
 * @example Basic usage in component
 *   const { state, analyze, toggleTag, getSelectedTags } = useAiAnalysis()
 *   
 *   // Trigger analysis
 *   await analyze(currentUrl)
 *   
 *   // Toggle tag selection
 *   toggleTag('JavaScript')
 *   
 *   // Get selected tags for main input
 *   const selected = getSelectedTags() // => ['JavaScript', 'TypeScript']
 */
export function useAiAnalysis() {
  /**
   * Reactive analysis state
   * 
   * Tracks complete analysis lifecycle:
   * - isAnalyzing: true during API call
   * - error: Error message if analysis failed
   * - suggestedNote: AI-generated note text
   * - suggestedTags: Array of tag suggestions with exists flags
   * - selectedTagNames: Set of tag names user has toggled on
   */
  const state = ref<AnalysisState>({
    isAnalyzing: false,
    error: null,
    suggestedNote: null,
    suggestedTags: [],
    selectedTagNames: new Set(),
  })
  
  /**
   * Trigger analysis for current page
   * 
   * Process:
   * 1. Validate URL is safe (not localhost/private IP)
   * 2. Extract content using Readability
   * 3. Call backend API with extracted content
   * 4. Update state with suggestions or error
   * 5. Clear previous selections (new analysis = fresh start)
   * 
   * Error handling:
   * - Privacy violations: Friendly message about localhost/private URLs
   * - API errors: Generic "failed" message (user can retry)
   * - Network errors: Generic error message
   * - All errors stored in state.error for display
   * 
   * @param url - Page URL to analyze
   * 
   * @example
   *   try {
   *     await analyze('https://example.com')
   *     if (state.value.suggestedTags.length > 0) {
   *       console.log('Got suggestions!')
   *     }
   *   } catch (error) {
   *     console.error('Analysis failed:', state.value.error)
   *   }
   */
  async function analyze(url: string): Promise<void> {
    // Privacy check (client-side, immediate feedback)
    if (!isSafeToAnalyze(url)) {
      state.value.error = 'Cannot analyze localhost or private URLs'
      return
    }
    
    // Extract page content
    let extracted
    try {
      extracted = extractPageContent()
    } catch (error) {
      state.value.error = 'Failed to extract page content'
      return
    }
    
    // Set loading state
    state.value.isAnalyzing = true
    state.value.error = null
    
    try {
      // Call backend API
      const response = await analyzeLink({
        url,
        content: extracted.content,
        title: extracted.title,
        description: extracted.description,
        author: extracted.author,
      })
      
      // Update state with suggestions
      state.value.suggestedNote = response.data.suggested_note
      state.value.suggestedTags = response.data.suggested_tags
      
      // Clear previous selections (new analysis = fresh start)
      state.value.selectedTagNames.clear()
    } catch (error) {
      // Handle API/network errors
      if (error instanceof Error) {
        // Extract user-friendly message from error
        if (error.message.includes('timeout') || error.message.includes('timed out')) {
          state.value.error = 'Analysis timed out. Try again?'
        } else if (error.message.includes('localhost') || error.message.includes('private')) {
          state.value.error = 'Cannot analyze localhost or private URLs'
        } else {
          state.value.error = 'Analysis failed. Please try again.'
        }
      } else {
        state.value.error = 'Analysis failed. Please try again.'
      }
    } finally {
      state.value.isAnalyzing = false
    }
  }
  
  /**
   * Toggle tag selection on/off
   * 
   * If tag is selected: deselect it (remove from Set)
   * If tag is not selected: select it (add to Set)
   * 
   * Set provides O(1) lookups for toggle check and selection state.
   * Parent component (LinkForm) watches selectedTagNames to update main TagInput.
   * 
   * @param tagName - Name of tag to toggle
   * 
   * @example
   *   toggleTag('JavaScript') // Selects 'JavaScript'
   *   toggleTag('JavaScript') // Deselects 'JavaScript'
   */
  function toggleTag(tagName: string): void {
    if (state.value.selectedTagNames.has(tagName)) {
      state.value.selectedTagNames.delete(tagName)
    } else {
      state.value.selectedTagNames.add(tagName)
    }
    
    // Trigger Vue reactivity (Set mutations don't auto-trigger)
    state.value.selectedTagNames = new Set(state.value.selectedTagNames)
  }
  
  /**
   * Get currently selected tag names as array
   * 
   * Converts Set to Array for easy consumption by parent components.
   * Used to populate main TagInput field with selected suggestions.
   * 
   * @returns Array of selected tag names
   * 
   * @example
   *   const selected = getSelectedTags()
   *   // => ['JavaScript', 'TypeScript', 'Web Development']
   */
  function getSelectedTags(): string[] {
    return Array.from(state.value.selectedTagNames)
  }
  
  /**
   * Reset analysis state
   * 
   * Clears all state back to initial values:
   * - No loading, no error
   * - No suggestions
   * - No selections
   * 
   * Call this when:
   * - User navigates to different tab
   * - User closes popup
   * - Starting fresh analysis session
   * 
   * @example
   *   // In LinkForm, watch for tab changes
   *   watch(() => props.currentTabInfo, () => {
   *     reset() // Clear AI state for new tab
   *   })
   */
  function reset(): void {
    state.value = {
      isAnalyzing: false,
      error: null,
      suggestedNote: null,
      suggestedTags: [],
      selectedTagNames: new Set(),
    }
  }
  
  return {
    state,
    analyze,
    toggleTag,
    getSelectedTags,
    reset,
  }
}
```

### Tasks

- [ ] Create `extension/lib/composables/useAiAnalysis.ts` with full implementation above
- [ ] Import all required types from '../types/ai-analysis'
- [ ] Import analyzeLink from '../apiClient'
- [ ] Import extractPageContent from '../contentExtractor'
- [ ] Import isSafeToAnalyze from '../privacy'
- [ ] Use Vue's ref for reactive state (import from 'vue')
- [ ] Ensure Set mutations trigger Vue reactivity (create new Set on mutation)
- [ ] Add JSDoc comments for all functions (included above)
- [ ] Verify TypeScript compilation passes
- [ ] Test composable logic manually (mock API calls to test state transitions)

**Implementation Notes:**
- **Set for selections**: O(1) toggle checks, better than array for this use case
- **Vue reactivity**: Set mutations need explicit new Set() to trigger updates
- **Error handling**: Friendly messages for common errors, generic message for unexpected errors
- **State reset**: Important for tab changes - don't show stale suggestions

---

## Phase 5: UI Components

**Purpose:** Create Vue components for AI analysis UI (button, suggestions display, note, tag chips).

**Justification:** Implements the complete user interaction flow - trigger analysis, review suggestions, select tags, add note. (spec.md#5.4, requirements.md#5)

### Component Architecture

```
AiAnalyzeButton.vue    - Trigger button with 3 states (idle, analyzing, analyzed)
AiSuggestions.vue      - Container for suggestions (only shown after success)
├─ SuggestedNote.vue   - Note display with "[+ Add to Notes]" button
└─ SuggestedTags.vue   - Tag chips with 4 visual states (exists × selected)
```

### File: `extension/entrypoints/popup/components/AiAnalyzeButton.vue`

This component is **novel** - implements button state machine with loading/cancellation. Full implementation detail provided:

```vue
<script lang="ts" setup>
/**
 * AI Analyze Button Component
 * 
 * Button with 3 states:
 * 1. Idle: "✨ Analyze with AI" (blue, clickable)
 * 2. Analyzing: "Analyzing..." with spinner (clickable to cancel - future feature)
 * 3. Analyzed: "↻ Analyze Again" (allows regeneration)
 * 
 * Emits 'analyze' event when clicked.
 * Parent component (LinkForm) handles actual analysis via useAiAnalysis composable.
 */

const props = defineProps<{
  /** true when analysis is in progress */
  isAnalyzing: boolean
  
  /** true when suggestions have been loaded (show "Analyze Again" text) */
  hasAnalyzed: boolean
}>()

const emit = defineEmits<{
  /** Emitted when button is clicked (trigger analysis or cancel) */
  analyze: []
}>()

function handleClick() {
  emit('analyze')
}
</script>

<template>
  <button
    type="button"
    class="w-full px-4 py-2 text-sm font-medium rounded-md transition-colors"
    :class="{
      'bg-blue-600 text-white hover:bg-blue-700': !isAnalyzing,
      'bg-blue-500 text-white cursor-wait': isAnalyzing
    }"
    :disabled="isAnalyzing"
    @click="handleClick"
  >
    <!-- Spinner icon when analyzing -->
    <span v-if="isAnalyzing" class="inline-flex items-center gap-2">
      <svg class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Analyzing...
    </span>
    
    <!-- "Analyze Again" text when suggestions loaded -->
    <span v-else-if="hasAnalyzed">
      ↻ Analyze Again
    </span>
    
    <!-- Initial "Analyze with AI" text -->
    <span v-else>
      ✨ Analyze with AI
    </span>
  </button>
</template>
```

### File: `extension/entrypoints/popup/components/AiSuggestions.vue`

This component is **novel** - container for suggestions with privacy notice. Full implementation detail provided:

```vue
<script lang="ts" setup>
/**
 * AI Suggestions Container Component
 * 
 * Displays AI analysis results in a dedicated section:
 * - Section header with robot emoji
 * - SuggestedNote component (note + add button)
 * - SuggestedTags component (toggleable chips)
 * - Privacy notice (content sent to OpenAI)
 * 
 * Only shown after successful analysis (parent controls visibility).
 */

import type { SuggestedTag } from '../../../../lib/types'
import SuggestedNote from './SuggestedNote.vue'
import SuggestedTags from './SuggestedTags.vue'

const props = defineProps<{
  /** AI-generated note text */
  suggestedNote: string
  
  /** Array of AI-suggested tags with exists flags */
  suggestedTags: SuggestedTag[]
  
  /** Set of currently selected tag names (for chip state) */
  selectedTagNames: Set<string>
}>()

const emit = defineEmits<{
  /** Emitted when user clicks "[+ Add to Notes]" button */
  addNote: [note: string]
  
  /** Emitted when user toggles a tag chip on/off */
  toggleTag: [tagName: string]
}>()

function handleAddNote() {
  emit('addNote', props.suggestedNote)
}

function handleToggleTag(tagName: string) {
  emit('toggleTag', tagName)
}
</script>

<template>
  <div class="bg-blue-50 border border-blue-200 rounded-md p-4 space-y-3">
    <!-- Section header -->
    <div class="flex items-center justify-between">
      <h3 class="text-sm font-semibold text-slate-700">
        🤖 AI Suggestions
      </h3>
      <span class="text-xs text-slate-500">
        ⚠️ Content sent to OpenAI
      </span>
    </div>
    
    <!-- Suggested note -->
    <SuggestedNote
      :note="suggestedNote"
      @add-note="handleAddNote"
    />
    
    <!-- Suggested tags -->
    <SuggestedTags
      :tags="suggestedTags"
      :selected-tag-names="selectedTagNames"
      @toggle-tag="handleToggleTag"
    />
  </div>
</template>
```

### File: `extension/entrypoints/popup/components/SuggestedNote.vue`

This component is **novel** - note display with add button. Full implementation detail provided:

```vue
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

const props = defineProps<{
  /** AI-generated note text (1-2 sentences) */
  note: string
}>()

const emit = defineEmits<{
  /** Emitted when user clicks add button */
  addNote: []
}>()

function handleAddNote() {
  emit('addNote')
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
```

### File: `extension/entrypoints/popup/components/SuggestedTags.vue`

This component is **novel** - implements 4-state toggle chips (exists × selected). Full implementation detail provided:

```vue
<script lang="ts" setup>
/**
 * Suggested Tags Component
 * 
 * Displays AI-suggested tags as toggleable chips with 4 visual states:
 * 1. Green + Solid: Existing tag, selected (added to main field)
 * 2. Green + Outline: Existing tag, unselected (not in main field)
 * 3. Blue + Solid: New tag, selected (added to main field, will be created)
 * 4. Blue + Outline: New tag, unselected (not in main field)
 * 
 * Visual communication:
 * - Green = tag exists in user's collection
 * - Blue = new tag will be created
 * - Solid = selected (in main TagInput)
 * - Outline = not selected (not in main TagInput)
 * 
 * All chips start unselected (outline style) - explicit opt-in approach.
 * User clicks to toggle selection on/off.
 */

import type { SuggestedTag } from '../../../../lib/types'

const props = defineProps<{
  /** Array of AI-suggested tags with exists flags */
  tags: SuggestedTag[]
  
  /** Set of currently selected tag names (for determining chip state) */
  selectedTagNames: Set<string>
}>()

const emit = defineEmits<{
  /** Emitted when user clicks a tag chip to toggle selection */
  toggleTag: [tagName: string]
}>()

/**
 * Check if tag is currently selected
 * @param tagName - Tag name to check
 * @returns true if tag is in selectedTagNames Set
 */
function isSelected(tagName: string): boolean {
  return props.selectedTagNames.has(tagName)
}

/**
 * Get chip CSS classes based on state
 * @param tag - Tag object with name and exists flag
 * @returns Object with CSS classes for current state
 */
function getChipClasses(tag: SuggestedTag) {
  const selected = isSelected(tag.name)
  
  return {
    // Base chip styles
    'inline-flex items-center px-3 py-1 rounded-full text-sm font-medium cursor-pointer transition-colors': true,
    
    // Existing tag, selected (green solid)
    'bg-green-600 text-white': tag.exists && selected,
    
    // Existing tag, unselected (green outline)
    'border-2 border-green-600 text-green-700 bg-white hover:bg-green-50': tag.exists && !selected,
    
    // New tag, selected (blue solid)
    'bg-blue-600 text-white': !tag.exists && selected,
    
    // New tag, unselected (blue outline)
    'border-2 border-blue-600 text-blue-700 bg-white hover:bg-blue-50': !tag.exists && !selected,
  }
}

function handleToggle(tagName: string) {
  emit('toggleTag', tagName)
}
</script>

<template>
  <div>
    <div class="text-xs text-slate-600 mb-2">
      Tags (click to select):
    </div>
    
    <div class="flex flex-wrap gap-2">
      <button
        v-for="tag in tags"
        :key="tag.name"
        type="button"
        :class="getChipClasses(tag)"
        @click="handleToggle(tag.name)"
      >
        {{ tag.name }}
      </button>
    </div>
  </div>
</template>
```

### Tasks

- [ ] Create `extension/entrypoints/popup/components/AiAnalyzeButton.vue` with implementation above
- [ ] Create `extension/entrypoints/popup/components/AiSuggestions.vue` with implementation above
- [ ] Create `extension/entrypoints/popup/components/SuggestedNote.vue` with implementation above
- [ ] Create `extension/entrypoints/popup/components/SuggestedTags.vue` with implementation above
- [ ] Verify all components use TypeScript `<script lang="ts" setup>`
- [ ] Verify all components import required types from '../../../../lib/types'
- [ ] Test button state transitions (idle → analyzing → analyzed)
- [ ] Test tag chip visual states (all 4 combinations render correctly)
- [ ] Verify Tailwind CSS classes work in extension context
- [ ] Test click handlers emit events correctly

**Implementation Notes:**
- **Button States**: Visual feedback for all 3 states (idle, loading, analyzed)
- **Chip States**: 4 distinct visual states communicate two attributes (exists, selected)
- **All Unselected Initially**: Explicit opt-in approach - user must click to select
- **Real-time Updates**: Selected tags automatically sync to main field (handled by parent)

---

## Phase 6: Integration

**Purpose:** Integrate AI components into LinkForm and wire up data flow.

**Justification:** Connects all pieces - button triggers analysis, suggestions displayed, selections sync to main fields. (spec.md#5.4)

### File: `extension/entrypoints/popup/components/LinkForm.vue`

Modify existing LinkForm to integrate AI analysis components. Pattern references provided (not full detail):

**Import Additions:**
```typescript
import { useAiAnalysis } from '../../../lib/composables/useAiAnalysis'
import AiAnalyzeButton from './AiAnalyzeButton.vue'
import AiSuggestions from './AiSuggestions.vue'
```

**Composable Setup (add to existing composables):**
```typescript
const { state: aiState, analyze, toggleTag, getSelectedTags, reset: resetAiState } = useAiAnalysis()
```

**Analysis Handler (new function):**
```typescript
async function handleAnalyze() {
  if (!props.currentTabInfo) return
  await analyze(props.currentTabInfo.url)
}
```

**Tag Syncing Logic (watch for AI selections):**
```typescript
// Watch AI tag selections and sync to main tagNames field
watch(() => Array.from(aiState.value.selectedTagNames), (selectedAiTags) => {
  // Merge AI-selected tags with manually-entered tags
  // Remove AI tags that were deselected
  // Keep manual tags that weren't from AI
  const manualTags = tagNames.value.filter(tag => 
    !aiState.value.suggestedTags.some(st => st.name === tag)
  )
  tagNames.value = [...manualTags, ...selectedAiTags]
}, { deep: true })
```

**Note Insertion Handler (new function):**
```typescript
function handleAddNote(note: string) {
  notes.value = note
}
```

**Reset AI State on Tab Change (add to existing watch):**
```typescript
watch(() => props.currentTabInfo, async (newTabInfo) => {
  // ... existing logic ...
  
  // Reset AI state for new tab
  resetAiState()
})
```

**Template Updates (add between UrlInput and NotesInput):**
```vue
<!-- AI Analysis Section -->
<AiAnalyzeButton
  :is-analyzing="aiState.isAnalyzing"
  :has-analyzed="aiState.suggestedTags.length > 0"
  @analyze="handleAnalyze"
/>

<!-- Show suggestions after successful analysis -->
<AiSuggestions
  v-if="aiState.suggestedTags.length > 0"
  :suggested-note="aiState.suggestedNote || ''"
  :suggested-tags="aiState.suggestedTags"
  :selected-tag-names="aiState.selectedTagNames"
  @add-note="handleAddNote"
  @toggle-tag="toggleTag"
/>

<!-- Show error if analysis failed -->
<div v-if="aiState.error" class="text-sm text-red-600">
  {{ aiState.error }}
</div>
```

### Tasks

- [ ] Import useAiAnalysis composable and AI components in LinkForm.vue
- [ ] Add aiState from useAiAnalysis to composables section
- [ ] Add handleAnalyze function to trigger analysis
- [ ] Add watch for aiState.selectedTagNames to sync to main tagNames field in real-time
- [ ] Add handleAddNote function to populate notes field
- [ ] Add resetAiState() call in tab change watcher
- [ ] Insert AiAnalyzeButton component between UrlInput and NotesInput
- [ ] Insert AiSuggestions component (conditional, only when suggestions exist)
- [ ] Insert error display (conditional, only when error exists)
- [ ] Test complete flow: click button → see suggestions → select tags → tags appear in main field
- [ ] Test note insertion: click "[+ Add to Notes]" → note populates NotesInput
- [ ] Test tab changes: navigate to new tab → AI state resets → no stale suggestions

**Pattern Reference:** Follow existing LinkForm patterns:
- Composables section (lines 26-28)
- Watch for tab changes (lines 37-63)
- Handler functions (lines 69-147)
- Template structure (lines 150-176)

**Integration Points:**
- **Button placement**: After UrlInput, before NotesInput (visible position)
- **Real-time syncing**: watch() for selectedTagNames → update tagNames
- **State reset**: Call resetAiState() when tab changes
- **Error display**: Simple error message below button

---

## Phase 7: Manual Testing

**Purpose:** Verify AI analysis feature works end-to-end with real pages.

**Justification:** No extension test framework - manual verification ensures feature works in real-world usage. (requirements.md#8)

### Testing Approach

Test with real browser extension in development mode. Focus on key scenarios and edge cases.

### Test Scenarios

**Basic Flow:**
- [ ] Open extension on article page, click "Analyze with AI"
- [ ] Verify loading spinner appears during analysis
- [ ] Verify suggestions appear after 3-5 seconds
- [ ] Verify green chips for existing tags, blue chips for new tags
- [ ] Click tag chips to select, verify main TagInput updates in real-time
- [ ] Click "[+ Add to Notes]", verify note populates NotesInput
- [ ] Save link, verify all selected tags and note are saved

**Privacy Protection:**
- [ ] Try analyzing http://localhost:3000 → should show error immediately
- [ ] Try analyzing http://192.168.1.1 → should show error immediately
- [ ] Try analyzing public domain → should work normally

**Content Extraction:**
- [ ] Test on blog articles (should extract clean text)
- [ ] Test on documentation pages (should extract content)
- [ ] Test on pages with minimal content (should handle gracefully)
- [ ] Test on very long pages (should truncate at 50K chars)

**Error Handling:**
- [ ] Disconnect network, try analysis → should show error
- [ ] Test with invalid API key → should show error
- [ ] Navigate to new tab during analysis → should cancel/reset

**Tag Selection:**
- [ ] Select multiple tags, verify all appear in main field
- [ ] Deselect tags, verify they're removed from main field
- [ ] Manually type tags, verify they're preserved alongside AI tags
- [ ] Select AI tags, then manually type same tag → no duplicates

**Re-analysis:**
- [ ] Click "Analyze Again" after getting suggestions
- [ ] Verify previous selections are cleared
- [ ] Verify new suggestions replace old ones

### Manual Testing Complete

After testing all scenarios above, feature is ready for production use.

---

## Implementation Complete

After completing all phases:

1. **Verify Build:**
   - Run `cd extension && pnpm run build`
   - Load extension in browser (chrome://extensions in dev mode)
   - Test on real pages

2. **Check Console:**
   - Open DevTools console
   - Verify no JavaScript errors
   - Check network tab for API calls

3. **User Experience:**
   - Analysis feels fast (3-5 seconds typical)
   - Suggestions are relevant and useful
   - Tag selection UX is smooth
   - Real-time syncing works reliably

**Success Criteria:**
- [ ] Content extraction works on various page types
- [ ] Privacy protection blocks localhost/private IPs
- [ ] AI returns relevant tag and note suggestions
- [ ] Existing tags display as green, new tags as blue
- [ ] Tag selection syncs to main field in real-time
- [ ] Note insertion populates NotesInput field
- [ ] Error handling is graceful and informative
- [ ] Tab changes reset AI state correctly
- [ ] Complete flow works: analyze → select → save

