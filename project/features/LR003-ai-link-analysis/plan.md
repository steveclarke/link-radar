# LR003 - AI-Powered Link Analysis - Implementation Plan

## Overview

This plan implements AI-powered tag and note suggestions for LinkRadar as a standalone feature, independent of content archival. The user can click a button in the extension to analyze any link (new or existing), and AI provides suggestions in a separate, non-destructive UI area.

## Timeline Estimate

**Total: 2-3 days**

- Phase 1: Backend AI Endpoint (1 day)
- Phase 2: Extension UI Enhancement (1 day)
- Phase 3: Prompt Engineering & Polish (0.5-1 day)

## Key Architectural Decisions

### 1. Analysis Separate from Save

- Analysis is a separate action (doesn't trigger save)
- Save doesn't trigger analysis  
- User can analyze before save, after save, or not at all
- Re-analysis supported anytime

### 2. Backend Fetches Content

- Extension sends URL (or link_id) to backend
- Backend fetches page content on-demand
- No content scraping in extension
- No content storage during analysis (that's a separate feature)

### 3. Non-Destructive UI

- Suggestions shown in separate "🤖 AI Suggestions" section
- AI never overwrites user's typed content
- User selects which suggestions to accept
- Manual input + AI suggestions can be combined

### 4. Works for New OR Existing Links

- New links: Analyze before saving
- Existing links: Re-analyze anytime
- Backend re-fetches content for fresh analysis

---

## Phase 1: Backend AI Endpoint (1 day)

### Goal

Create a Rails API endpoint that accepts a URL or link ID, fetches content, analyzes with OpenAI, and returns structured suggestions.

### Tasks

#### 1.1 Create Analysis Endpoint

**File:** `app/controllers/api/v1/links_controller.rb`

Add new action:

```ruby
# POST /api/v1/links/analyze
def analyze
  url = params[:url]
  link_id = params[:link_id]
  
  # Validate: must have url OR link_id
  if url.blank? && link_id.blank?
    render json: { error: 'Must provide url or link_id' }, status: :bad_request
    return
  end
  
  # If link_id provided, re-analyze existing link
  if link_id.present?
    link = Link.find_by(id: link_id)
    unless link
      render json: { error: 'Link not found' }, status: :not_found
      return
    end
    url = link.url
  end
  
  # Analyze the URL
  result = LinkAnalysisService.analyze(url: url, user: current_user)
  
  if result[:error]
    render json: { error: result[:error] }, status: :unprocessable_entity
  else
    render json: {
      suggested_note: result[:note],
      suggested_tags: result[:tags]
    }
  end
rescue Timeout::Error
  render json: { error: 'Analysis timed out' }, status: :gateway_timeout
rescue => e
  Rails.logger.error "Analysis failed: #{e.message}"
  render json: { error: 'Analysis failed' }, status: :internal_server_error
end
```

**Route:** `config/routes.rb`

```ruby
namespace :api do
  namespace :v1 do
    resources :links do
      collection do
        post :analyze
      end
    end
  end
end
```

#### 1.2 Create LinkAnalysisService

**File:** `app/services/link_analysis_service.rb`

```ruby
class LinkAnalysisService
  TIMEOUT = 15.seconds
  CONTENT_LIMIT = 2000 # characters
  
  def self.analyze(url:, user:)
    new(url: url, user: user).analyze
  end
  
  def initialize(url:, user:)
    @url = url
    @user = user
  end
  
  def analyze
    # Fetch page content
    content_data = fetch_content(@url)
    return { error: 'Unable to fetch content' } if content_data[:error]
    
    # Get user's existing tags (case-insensitive, normalized)
    existing_tags = @user.tags.pluck(:name).map(&:downcase).uniq
    
    # Build prompt and call AI
    prompt = build_prompt(content_data, existing_tags)
    ai_response = call_ai(prompt)
    
    return { error: 'AI analysis failed' } if ai_response[:error]
    
    # Parse and structure response
    parse_ai_response(ai_response[:text], existing_tags)
  rescue Timeout::Error
    { error: 'Request timed out' }
  rescue => e
    Rails.logger.error "LinkAnalysisService error: #{e.message}"
    { error: 'Analysis failed' }
  end
  
  private
  
  def fetch_content(url)
    # Use Faraday to fetch page
    response = Faraday.get(url) do |req|
      req.options.timeout = 5
      req.headers['User-Agent'] = 'LinkRadar/1.0'
    end
    
    if response.success?
      html = Nokogiri::HTML(response.body)
      
      # Extract metadata
      title = html.at_css('title')&.text&.strip || 
              html.at_css('meta[property="og:title"]')&.[]('content') || 
              url
      
      meta_desc = html.at_css('meta[name="description"]')&.[]('content') ||
                  html.at_css('meta[property="og:description"]')&.[]('content')
      
      # Extract text content (simple extraction)
      text = html.css('p').map(&:text).join("\n").strip
      text = text[0..CONTENT_LIMIT] if text.length > CONTENT_LIMIT
      
      {
        title: title,
        description: meta_desc,
        text: text
      }
    else
      { error: "HTTP #{response.status}" }
    end
  rescue => e
    Rails.logger.error "Content fetch error: #{e.message}"
    { error: e.message }
  end
  
  def build_prompt(content_data, existing_tags)
    system_prompt = <<~PROMPT
      You are an intelligent tagging assistant for a personal knowledge management system.
      Your job is to analyze web page content and suggest relevant tags and a brief note.
      
      Rules:
      1. Suggest 3-7 most relevant tags
      2. Prefer existing user tags when applicable (case-insensitive matching)
      3. Only suggest new tags if existing ones don't fit
      4. Write a concise 1-2 sentence note explaining why this content is worth saving
      5. Return response as JSON: { "tags": ["tag1", "tag2"], "note": "..." }
    PROMPT
    
    existing_tags_text = existing_tags.any? ? existing_tags.join(', ') : 'none yet'
    
    user_prompt = <<~PROMPT
      Analyze this content and suggest tags and a note.
      
      Existing tags (prefer these): #{existing_tags_text}
      
      Content:
      Title: #{content_data[:title]}
      Description: #{content_data[:description]}
      
      #{content_data[:text]}
      
      Return JSON with "tags" array and "note" string.
    PROMPT
    
    { system: system_prompt, user: user_prompt }
  end
  
  def call_ai(prompt)
    Timeout.timeout(TIMEOUT) do
      response = RubyLLM.chat(
        messages: [
          { role: 'system', content: prompt[:system] },
          { role: 'user', content: prompt[:user] }
        ],
        model: 'gpt-4o-mini',
        response_format: { type: 'json_object' }
      )
      
      { text: response }
    end
  rescue => e
    Rails.logger.error "AI call error: #{e.message}"
    { error: e.message }
  end
  
  def parse_ai_response(response_text, existing_tags)
    parsed = JSON.parse(response_text)
    suggested_tags = parsed['tags'] || []
    note = parsed['note'] || ''
    
    # Mark which tags exist
    tags_with_existence = suggested_tags.map do |tag|
      exists = existing_tags.include?(tag.downcase)
      { name: tag, exists: exists }
    end
    
    {
      note: note,
      tags: tags_with_existence
    }
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse AI response: #{e.message}"
    { error: 'Failed to parse AI response' }
  end
end
```

#### 1.3 Add Required Gems

**File:** `Gemfile`

```ruby
# Already have RubyLLM, but ensure Faraday and Nokogiri
gem 'faraday'
gem 'nokogiri'
```

Run: `bundle install`

#### 1.4 Test the Endpoint

Use Bruno or curl to test:

```bash
# Test with URL
curl -X POST http://localhost:3000/api/v1/links/analyze \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise"}'

# Expected response:
# {
#   "suggested_note": "Documentation on JavaScript Promises for handling async operations...",
#   "suggested_tags": [
#     {"name": "JavaScript", "exists": true},
#     {"name": "async", "exists": false},
#     {"name": "promises", "exists": false}
#   ]
# }
```

#### 1.5 Add Logging for Cost Monitoring

**File:** `app/services/link_analysis_service.rb`

Add to `call_ai` method:

```ruby
def call_ai(prompt)
  start_time = Time.current
  
  Timeout.timeout(TIMEOUT) do
    response = RubyLLM.chat(...)
    
    # Log for cost monitoring
    Rails.logger.info({
      event: 'ai_analysis',
      user_id: @user.id,
      url: @url,
      duration_ms: ((Time.current - start_time) * 1000).round,
      model: 'gpt-4o-mini'
    }.to_json)
    
    { text: response }
  end
rescue => e
  Rails.logger.error "AI call error: #{e.message}"
  { error: e.message }
end
```

### Phase 1 Deliverables

- [ ] `POST /api/v1/links/analyze` endpoint working
- [ ] Accepts `{url}` or `{link_id}`
- [ ] Fetches page content on-demand
- [ ] Queries user's existing tags
- [ ] Calls OpenAI via RubyLLM
- [ ] Returns structured JSON with suggestions
- [ ] Error handling (timeouts, fetch failures, AI errors)
- [ ] Logging for cost monitoring
- [ ] Tested with real URLs

---

## Phase 2: Extension UI Enhancement (1 day)

### Goal

Add AI analysis button and suggestions UI to the browser extension popup, allowing users to request analysis and selectively accept suggestions.

### Tasks

#### 2.1 Update API Client

**File:** `extension/lib/apiClient.ts`

Add types and functions:

```typescript
export interface SuggestedTag {
  name: string
  exists: boolean // true = existing tag, false = new suggestion
}

export interface AnalyzeLinkResponse {
  suggested_note: string
  suggested_tags: SuggestedTag[]
}

/**
 * Analyze a URL and get AI-powered tag and note suggestions.
 * Content is fetched by the backend, not sent from extension.
 */
export async function analyzeLink(url: string): Promise<AnalyzeLinkResponse> {
  const response = await fetch(`${API_BASE}/api/v1/links/analyze`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${await getApiToken()}`
    },
    body: JSON.stringify({ url })
  })
  
  if (!response.ok) {
    const error = await response.json()
    throw new Error(error.error || 'Analysis failed')
  }
  
  return response.json()
}

/**
 * Re-analyze an existing link by ID.
 */
export async function analyzeLinkById(linkId: string): Promise<AnalyzeLinkResponse> {
  const response = await fetch(`${API_BASE}/api/v1/links/analyze`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${await getApiToken()}`
    },
    body: JSON.stringify({ link_id: linkId })
  })
  
  if (!response.ok) {
    const error = await response.json()
    throw new Error(error.error || 'Analysis failed')
  }
  
  return response.json()
}
```

#### 2.2 Add Analysis State Management

**File:** `extension/entrypoints/popup/App.vue` (or create new composable)

Add state for AI suggestions:

```typescript
const aiSuggestions = ref<AnalyzeLinkResponse | null>(null)
const isAnalyzing = ref(false)
const analysisError = ref<string | null>(null)

// Selected suggestions (user toggles these)
const selectedTagSuggestions = ref<Set<string>>(new Set())
const includeNoteSuggestion = ref(false)

async function handleAnalyze() {
  isAnalyzing.value = true
  analysisError.value = null
  aiSuggestions.value = null
  selectedTagSuggestions.value.clear()
  includeNoteSuggestion.value = false
  
  try {
    const currentUrl = getCurrentTabUrl() // existing function
    const response = await analyzeLink(currentUrl)
    aiSuggestions.value = response
    
    // Pre-select all tags by default (user can uncheck)
    response.suggested_tags.forEach(tag => {
      selectedTagSuggestions.value.add(tag.name)
    })
  } catch (error) {
    analysisError.value = error.message || 'Analysis failed'
  } finally {
    isAnalyzing.value = false
  }
}

function toggleTagSelection(tagName: string) {
  if (selectedTagSuggestions.value.has(tagName)) {
    selectedTagSuggestions.value.delete(tagName)
  } else {
    selectedTagSuggestions.value.add(tagName)
  }
}

function addNoteToUserNotes() {
  if (aiSuggestions.value?.suggested_note) {
    // Append to user's notes field
    const currentNotes = userNotes.value // existing ref
    if (currentNotes) {
      userNotes.value = `${currentNotes}\n\n${aiSuggestions.value.suggested_note}`
    } else {
      userNotes.value = aiSuggestions.value.suggested_note
    }
  }
}
```

#### 2.3 Update Popup UI

**File:** `extension/entrypoints/popup/App.vue`

Add AI analysis section to template:

```vue
<template>
  <div class="linkradar-popup">
    <!-- Existing URL and title display -->
    <div class="url-section">
      <input v-model="url" readonly />
      <input v-model="title" />
    </div>
    
    <!-- AI Analyze Button -->
    <button 
      @click="handleAnalyze" 
      :disabled="isAnalyzing"
      class="analyze-button"
    >
      <span v-if="!isAnalyzing">✨ Analyze with AI</span>
      <span v-else>
        <LoadingSpinner /> Analyzing...
      </span>
    </button>
    
    <!-- User Input Section -->
    <div class="user-input-section">
      <label>📝 Your Notes:</label>
      <textarea 
        v-model="userNotes" 
        placeholder="Add your own notes..."
      />
      
      <label>🏷️ Your Tags:</label>
      <div class="tags-input">
        <!-- Existing tag input component -->
        <TagInput v-model="userTags" />
      </div>
    </div>
    
    <!-- AI Suggestions Section (shown after analysis) -->
    <div v-if="aiSuggestions" class="ai-suggestions-section">
      <h3>🤖 AI Suggestions</h3>
      
      <!-- Suggested Note -->
      <div class="suggested-note">
        <label>Suggested Note:</label>
        <div class="note-box">
          {{ aiSuggestions.suggested_note }}
        </div>
        <button @click="addNoteToUserNotes" class="add-note-btn">
          + Add to Notes
        </button>
      </div>
      
      <!-- Suggested Tags -->
      <div class="suggested-tags">
        <label>Suggested Tags:</label>
        <div class="tag-chips">
          <button
            v-for="tag in aiSuggestions.suggested_tags"
            :key="tag.name"
            @click="toggleTagSelection(tag.name)"
            :class="[
              'tag-chip',
              tag.exists ? 'existing-tag' : 'new-tag',
              selectedTagSuggestions.has(tag.name) ? 'selected' : ''
            ]"
          >
            {{ tag.name }}
            <span v-if="selectedTagSuggestions.has(tag.name)">✓</span>
          </button>
        </div>
        <p class="tag-hint">
          Click tags to select/deselect. Green = existing, Blue = new.
        </p>
      </div>
      
      <p class="privacy-notice">⚠️ Content sent to OpenAI</p>
    </div>
    
    <!-- Error Display -->
    <div v-if="analysisError" class="error-message">
      {{ analysisError }}
    </div>
    
    <!-- Save Button -->
    <button @click="handleSave" class="save-button">
      Save
    </button>
  </div>
</template>
```

#### 2.4 Update Save Logic

Modify save function to include selected AI suggestions:

```typescript
async function handleSave() {
  // Combine user's manual tags with selected AI tag suggestions
  const allTags = [
    ...userTags.value, // user's manually entered tags
    ...Array.from(selectedTagSuggestions.value) // selected AI tags
  ]
  
  // Remove duplicates (case-insensitive)
  const uniqueTags = [...new Set(allTags.map(t => t.toLowerCase()))]
  
  await saveLink({
    url: url.value,
    title: title.value,
    notes: userNotes.value,
    tags: uniqueTags
  })
  
  // Clear state
  aiSuggestions.value = null
  selectedTagSuggestions.value.clear()
  
  // Show success, close popup, etc.
}
```

#### 2.5 Add Styles

**File:** `extension/entrypoints/popup/App.vue` (style section)

```css
.analyze-button {
  width: 100%;
  padding: 12px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  margin-bottom: 16px;
  transition: opacity 0.2s;
}

.analyze-button:hover:not(:disabled) {
  opacity: 0.9;
}

.analyze-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.ai-suggestions-section {
  background: #f8f9fa;
  border: 1px solid #e9ecef;
  border-radius: 8px;
  padding: 16px;
  margin-top: 16px;
}

.ai-suggestions-section h3 {
  margin: 0 0 12px 0;
  font-size: 14px;
  font-weight: 600;
  color: #495057;
}

.suggested-note {
  margin-bottom: 16px;
}

.note-box {
  background: white;
  border: 1px solid #dee2e6;
  border-radius: 4px;
  padding: 12px;
  font-size: 13px;
  color: #495057;
  margin-bottom: 8px;
  line-height: 1.5;
}

.add-note-btn {
  background: #28a745;
  color: white;
  border: none;
  border-radius: 4px;
  padding: 6px 12px;
  font-size: 12px;
  cursor: pointer;
}

.suggested-tags {
  margin-bottom: 12px;
}

.tag-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 8px;
}

.tag-chip {
  padding: 6px 12px;
  border-radius: 16px;
  border: 2px solid;
  background: white;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 4px;
}

.tag-chip.existing-tag {
  border-color: #28a745;
  color: #28a745;
}

.tag-chip.new-tag {
  border-color: #007bff;
  color: #007bff;
}

.tag-chip.selected {
  font-weight: 600;
}

.tag-chip.selected.existing-tag {
  background: #28a745;
  color: white;
}

.tag-chip.selected.new-tag {
  background: #007bff;
  color: white;
}

.tag-hint {
  font-size: 11px;
  color: #6c757d;
  margin: 0;
}

.privacy-notice {
  font-size: 11px;
  color: #6c757d;
  margin: 12px 0 0 0;
  text-align: center;
}

.error-message {
  background: #f8d7da;
  border: 1px solid #f5c6cb;
  color: #721c24;
  padding: 12px;
  border-radius: 4px;
  font-size: 13px;
  margin-top: 12px;
}
```

#### 2.6 Add Loading Spinner Component

**File:** `extension/lib/components/LoadingSpinner.vue`

```vue
<template>
  <span class="spinner"></span>
</template>

<style scoped>
.spinner {
  display: inline-block;
  width: 14px;
  height: 14px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>
```

#### 2.7 Add Timeout and Cancellation

Add abort controller for cancellable requests:

```typescript
let analysisAbortController: AbortController | null = null

async function handleAnalyze() {
  // Cancel any in-flight request
  if (analysisAbortController) {
    analysisAbortController.abort()
  }
  
  analysisAbortController = new AbortController()
  isAnalyzing.value = true
  analysisError.value = null
  
  try {
    const currentUrl = getCurrentTabUrl()
    const response = await analyzeLink(currentUrl, {
      signal: analysisAbortController.signal,
      timeout: 15000 // 15 seconds
    })
    aiSuggestions.value = response
  } catch (error) {
    if (error.name === 'AbortError') {
      analysisError.value = 'Analysis cancelled'
    } else {
      analysisError.value = error.message || 'Analysis failed'
    }
  } finally {
    isAnalyzing.value = false
    analysisAbortController = null
  }
}

function cancelAnalysis() {
  if (analysisAbortController) {
    analysisAbortController.abort()
  }
}
```

Update UI to show cancel button:

```vue
<button 
  v-if="isAnalyzing" 
  @click="cancelAnalysis"
  class="cancel-btn"
>
  ✕ Cancel
</button>
```

### Phase 2 Deliverables

- [ ] `analyzeLink()` function in apiClient.ts
- [ ] "✨ Analyze with AI" button in popup
- [ ] Loading state with spinner
- [ ] Cancellable analysis (X button, 15s timeout)
- [ ] "🤖 AI Suggestions" section displays after analysis
- [ ] Suggested note with "[+ Add to Notes]" button
- [ ] Suggested tags as toggleable chips (green=existing, blue=new)
- [ ] Privacy notice displayed
- [ ] Selected suggestions merge with user input on save
- [ ] Error handling with user-friendly messages
- [ ] Works for both new and existing links

---

## Phase 3: Prompt Engineering & Polish (0.5-1 day)

### Goal

Optimize the AI prompts for high-quality suggestions and polish the user experience.

### Tasks

#### 3.1 Test with Real Articles

Test analysis with variety of content types:

- Technical blog posts (dev.to, Medium)
- Documentation (MDN, Rails Guides)
- News articles (Hacker News links)
- GitHub repositories
- Research papers (arXiv)

Collect examples of:
- Good suggestions (relevant, useful)
- Bad suggestions (generic, irrelevant)
- Edge cases (very short content, non-English, etc.)

#### 3.2 Refine Prompts

Iterate on the system prompt based on testing:

```ruby
system_prompt = <<~PROMPT
  You are an intelligent tagging assistant for a personal knowledge management system.
  
  Your job is to analyze web page content and suggest:
  1. Relevant tags (3-7 tags)
  2. A brief note (1-2 sentences) explaining why this content is worth saving
  
  IMPORTANT RULES:
  - Prefer user's existing tags when applicable (case-insensitive matching)
  - Only suggest new tags if existing ones don't adequately describe the content
  - Tags should be:
    * Specific and descriptive (not too generic)
    * Consistent with user's existing vocabulary
    * Lowercase for new tags
  - Note should:
    * Be concise (1-2 sentences max)
    * Explain what the content covers and why it's useful
    * Use natural, friendly language
  
  Return ONLY valid JSON: { "tags": ["tag1", "tag2"], "note": "..." }
PROMPT
```

Test and refine:
- Tag quality (too generic? too specific?)
- Note quality (too long? not useful?)
- Existing tag reuse (is it matching well?)
- Edge case handling

#### 3.3 Tune Content Extraction

Experiment with content limits:

```ruby
# Current: 2000 characters
# Test: Does 1000 work just as well? (saves cost)
# Test: Does 3000 provide better results?

# Also test: 
# - Including more metadata (keywords, author, publish date)?
# - Extracting from specific elements (<article>, <main>)?
# - Cleaning text better (remove code blocks, navigation)?
```

Find the sweet spot between:
- Cost (fewer chars = cheaper)
- Quality (more context = better suggestions)

#### 3.4 Handle Edge Cases

Test and handle:

**Empty or minimal content:**
```ruby
if content_data[:text].blank? || content_data[:text].length < 100
  # Fall back to just title and description
  # Or return fewer tags
end
```

**Non-English content:**
- Current decision: Do nothing special (GPT-4 handles multiple languages)
- Test with non-English pages to verify
- Update docs if needed

**Fetch failures:**
```ruby
# Already handled, but improve error messages:
- "Unable to fetch content (timeout)"
- "Unable to fetch content (not found)"
- "Unable to fetch content (access denied)"
```

**Malformed AI responses:**
```ruby
# Improve parsing to handle:
- Missing fields
- Extra fields
- Non-array tags
- Empty responses
```

#### 3.5 Add Usage Documentation

**File:** `project/features/LR003-ai-link-analysis/usage.md`

Document:
- How to use the feature
- What to expect (typical response time, quality)
- Limitations (auth-walled content, non-English)
- Privacy (content sent to OpenAI)
- Cost estimates
- Troubleshooting common issues

#### 3.6 Final Polish

UI polish:
- [ ] Smooth transitions/animations
- [ ] Clear visual hierarchy
- [ ] Responsive to different popup sizes
- [ ] Keyboard shortcuts (Enter to analyze?)
- [ ] Focus management

Error message improvements:
- [ ] "AI analysis timed out. Try again or save manually."
- [ ] "Unable to analyze this page. You can still save it manually."
- [ ] "Analysis unavailable right now. Please try again later."

Performance:
- [ ] Optimize re-renders
- [ ] Debounce button clicks
- [ ] Cancel in-flight requests properly

#### 3.7 Create Demo Video/GIF

Record screencast showing:
1. Open extension on article
2. Click "Analyze with AI"
3. Wait 3 seconds
4. Review suggestions
5. Toggle tags, add note
6. Save

Use for documentation and demos.

### Phase 3 Deliverables

- [ ] Prompts tested and refined with real content
- [ ] Content extraction tuned for quality and cost
- [ ] Edge cases handled gracefully
- [ ] Usage documentation written
- [ ] UI polished and responsive
- [ ] Error messages user-friendly
- [ ] Demo video/GIF created

---

## Testing Checklist

### Backend Testing

- [ ] Analyze new URL works
- [ ] Analyze existing link (by ID) works
- [ ] Case-insensitive tag matching works
- [ ] Handles timeout gracefully
- [ ] Handles fetch failures gracefully
- [ ] Handles AI failures gracefully
- [ ] Returns correct JSON structure
- [ ] Logs analysis events
- [ ] Works with auth-required endpoints (fails gracefully)
- [ ] Handles very long content
- [ ] Handles minimal content
- [ ] Handles non-HTML content (JSON API response, etc.)

### Frontend Testing

- [ ] Button triggers analysis
- [ ] Loading state shows spinner
- [ ] Can cancel in-flight request
- [ ] Suggestions appear after analysis
- [ ] Tags are toggleable
- [ ] Existing tags show in green
- [ ] New tags show in blue
- [ ] Note can be added to user's notes
- [ ] Selected tags merge with manual tags on save
- [ ] Duplicate tags are removed on save
- [ ] Error messages display clearly
- [ ] Works for new links (before save)
- [ ] Works for existing links (re-analysis)
- [ ] Privacy notice is visible
- [ ] Handles analysis errors gracefully

### Integration Testing

- [ ] End-to-end: Analyze → Select → Save → Verify in backend
- [ ] Multiple analyses in a row work
- [ ] Analysis + manual tags + manual notes all save together
- [ ] Re-analysis updates suggestions
- [ ] Cost logging appears in Rails logs

---

## Rollout Plan

### Development

1. Implement Phase 1 (backend)
2. Test backend with Bruno/curl
3. Implement Phase 2 (extension UI)
4. Test extension locally
5. Implement Phase 3 (polish)

### Deployment

1. Deploy backend changes to production
2. Verify backend endpoint works in production
3. Build extension with production API URL
4. Load unpacked extension for testing
5. Test on real articles in production
6. Create extension build for distribution

### Monitoring

- Watch Rails logs for analysis events
- Monitor OpenAI API usage in OpenAI dashboard
- Track error rates
- Collect user feedback (just yourself initially)

---

## Success Metrics

### Qualitative

- Do AI suggestions feel helpful?
- Are suggested tags relevant?
- Are notes useful and concise?
- Does existing tag reuse work well?
- Is the UI intuitive and responsive?

### Quantitative

- Analysis success rate (% of requests that succeed)
- Average response time (target: 3-5 seconds)
- Tag reuse rate (% of suggestions using existing tags)
- Cost per analysis (target: ~$0.0004)
- User acceptance rate (% of suggestions accepted)

---

## Future Enhancements (Not in LR003)

### Phase 2 Features (Later)

- **Content Archival Integration**: Use stored content instead of re-fetching
- **Auto-analyze Mode**: Automatically trigger analysis on popup open
- **Learning System**: Track accepted/rejected suggestions, improve over time
- **Batch Analysis**: Analyze multiple links at once
- **Confidence Scoring**: Show which suggestions AI is more confident about
- **Tag Hierarchy Support**: Suggest nested tags (JavaScript > Async > Promises)
- **Smart Tag Synonyms**: Merge similar tags (js/javascript, ML/machine-learning)

### Phase 3 Features (Even Later)

- **Multiple AI Models**: Let user choose OpenAI vs Claude vs local
- **Custom Prompts**: User-defined prompt templates
- **Suggestion History**: Track and review past suggestions per link
- **A/B Testing**: Test different prompts automatically
- **Feedback Loop**: "This suggestion was good/bad" to improve prompts

---

## Dependencies

- ✅ RubyLLM gem installed and configured
- ✅ OpenAI API key configured
- ✅ Links and Tags models exist in backend
- ✅ Extension popup UI exists
- ✅ API authentication working
- ⚠️ Need: Faraday gem (for HTTP requests)
- ⚠️ Need: Nokogiri gem (for HTML parsing)

---

## Related Documentation

- [Vision Document](vision.md) - Problem, solution, and design decisions
- [README](README.md) - Feature overview and quick links
- [LinkRadar Tech Stack](../../notes/tech-stack-proposal.md) - Overall architecture
- [RubyLLM Documentation](https://rubyllm.com/) - AI integration library

---

## Questions/Decisions Log

### Q: Should we cache analysis results?
**Decision:** No caching in MVP. Pages change, and we want fresh analysis. Can add later if needed.

### Q: Should we store content during analysis?
**Decision:** No. Content archival is a separate feature with separate timeline. This keeps analysis independent.

### Q: Should AI auto-fill form fields?
**Decision:** No. Show suggestions in separate area, user selects what to use. Non-destructive approach.

### Q: Should we limit analyses per day?
**Decision:** No rate limiting for single-user MVP. Monitor usage, add limits if needed later.

### Q: Which AI model?
**Decision:** GPT-4o-mini. Fast (~2-4s), cheap (~$0.0004), good quality.

### Q: Should we handle non-English content?
**Decision:** Do nothing special. GPT-4 is multilingual. Test and document behavior.

### Q: Should we support re-analysis?
**Decision:** Yes. Accept URL or link_id, so users can re-analyze existing links anytime.

---

**Last Updated:** January 2025  
**Status:** Ready for Implementation
