# LR003 - AI-Powered Link Analysis: Technical Specification

## Table of Contents

- [LR003 - AI-Powered Link Analysis: Technical Specification](#lr003---ai-powered-link-analysis-technical-specification)
  - [Table of Contents](#table-of-contents)
  - [1. Overview](#1-overview)
  - [2. Architecture Overview](#2-architecture-overview)
    - [2.1 System Architecture](#21-system-architecture)
    - [2.2 Core Design Decisions](#22-core-design-decisions)
    - [2.3 Technology Choices](#23-technology-choices)
  - [3. API Architecture](#3-api-architecture)
    - [3.1 Endpoint Definition](#31-endpoint-definition)
    - [3.2 Request Contract](#32-request-contract)
    - [3.3 Response Contract](#33-response-contract)
    - [3.4 Error Responses](#34-error-responses)
  - [4. Backend Architecture](#4-backend-architecture)
    - [4.1 Service Layer](#41-service-layer)
    - [4.2 AI Integration](#42-ai-integration)
    - [4.3 Tag Matching Logic](#43-tag-matching-logic)
    - [4.4 Content Validation](#44-content-validation)
  - [5. Extension Architecture](#5-extension-architecture)
    - [5.1 Type Definitions](#51-type-definitions)
    - [5.2 API Client Integration](#52-api-client-integration)
    - [5.3 Content Extraction](#53-content-extraction)
    - [5.4 Component Architecture](#54-component-architecture)
    - [5.5 State Management](#55-state-management)
  - [6. Configuration Architecture](#6-configuration-architecture)
    - [6.1 Backend Configuration](#61-backend-configuration)
    - [6.2 Extension Dependencies](#62-extension-dependencies)
  - [7. Integration Architecture](#7-integration-architecture)
    - [7.1 Privacy Protection](#71-privacy-protection)
    - [7.2 Error Handling Strategy](#72-error-handling-strategy)
  - [8. File Organization](#8-file-organization)
    - [8.1 Backend Files](#81-backend-files)
    - [8.2 Extension Files](#82-extension-files)
  - [9. Quality Attributes](#9-quality-attributes)
    - [9.1 Performance](#91-performance)
    - [9.2 Security](#92-security)
    - [9.3 Reliability](#93-reliability)
    - [9.4 Maintainability](#94-maintainability)
  - [Implementation Notes](#implementation-notes)

---

## 1. Overview

This specification defines the architecture for AI-powered link analysis, enabling users to get intelligent tag and note suggestions when saving links. The feature provides on-demand AI assistance without disrupting manual workflows.

**Core Capability**: User clicks "Analyze with AI" button, extension extracts page content, backend calls OpenAI via RubyLLM to generate tag and note suggestions, user selectively accepts suggestions.

**Key Architectural Principles**:
- **Stateless Analysis**: No database persistence, ephemeral request/response only
- **Defense in Depth**: Privacy protection at both extension and backend layers
- **Graceful Degradation**: AI failures never block manual link saving
- **Non-Destructive UI**: Suggestions appear separately, never overwrite user input
- **Pattern Consistency**: Follows established API response formats, error handling, and authentication patterns

---

## 2. Architecture Overview

### 2.1 System Architecture

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│  Browser    │────────▶│  Extension  │────────▶│   Backend   │
│  (Content)  │         │  (Extract)  │         │  (Analyze)  │
└─────────────┘         └─────────────┘         └─────────────┘
                              │                        │
                              │                        ▼
                              │                  ┌─────────────┐
                              │                  │   RubyLLM   │
                              │                  │  (OpenAI)   │
                              │                  └─────────────┘
                              ▼
                        ┌─────────────┐
                        │  Popup UI   │
                        │ (Suggestions)│
                        └─────────────┘
```

**Flow**:
1. User opens extension on a page and clicks "Analyze with AI" button
2. Extension extracts content using @mozilla/readability and validates privacy constraints
3. Extension sends `{url, content, title, description, author}` to backend analyze endpoint
4. Backend queries user's existing tags and constructs AI prompt with context
5. Backend calls OpenAI GPT-4o-mini via RubyLLM with structured JSON output
6. Backend matches suggested tags against existing tags (case-insensitive)
7. Backend returns `{suggested_note, suggested_tags: [{name, exists}]}`
8. Extension displays suggestions in separate UI section with toggleable tag chips
9. User selectively accepts suggestions which populate into main form fields
10. User saves link via existing save flow (unchanged)

### 2.2 Core Design Decisions

**1. Backend-Only AI Integration**
- Extension never calls OpenAI directly
- Backend handles all LLM communication via RubyLLM gem
- Centralizes API key management and cost monitoring

**2. Content Extraction at Extension**
- Extension performs content extraction using @mozilla/readability
- Backend receives pre-extracted content, never fetches pages
- Avoids complexity of headless browser rendering on backend
- Leverages browser's existing DOM access

**3. Stateless, Ephemeral Operation**
- No database tables for analysis requests or results
- No caching of analysis results (pages change frequently)
- Simple request/response cycle keeps implementation straightforward

**4. Two-Stage Tag Intelligence**
- Stage 1: AI receives existing tag names, instructed to prefer them
- Stage 2: Backend verifies and marks which suggestions actually exist
- Ensures accuracy while guiding AI toward consistency

**5. Defense in Depth Privacy**
- Extension blocks localhost/private IPs before sending (UX + privacy)
- Backend validates with Addressable gem (security boundary)
- Manual trigger ensures user consent before sending content to OpenAI

### 2.3 Technology Choices

**Backend**:
- **RubyLLM** (~> 1.8): Unified LLM API client, already integrated
- **OpenAI GPT-4o-mini**: Cost-effective model via RubyLLM
- **Structured Outputs**: RubyLLM's JSON schema support for reliable parsing
- **Addressable**: URL validation and private IP detection (existing dependency)

**Extension**:
- **@mozilla/readability**: Industry-standard content extraction library
- **ip-address** (or similar): Private IP detection for privacy protection
- **TypeScript**: Type-safe API contracts and suggestion handling
- **Vue 3 Composables**: State management for analysis lifecycle

**Architecture Pattern**: Rails API backend with Vue.js extension frontend, following existing patterns established in codebase.

---

## 3. API Architecture

### 3.1 Endpoint Definition

```
POST /api/v1/links/analyze
```

**Purpose**: Analyze page content and return AI-generated tag and note suggestions.

**Authentication**: Bearer token (existing API key authentication)

**Content-Type**: `application/json`

**Characteristics**:
- Stateless operation (no database persistence)
- Idempotent (same input produces same output, subject to AI variability)
- No side effects (doesn't modify any data)

### 3.2 Request Contract

**Required Parameters**:
```ruby
{
  url: String,           # Page URL (HTTP/HTTPS only)
  content: String,       # Main article text from Readability (max 50,000 chars)
  title: String,         # Page title (og:title, <title>, or h1)
  description: String,   # Meta description (og:description or meta description)
  author: String         # Author info (optional, can be nil)
}
```

**Parameter Details**:

- **url**: Full page URL
  - Must be valid HTTP or HTTPS
  - Used for domain context in AI analysis
  - Backend validates not localhost/private IP

- **content**: Main article text
  - Extracted via @mozilla/readability in extension
  - Maximum 50,000 characters (enforced on backend)
  - Whitespace normalized but paragraph structure preserved
  - Empty content allowed (AI uses URL/title/description)

- **title**: Page title
  - Fallback chain: og:title → `<title>` → first `<h1>`
  - Required field (cannot be blank)

- **description**: Meta description
  - Fallback chain: og:description → meta description
  - Optional (can be blank)

- **author**: Author information
  - From meta author tag or og:article:author
  - Optional (can be blank)

**Validation Rules**:
- URL must be present and valid HTTP/HTTPS format
- URL must not be localhost or private IP address
- Content length must not exceed 50,000 characters
- Title must be present (cannot be blank)

### 3.3 Response Contract

**Success Response (200 OK)**:

```ruby
{
  data: {
    suggested_note: String,        # 1-2 sentence note explaining content value
    suggested_tags: [              # Array of 3-7 suggested tags
      {
        name: String,              # Tag name (Title Case preferred)
        exists: Boolean            # true if tag exists in user's collection
      }
    ]
  }
}
```

**Response Structure**:

File: `app/views/api/v1/links/analyze.jbuilder`

```ruby
json.data do
  json.suggested_note @suggested_note
  json.suggested_tags @suggested_tags do |tag|
    json.name tag[:name]
    json.exists tag[:exists]
  end
end
```

**Field Specifications**:

- **suggested_note**: 
  - Casual, conversational tone
  - Generally 1-2 sentences (guideline, not enforced)
  - Explains why content is worth saving
  - Example: "Comprehensive guide to Ruby metaprogramming patterns with practical examples. Covers method_missing, define_method, and class_eval in depth."

- **suggested_tags**:
  - Array of 3-7 tags (flexible based on content)
  - Ordered by AI's relevance ranking (most relevant first)
  - Each tag includes:
    - `name`: Tag name in Title Case (e.g., "JavaScript") or lowercase
    - `exists`: Boolean indicating if tag exists in user's Tag table (case-insensitive match)

**Tag Existence Indicator**:
- `exists: true` → Extension displays tag chip in **green** (existing tag)
- `exists: false` → Extension displays tag chip in **blue** (new tag will be created)

### 3.4 Error Responses

All error responses follow the established `ResponseHelpers` pattern.

**Validation Error (422 Unprocessable Content)**:
```ruby
{
  error: {
    code: "validation_failed",
    message: "Content exceeds maximum length of 50,000 characters"
  }
}
```

**Bad Request (400 Bad Request)**:
```ruby
{
  error: {
    code: "invalid_argument",
    message: "URL must be HTTP or HTTPS"
  }
}
```

**Unauthorized (401 Unauthorized)**:
```ruby
{
  error: {
    code: "unauthorized",
    message: "Invalid or missing API token"
  }
}
```

**OpenAI API Failure (500 Internal Server Error)**:
```ruby
{
  error: {
    code: "ai_analysis_failed",
    message: "Failed to analyze content. Please try again."
  }
}
```

**Error Scenarios**:
1. **Invalid URL format**: 400 with "invalid_argument"
2. **Localhost/private IP**: 400 with "forbidden_url"
3. **Content too long**: 422 with "validation_failed"
4. **Missing required fields**: 400 with "invalid_argument"
5. **OpenAI API timeout/error**: 500 with "ai_analysis_failed"
6. **JSON parse error from OpenAI**: 500 with "ai_analysis_failed"

**Error Handling Philosophy**:
- User-facing errors are friendly and actionable
- Backend logs detailed exception information for debugging
- Extension displays generic error message and allows retry
- Errors never block manual link saving workflow

---

## 4. Backend Architecture

### 4.1 Service Layer

**Service Object Pattern**:

```ruby
# app/services/link_radar/ai/analyze_link_content.rb
module LinkRadar
  module AI
    class AnalyzeLinkContent
      # Service contract:
      # - Input: {url:, content:, title:, description:, author:} (all strings)
      # - Output: {suggested_note:, suggested_tags: [{name:, exists:}]}
      # - Raises: ArgumentError for validation failures
      # - Raises: StandardError for AI/network failures
      
      def initialize(url:, content:, title:, description: nil, author: nil)
        @url = url
        @content = content
        @title = title
        @description = description
        @author = author
      end
      
      def call
        validate_inputs!
        existing_tags = fetch_existing_tags
        ai_response = call_openai(existing_tags)
        mark_existing_tags(ai_response, existing_tags)
      end
      
      private
      
      def validate_inputs!
        # Validate URL format, not localhost/private IP
        # Validate content length <= 50,000 chars
        # Validate title presence
      end
      
      def fetch_existing_tags
        # Returns array of tag names: ["JavaScript", "Ruby", ...]
        Tag.pluck(:name)
      end
      
      def call_openai(existing_tags)
        # Constructs prompt with content + existing tags context
        # Calls OpenAI via RubyLLM with structured output
        # Returns parsed JSON: {note:, tags: [...]}
      end
      
      def build_response(ai_response, existing_tags)
        # Transforms AI response into API response format
        # Maps tags and adds exists: boolean via case-insensitive matching
        # Returns: {suggested_note:, suggested_tags: [{name:, exists:}]}
      end
    end
  end
end
```

**Controller Integration**:

```ruby
# app/controllers/api/v1/links_controller.rb
class Api::V1::LinksController < ApplicationController
  # POST /api/v1/links/analyze
  def analyze
    result = LinkRadar::AI::AnalyzeLinkContent.new(
      url: params[:url],
      content: params[:content],
      title: params[:title],
      description: params[:description],
      author: params[:author]
    ).call
    
    @suggested_note = result[:suggested_note]
    @suggested_tags = result[:suggested_tags]
    
    render :analyze
  end
end
```

**Service Responsibilities**:
1. Input validation (URL format, content length, required fields)
2. Privacy validation (no localhost/private IPs using Addressable gem)
3. Fetching user's existing tags from database
4. Constructing AI prompt with content and tag context
5. Calling OpenAI via RubyLLM with structured output schema
6. Parsing and validating AI response
7. Case-insensitive tag matching to mark existence
8. Error handling and logging

### 4.2 AI Integration

**RubyLLM Configuration** (existing):

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = LlmConfig.openai_api_key
  config.use_new_acts_as = true
end
```

**Structured Output Schema**:

```ruby
# Define JSON schema for OpenAI structured output
ANALYSIS_SCHEMA = {
  type: "object",
  properties: {
    note: {
      type: "string",
      description: "1-2 sentence note explaining why content is worth saving"
    },
    tags: {
      type: "array",
      description: "Relevant tags for the content (typically 3-7)",
      items: {
        type: "string"
      }
    }
  },
  required: ["note", "tags"]
}
```

**AI Prompt Structure**:

```ruby
def build_prompt(content, title, description, author, existing_tags)
  <<~PROMPT
    You are helping a user organize web content they want to save for later.
    
    Analyze this content and suggest:
    1. A brief note (1-2 sentences) explaining why it's worth saving
    2. Relevant tags (3-7 tags) to categorize it
    
    CONTENT DETAILS:
    Title: #{title}
    #{description ? "Description: #{description}" : ""}
    #{author ? "Author: #{author}" : ""}
    URL: #{url}
    
    CONTENT:
    #{truncated_content}
    
    EXISTING TAGS:
    The user already has these tags: #{existing_tags.join(", ")}
    
    INSTRUCTIONS:
    - Note should be casual and conversational
    - Prefer using existing tags when relevant (but don't force-fit)
    - Be liberal with tags - capture nuances without artificial constraints
    - Use Title Case for new tags (e.g., "JavaScript" not "javascript")
    - Don't suggest obvious synonyms if existing tag exists (e.g., don't suggest "js" if "JavaScript" exists)
    - Suggest 3-7 tags based purely on content relevance
  PROMPT
end
```

**RubyLLM Call**:

```ruby
def call_openai(existing_tags)
  prompt = build_prompt(@content, @title, @description, @author, existing_tags)
  
  response = RubyLLM::Messages.create(
    model: "gpt-4o-mini",
    messages: [
      { role: "system", content: "You are a helpful assistant that analyzes web content." },
      { role: "user", content: prompt }
    ],
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "link_analysis",
        schema: ANALYSIS_SCHEMA
      }
    }
  )
  
  JSON.parse(response.choices.first.message.content)
rescue => e
  Rails.logger.error("OpenAI API call failed: #{e.class} - #{e.message}")
  raise StandardError, "AI analysis failed"
end
```

**Error Handling**:
- Timeout errors from OpenAI API
- Invalid JSON responses
- Schema validation failures
- API rate limits
- Network errors

All errors logged with full context and re-raised as `StandardError` for controller to handle via `ErrorHandlers` concern.

### 4.3 Tag Matching Logic

**Two-Stage Process**:

**Stage 1: AI Context** (during prompt construction)
- Send all existing tag names to AI: `"JavaScript, Ruby, Web Development, ..."`
- Instruct AI to prefer these tags when relevant
- AI naturally gravitates toward existing taxonomy

**Stage 2: Backend Verification** (after AI response)
- Case-insensitive matching: `"javascript"` matches `"JavaScript"`
- Exact name matching only (no fuzzy matching)
- Mark each suggestion with `exists` boolean

**Implementation**:

```ruby
def mark_existing_tags(ai_response, existing_tags)
  # Build lowercase lookup hash for O(1) matching
  existing_tags_downcase = existing_tags.map(&:downcase).to_set
  
  suggested_tags = ai_response["tags"].map do |tag_name|
    {
      name: tag_name,
      exists: existing_tags_downcase.include?(tag_name.downcase)
    }
  end
  
  {
    suggested_note: ai_response["note"],
    suggested_tags: suggested_tags
  }
end
```

**Why Two Stages**:
1. **AI Guidance**: Sending existing tags helps AI suggest consistent tags naturally
2. **Accuracy**: Backend verification ensures `exists` flag is 100% accurate
3. **Case Handling**: AI might return "javascript" when user has "JavaScript" - backend detects this as existing

### 4.4 Content Validation

**Privacy Protection** (reuses UrlValidator):

```ruby
def validate_not_private_url(url)
  # Reuses existing SSRF protection from content archiving
  result = LinkRadar::ContentArchiving::UrlValidator.new(url).call
  
  raise ArgumentError, result.errors.first if result.failure?
end
```

**Content Length Validation**:

```ruby
def validate_content_length(content)
  max_length = 50_000
  if content.length > max_length
    raise ArgumentError, "Content exceeds maximum length of #{max_length} characters"
  end
end
```

**Required Fields Validation**:

```ruby
def validate_required_fields(url, title)
  raise ArgumentError, "URL is required" if url.blank?
  raise ArgumentError, "Title is required" if title.blank?
end
```

---

## 5. Extension Architecture

### 5.1 Type Definitions

**File: `extension/lib/types/ai-analysis.ts`**

```typescript
/**
 * Analysis request payload sent to backend
 */
export interface AnalyzeRequest {
  url: string
  content: string
  title: string
  description: string
  author?: string
}

/**
 * Individual tag suggestion from AI
 */
export interface SuggestedTag {
  name: string        // Tag name (Title Case or lowercase)
  exists: boolean     // true if tag exists in user's collection
}

/**
 * Analysis response from backend
 */
export interface AnalyzeResponse {
  data: {
    suggested_note: string
    suggested_tags: SuggestedTag[]
  }
}

/**
 * Extracted page content from Readability
 */
export interface ExtractedContent {
  content: string      // Main article text
  title: string        // Page title (og:title, <title>, or h1)
  description: string  // Meta description
  author?: string      // Author info (optional)
  url: string         // Page URL
}

/**
 * Analysis state for UI
 */
export interface AnalysisState {
  isAnalyzing: boolean
  error: string | null
  suggestedNote: string | null
  suggestedTags: SuggestedTag[]
  selectedTagNames: Set<string>  // Track which tags user has selected
}
```

### 5.2 API Client Integration

**File: `extension/lib/apiClient.ts`**

```typescript
/**
 * Analyze page content and get AI suggestions for tags and notes
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

**Error Handling**:
- Timeout errors (15 second client-side timeout)
- Network failures
- API errors (400, 422, 500)
- Returns user-friendly error messages for display

### 5.3 Content Extraction

**Privacy Protection**:

```typescript
// File: extension/lib/privacy.ts

import { Address4, Address6 } from 'ip-address'

/**
 * Check if URL is safe to analyze (not localhost or private IP)
 */
export function isSafeToAnalyze(url: string): boolean {
  try {
    const urlObj = new URL(url)
    
    // Check for localhost
    if (urlObj.hostname === 'localhost' 
        || urlObj.hostname === '127.0.0.1' 
        || urlObj.hostname === '::1') {
      return false
    }
    
    // Check for private IPv4
    const ipv4 = new Address4(urlObj.hostname)
    if (ipv4.isValid() && !ipv4.isPublic()) {
      return false
    }
    
    // Check for private IPv6
    const ipv6 = new Address6(urlObj.hostname)
    if (ipv6.isValid() && !ipv6.isPublic()) {
      return false
    }
    
    return true
  } catch {
    return true // If parsing fails, let backend validate
  }
}
```

**Content Extraction** (using @mozilla/readability):

```typescript
// File: extension/lib/contentExtractor.ts

import { Readability } from '@mozilla/readability'

export interface ExtractionResult {
  content: string
  title: string
  description: string
  author?: string
}

/**
 * Extract page content using Readability
 */
export function extractPageContent(): ExtractionResult {
  // Clone document for Readability (it modifies the DOM)
  const documentClone = document.cloneNode(true) as Document
  
  // Extract main content
  const reader = new Readability(documentClone)
  const article = reader.parse()
  
  // Extract metadata
  const ogTitle = document.querySelector('meta[property="og:title"]')
    ?.getAttribute('content')
  const ogDescription = document.querySelector('meta[property="og:description"]')
    ?.getAttribute('content')
  const metaDescription = document.querySelector('meta[name="description"]')
    ?.getAttribute('content')
  const metaAuthor = document.querySelector('meta[name="author"]')
    ?.getAttribute('content')
  const ogAuthor = document.querySelector('meta[property="og:article:author"]')
    ?.getAttribute('content')
  
  // Fallback chain for title
  const title = ogTitle 
    || document.title 
    || document.querySelector('h1')?.textContent 
    || 'Untitled'
  
  // Fallback chain for description
  const description = ogDescription || metaDescription || ''
  
  // Optional author
  const author = metaAuthor || ogAuthor
  
  return {
    content: article?.textContent || '',
    title: title.trim(),
    description: description.trim(),
    author: author?.trim(),
  }
}
```

**Content Validation**:
- Extension truncates content to 50,000 characters before sending (network efficiency, user feedback)
- Backend validates maximum length as safety check (rejects anything over 50,000 chars)
- Empty content allowed (AI uses metadata)
- Whitespace normalization handled by Readability

### 5.4 Component Architecture

**File Summary**:
- `LinkForm.vue` - Parent form component (existing, add analyze button here)
- `AiAnalyzeButton.vue` - New button component with state management
- `AiSuggestions.vue` - New component displaying AI suggestions
- `SuggestedNote.vue` - Note display with "Add to Notes" button
- `SuggestedTags.vue` - Tag chips with toggle selection
- `composables/useAiAnalysis.ts` - Analysis state and logic

**Component Hierarchy**:

```
LinkForm.vue
├── AiAnalyzeButton.vue        (triggers analysis)
├── AiSuggestions.vue           (displays results)
│   ├── SuggestedNote.vue       (note + add button)
│   └── SuggestedTags.vue       (tag chips)
├── NotesInput.vue              (existing, receives note)
├── TagInput.vue                (existing, receives tags)
└── LinkActions.vue             (existing save buttons)
```

**Button States**:
1. Initial: "✨ Analyze with AI" (blue, clickable)
2. Analyzing: "Analyzing..." with spinner (clickable to cancel)
3. Success: "↻ Analyze Again" (allows regeneration)
4. Error: "✨ Analyze with AI" (allows retry)

**Suggestions Section Visibility**:
- Only appears after successful analysis
- Persists until user navigates to different tab
- Can be regenerated with "Analyze Again"

**Tag Chip States** (4 visual combinations):
- **Green + Solid**: Existing tag, selected (added to main field)
- **Green + Outline**: Existing tag, unselected (not in main field)
- **Blue + Solid**: New tag, selected (added to main field, will be created)
- **Blue + Outline**: New tag, unselected (not in main field)

### 5.5 State Management

**Composable: `useAiAnalysis.ts`**

```typescript
import { ref } from 'vue'
import type { AnalysisState, SuggestedTag } from '../types/ai-analysis'
import { analyzeLink } from '../apiClient'
import { extractPageContent } from '../contentExtractor'
import { isSafeToAnalyze } from '../privacy'

export function useAiAnalysis() {
  const state = ref<AnalysisState>({
    isAnalyzing: false,
    error: null,
    suggestedNote: null,
    suggestedTags: [],
    selectedTagNames: new Set(),
  })
  
  /**
   * Trigger analysis for current page
   */
  async function analyze(url: string): Promise<void> {
    // Privacy check
    if (!isSafeToAnalyze(url)) {
      state.value.error = 'Cannot analyze localhost or private URLs'
      return
    }
    
    // Extract content
    const extracted = extractPageContent()
    
    // Call backend
    state.value.isAnalyzing = true
    state.value.error = null
    
    try {
      const response = await analyzeLink({
        url,
        content: extracted.content,
        title: extracted.title,
        description: extracted.description,
        author: extracted.author,
      })
      
      state.value.suggestedNote = response.data.suggested_note
      state.value.suggestedTags = response.data.suggested_tags
      state.value.selectedTagNames.clear()
    } catch (error) {
      state.value.error = error instanceof Error 
        ? error.message 
        : 'Analysis failed. Please try again.'
    } finally {
      state.value.isAnalyzing = false
    }
  }
  
  /**
   * Toggle tag selection
   */
  function toggleTag(tagName: string): void {
    if (state.value.selectedTagNames.has(tagName)) {
      state.value.selectedTagNames.delete(tagName)
    } else {
      state.value.selectedTagNames.add(tagName)
    }
  }
  
  /**
   * Get currently selected tag names as array
   */
  function getSelectedTags(): string[] {
    return Array.from(state.value.selectedTagNames)
  }
  
  /**
   * Reset analysis state
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

**Integration with LinkForm**:
- Selected tags automatically sync to main TagInput field in real-time
- Suggested note populates NotesInput on "[+ Add to Notes]" button click
- All selections merge with manual input
- Analysis state resets on tab change

---

## 6. Configuration Architecture

### 6.1 Backend Configuration

**Environment Variable** (via LlmConfig):

```bash
# .env or production environment
OPENAI_API_KEY=sk-proj-...
```

**Configuration Access** (existing pattern):

```ruby
# config/configs/llm_config.rb
class LlmConfig < ApplicationConfig
  attr_config(
    :openai_api_key
  )
end

# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = LlmConfig.openai_api_key
  config.use_new_acts_as = true
end
```

**No New Configuration Needed**: Feature uses existing LlmConfig and RubyLLM setup.

**Deployment Considerations**:
- `OPENAI_API_KEY` must be set in production environment
- No database migrations needed (stateless feature)
- No new config files required

### 6.2 Extension Dependencies

**New npm Dependencies**:

```json
{
  "dependencies": {
    "@mozilla/readability": "^0.5.0",
    "ip-address": "^9.0.5"
  }
}
```

**Installation**:
```bash
cd extension
pnpm add @mozilla/readability ip-address
```

**Type Definitions**:
- `@mozilla/readability` includes TypeScript definitions
- `ip-address` includes TypeScript definitions
- No additional `@types/*` packages needed

---

## 7. Integration Architecture

### 7.1 Privacy Protection

**Defense in Depth Strategy**:

**Layer 1: Extension (UX + Privacy)**
- Client-side check before sending content
- Uses `ip-address` npm package
- Provides immediate feedback to user
- Prevents sensitive content from leaving browser

**Layer 2: Backend (Security Boundary)**
- Server-side validation using Addressable gem
- Enforces privacy policy at API boundary
- Logs blocked attempts for security monitoring
- Protects against malicious clients bypassing extension check

**Blocked URLs**:
- `localhost`, `127.0.0.1`, `::1`
- Private IPv4: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`
- Private IPv6: `fc00::/7`, `fe80::/10`
- Link-local addresses

**User Communication**:
- Extension shows: "Cannot analyze localhost or private URLs"
- Privacy notice in UI: "⚠️ Content sent to OpenAI"
- Manual trigger ensures user consent

### 7.2 Error Handling Strategy

**Extension Error Display**:
- Timeout: "Analysis timed out. Try again?"
- Generic: "Analysis failed. Please try again."
- Privacy: "Cannot analyze localhost or private URLs"
- Network: "Network error. Check connection."

**Backend Error Logging**:
```ruby
# Full exception context logged
Rails.logger.error "AI analysis failed: #{e.class} - #{e.message}"
Rails.logger.error e.backtrace.join("\n")
```

**Error Recovery**:
- User clicks "Analyze with AI" button again to retry
- No automatic retry (keeps UX simple)
- Manual link saving always available as fallback

**Non-Blocking Philosophy**:
- AI failure never prevents link saving
- User can always type tags and notes manually
- Feature enhances workflow but doesn't replace it

---

## 8. File Organization

### 8.1 Backend Files

**New Files**:
```
backend/
├── app/
│   ├── controllers/
│   │   └── api/
│   │       └── v1/
│   │           └── links_controller.rb          (add analyze action)
│   ├── services/
│   │   └── link_radar/
│   │       └── ai/
│   │           └── analyze_link_content.rb      (new service)
│   └── views/
│       └── api/
│           └── v1/
│               └── links/
│                   └── analyze.jbuilder    (new view)
└── spec/
    ├── requests/
    │   └── api/
    │       └── v1/
    │           └── links/
    │               └── analyze_spec.rb           (new test)
    └── services/
        └── link_radar/
            └── ai/
                └── analyze_link_content_spec.rb  (new test)
```

**Modified Files**:
```
backend/
└── config/
    └── routes.rb                                (add analyze route)
```

**Route Addition**:
```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :links do
      collection do
        get :by_url
        post :analyze    # NEW: AI analysis endpoint
      end
    end
  end
end
```

### 8.2 Extension Files

**New Files**:
```
extension/
├── lib/
│   ├── types/
│   │   └── ai-analysis.ts                       (new types)
│   ├── contentExtractor.ts                      (new utility)
│   ├── privacy.ts                               (new utility)
│   └── apiClient.ts                             (add analyzeLink function)
├── entrypoints/
│   └── popup/
│       ├── components/
│       │   ├── AiAnalyzeButton.vue              (new component)
│       │   ├── AiSuggestions.vue                (new component)
│       │   ├── SuggestedNote.vue                (new component)
│       │   ├── SuggestedTags.vue                (new component)
│       │   └── LinkForm.vue                     (modified)
│       └── composables/
│           └── useAiAnalysis.ts                 (new composable)
└── package.json                                 (add dependencies)
```

**Modified Files**:
```
extension/
├── lib/
│   ├── types/
│   │   └── index.ts                             (export new types)
│   └── apiClient.ts                             (add analyzeLink)
└── entrypoints/
    └── popup/
        └── components/
            └── LinkForm.vue                     (integrate AI components)
```

---

## 9. Quality Attributes

### 9.1 Performance

**Response Time Targets**:
- Typical AI analysis: 3-5 seconds
- Extension timeout: 15 seconds
- Backend timeout: Relies on extension timeout (no separate backend timeout)

**Performance Characteristics**:
- Stateless operation (no database queries except tag list)
- Single OpenAI API call per request
- Tag matching: O(n) where n = number of suggested tags (~7 max)
- No caching (acceptable for single-user MVP)

**Cost Considerations**:
- GPT-4o-mini: Cost-effective model for text analysis
- ~50K characters max: Keeps token usage reasonable
- User monitors costs via OpenAI dashboard
- No in-app cost tracking (single-user system)

### 9.2 Security

**Authentication**:
- Existing Bearer token authentication (API key)
- Same mechanism as all other API endpoints
- No special authentication needed

**Privacy Protection**:
- Defense in depth: Extension + backend validation
- No localhost/private IP analysis
- Manual trigger ensures user consent
- Privacy notice displayed in UI

**Data Handling**:
- No database persistence of analysis requests/responses
- No caching of page content
- OpenAI receives content (acknowledged in privacy notice)
- No PII scrubbing (user responsible for choosing what to analyze)

**Deferred Security Features** (acceptable for v1):
- No banking site detection
- No password field detection
- No sensitive query parameter scrubbing
- No per-user rate limiting

### 9.3 Reliability

**Error Handling**:
- All exceptions logged with full context
- User-friendly error messages
- Graceful degradation (manual workflow always available)
- No automatic retry (user controls retry)

**Fault Tolerance**:
- OpenAI API failures don't crash application
- Extension timeout prevents indefinite waiting
- Validation errors provide actionable feedback
- Network failures handled gracefully

**Availability**:
- Feature availability depends on OpenAI API uptime
- Manual link saving always available regardless of AI status
- No database dependencies (except existing Tag queries)

### 9.4 Maintainability

**Code Organization**:
- Service object pattern isolates AI logic
- Clear separation of concerns (validation, extraction, AI call, matching)
- Reusable components in extension
- Composable for state management

**Testing Strategy**:
- Backend: WebMock for OpenAI API stubbing
- Request specs for endpoint contract
- Service specs for business logic
- Extension: Manual testing only (no test framework)

**Documentation**:
- Inline comments explaining business logic
- Type definitions document contracts
- API documentation in this spec
- Error messages guide troubleshooting

**Future Extensibility**:
- Service object pattern makes it easy to add features
- Structured output schema can be extended
- Component architecture supports UI enhancements
- Configuration pattern supports new LLM providers

---

## Implementation Notes

**Development Sequence**:
1. Backend service layer (TDD with WebMock)
2. Backend controller and route
3. Backend jbuilder view and response contract
4. Extension types and utilities
5. Extension composable
6. Extension components
7. Integration testing

**Testing Approach**:
- Mock OpenAI API calls in tests (avoid hitting API)
- Test happy path and error scenarios
- Test tag matching logic thoroughly
- Test privacy validation
- Manual end-to-end testing with real content

**Deployment Checklist**:
- Verify `OPENAI_API_KEY` set in production
- Test privacy protection with real URLs
- Monitor OpenAI API costs after launch
- Verify extension content extraction on various sites
- Test error handling with network failures

---

**End of Technical Specification**

