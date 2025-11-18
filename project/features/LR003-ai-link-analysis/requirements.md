# LR003 - AI-Powered Link Analysis: Requirements

## Table of Contents

- [LR003 - AI-Powered Link Analysis: Requirements](#lr003---ai-powered-link-analysis-requirements)
  - [Table of Contents](#table-of-contents)
  - [1. User Stories \& Business Needs](#1-user-stories--business-needs)
    - [1.1 End User (Link Saver)](#11-end-user-link-saver)
  - [2. Core System Capabilities](#2-core-system-capabilities)
  - [3. Business Data Requirements](#3-business-data-requirements)
    - [3.1 Entities](#31-entities)
    - [3.2 Relationships](#32-relationships)
    - [3.3 Business-Level Attributes](#33-business-level-attributes)
  - [4. Business Rules \& Logic](#4-business-rules--logic)
    - [4.1 AI Analysis Rules](#41-ai-analysis-rules)
    - [4.2 Tag Management Rules](#42-tag-management-rules)
    - [4.3 Content Extraction Rules](#43-content-extraction-rules)
  - [5. User Experience Requirements](#5-user-experience-requirements)
    - [5.1 Extension UI](#51-extension-ui)
    - [5.2 Interaction Model](#52-interaction-model)
    - [5.3 Visual Design](#53-visual-design)
  - [6. Quality Attributes \& Constraints](#6-quality-attributes--constraints)
    - [6.1 Performance](#61-performance)
    - [6.2 Security \& Privacy](#62-security--privacy)
    - [6.3 Error Handling](#63-error-handling)
  - [7. Integration Touchpoints](#7-integration-touchpoints)
    - [7.1 Extension Integration](#71-extension-integration)
    - [7.2 Backend Integration](#72-backend-integration)
    - [7.3 Third-Party Services](#73-third-party-services)
  - [8. Development \& Testing Approach](#8-development--testing-approach)
  - [9. Success Criteria](#9-success-criteria)
  - [10. Constraints \& Assumptions](#10-constraints--assumptions)
  - [References](#references)

---

## 1. User Stories & Business Needs

### 1.1 End User (Link Saver)

**As a link saver, I want to:**

- Get intelligent tag suggestions when saving links so I don't have to manually remember and type tag names
- See which suggested tags already exist in my collection so I can maintain consistent categorization
- Receive contextual note suggestions that explain why content is worth saving without breaking my capture flow
- Control when AI analysis happens so I only use it when I want help
- Review and selectively accept AI suggestions so I maintain full control over my organization
- Combine AI suggestions with my own manual input for a hybrid approach
- Continue saving links manually when AI isn't needed or fails

**Business Capabilities Needed:**

- Analyze page content and suggest relevant tags based on what I already use
- Generate contextual notes that capture the essence of why content matters
- Present suggestions in a way that makes it easy to accept, reject, or modify them
- Preserve my existing manual workflow while enhancing it with AI assistance

---

## 2. Core System Capabilities

The system must provide:

1. **On-Demand Content Analysis** - User triggers analysis by clicking a button, system extracts page content and sends to backend for AI processing

2. **Intelligent Tag Suggestions** - AI suggests 3-7 relevant tags, preferring existing tags to maintain consistency while being liberal with creating new tags when needed

3. **Contextual Note Generation** - AI generates 1-2 sentence notes explaining why content is worth saving in a casual tone

4. **Existing Tag Recognition** - System queries user's existing tags and highlights which suggested tags already exist versus which are new

5. **Non-Destructive Suggestion Presentation** - Suggestions appear in separate UI section, allowing users to review and selectively accept without overwriting manual input

6. **Manual Control** - Analysis only happens when explicitly triggered by user, never automatically

7. **Graceful Degradation** - If AI analysis fails, user can still save links manually without disruption

8. **Content Privacy Protection** - Basic protections prevent analysis of localhost/private IP addresses

---

## 3. Business Data Requirements

### 3.1 Entities

**Analysis Request**
- Page content extracted from browser
- Page metadata (title, description, author)
- Target URL
- User context (existing tags)

**Analysis Response**
- Suggested note text
- List of suggested tags with existence indicators
- No persistent storage (ephemeral data only)

**Page Content**
- Main article text (Readability-extracted)
- Page title (from title tag or Open Graph)
- Meta description
- Author information (when available)
- URL for domain context

### 3.2 Relationships

- Analysis Request → User (one-to-one: each request belongs to authenticated user)
- Analysis Response → Suggested Tags (one-to-many: response contains multiple tag suggestions)
- Suggested Tags → Existing Tags (reference: indicates which suggestions match existing user tags)

### 3.3 Business-Level Attributes

**Analysis Request Attributes:**
- URL must be valid HTTP/HTTPS
- Content should be meaningful text (minimum viable length)
- User must be authenticated

**Suggested Tag Attributes:**
- Tag name in Title Case format (preferred) or lowercase
- Existence indicator (boolean: exists in user's collection or not)
- Order reflects AI's relevance ranking

**Suggested Note Attributes:**
- Casual, conversational tone
- Generally 1-2 sentences (guideline, not hard limit)
- Explains value or relevance of content

---

## 4. Business Rules & Logic

### 4.1 AI Analysis Rules

**Analysis Triggering:**
- Analysis must be manually triggered by user clicking "Analyze with AI" button
- Analysis only works when user has page open in browser (extension context)
- Analysis can be performed on any page before saving the link
- User can cancel in-progress analysis

**AI Context and Instructions:**
- AI receives page URL, extracted content, and metadata
- AI receives list of user's existing tag names (names only, no usage counts)
- AI is instructed to prefer existing tags when relevant but not force-fit tags that don't apply
- AI should be liberal with tags - capture nuances without artificial constraints
- AI should suggest tags based purely on content relevance, not popularity
- Tag format preference is Title Case, with lowercase acceptable
- Note tone should be casual if any tone is applied
- Suggested note length is 1-2 sentences (guideline)
- Suggested tag count is 3-7 (flexible based on content)

**Tag Matching Logic:**
- Case-insensitive matching to detect existing tags (JavaScript === javascript)
- Exact name matching only (no fuzzy matching or similarity detection in v1)
- AI should understand common abbreviations and synonyms to avoid suggesting duplicates (e.g., don't suggest "js" if "JavaScript" exists)

### 4.2 Tag Management Rules

**Tag Suggestion Presentation:**
- All suggested tags start unselected (outline style) - explicit opt-in approach
- Existing tags display in green, new tags display in blue
- Selected tags display with solid background, unselected with outline style
- Tags display in AI-suggested order (trust relevance ranking)

**Tag Acceptance and Merging:**
- User toggles individual tag chips ON to select them
- Selected tags automatically populate into main Tags input field in real-time
- User can also manually type tags directly into main field
- Main Tags field shows combined result (AI-selected + manually-entered)
- No visual distinction needed in main field between AI vs manual tags (all just "your tags")
- If AI suggests a tag user already typed (case-insensitive match), don't show duplicate in suggestions
- When link is saved, all tags from main field are submitted via existing link save flow
- Tag creation happens automatically at save time for any new tags

### 4.3 Content Extraction Rules

**Extension Extraction:**
- Use @mozilla/readability JavaScript library for main content extraction
- Extract title from: og:title meta tag first, fallback to title tag, fallback to first h1
- Extract description from: og:description meta tag first, fallback to meta description
- Extract author from: meta author tag or og:article:author when available
- Include full URL for domain context
- Send full Readability-extracted content (no character limit truncation)
- Clean excessive whitespace but preserve paragraph structure
- Only extract from HTML pages (skip PDFs, videos, etc.)

**Content Validation:**
- If content extraction fails, show error but still allow user to attempt analysis
- If page has minimal or no extractable text, let user try analysis anyway (AI will handle gracefully)
- Include URL even if content extraction is poor (provides domain context)

**Privacy Protections:**
- Block analysis of localhost URLs (localhost, 127.0.0.1)
- Block analysis of private IP addresses (192.168.x.x, 10.x.x.x, etc.)
- Use npm package for private IP detection (similar to backend's Addressable gem)
- Manual trigger ensures user controls when content is sent to OpenAI

---

## 5. User Experience Requirements

### 5.1 Extension UI

**Button Placement:**
- "✨ Analyze with AI" button appears between page info and "Add a note" section
- Button is prominent and discoverable immediately when popup opens
- Button positioned before the fields it helps fill (notes and tags)

**Button States:**
- Initial: Blue button displaying "✨ Analyze with AI"
- Analyzing: Button shows spinner + "Analyzing..." text (clickable to cancel)
- After analysis: Button remains visible, changes to "↻ Analyze Again" to allow regeneration
- Always clickable unless currently analyzing

**Suggestions Section:**
- "🤖 AI Suggestions" section appears below button, above note field
- Section only appears after successful analysis
- Contains suggested note with "[+ Add to Notes]" button
- Contains suggested tags as toggleable chips
- Includes privacy notice: "⚠️ Content sent to OpenAI"

### 5.2 Interaction Model

**Analysis Flow:**
1. User opens extension on page they want to save
2. User clicks "✨ Analyze with AI" button
3. Extension extracts content and sends to backend
4. Button changes to "Analyzing..." with spinner (3-5 second typical wait, 15s timeout)
5. User can click button again to cancel if desired
6. On success, suggestions appear in dedicated "🤖 AI Suggestions" section
7. User reviews tag chips (all start unselected/outline style) and suggested note
8. User toggles ON desired tags - they populate main Tags field in real-time
9. User can manually type additional tags directly in main field
10. User clicks "[+ Add to Notes]" to insert AI note (optional)
11. User can modify inserted note or leave as-is
12. User clicks "Save This Link" - all tags in main field are submitted

**Note Insertion:**
- Clicking "[+ Add to Notes]" button replaces current notes field content with AI suggestion
- User can then freely edit the inserted text
- This is an all-or-nothing insertion (no cursor-position insertion in v1)

**Tag Interaction:**
- All chips start in unselected state (outline style)
- Click chip once to select (changes to solid background, tag appears in main Tags field)
- Click again to deselect (changes back to outline, tag removed from main field)
- Four visual states communicate two attributes:
  - Green + Solid = Existing tag, selected (added to main field)
  - Green + Outline = Existing tag, unselected (not in main field)
  - Blue + Solid = New tag, selected (added to main field, will be created)
  - Blue + Outline = New tag, unselected (not in main field)
- Selection state syncs in real-time with main Tags field
- Main Tags field shows all tags (AI-selected + manual) without visual distinction

**Error Handling:**
- On error, show friendly message: "Analysis failed. Please try again."
- Distinguish timeout errors: "Analysis timed out. Try again?"
- User clicks "Analyze" again to retry (no automatic retry)
- User can always proceed with manual entry if analysis fails

### 5.3 Visual Design

**Tag Chip States:**
- Selected state: Solid background (green or blue), white text
- Unselected state: Light outline style with gray text
- Green color indicates existing tag
- Blue color indicates new tag
- Chips displayed in AI-suggested order (relevance ranking)

**Suggested Note Display:**
- Note text displayed in readable format
- Clear "[+ Add to Notes]" button to accept suggestion
- Note preserves AI's casual tone and formatting

---

## 6. Quality Attributes & Constraints

### 6.1 Performance

**Response Time:**
- Typical analysis completes in 3-5 seconds
- Extension enforces 15-second timeout
- No specific timeout on backend (relies on extension timeout)
- No need for progress indicators beyond basic spinner (single user, acceptable wait time)

**Simplicity:**
- Basic spinner animation sufficient for loading state
- No complex progress messages or percentage indicators
- Single-user system doesn't require performance optimization in v1

### 6.2 Security & Privacy

**Privacy Controls:**
- Analysis only triggered manually by user (explicit consent)
- Privacy notice displayed: "⚠️ Content sent to OpenAI"
- Block analysis of localhost URLs
- Block analysis of private IP addresses
- User awareness that page content is sent to third-party API

**Deferred Security Features:**
- No banking site detection (complex, requires site lists)
- No password field detection (complicated edge cases)
- No sensitive query parameter scrubbing (hard to define "sensitive")
- No per-user rate limiting (single user system)
- No special logging restrictions (user can review logs directly)

**Authentication:**
- Uses existing API token authentication system from extension
- Same authentication mechanism as current link saving functionality

### 6.3 Error Handling

**User-Facing Errors:**
- Show simple, friendly error messages
- Generic error: "Analysis failed. Please try again."
- Timeout error: "Analysis timed out. Try again?"
- Content extraction error: Show error but still allow analysis attempt
- No automatic retry - user clicks button again if desired

**Backend Logging:**
- Rails logs error details (exception type, message, stack trace)
- Logs available for investigation when needed
- No cost monitoring in application (user monitors via OpenAI dashboard)

**Error Philosophy:**
- Errors never block manual link saving workflow
- Graceful degradation - feature enhances workflow but doesn't replace it
- Simple error messages sufficient for single-user system

---

## 7. Integration Touchpoints

### 7.1 Extension Integration

**Existing Extension Capabilities:**
- Authentication system (API token) remains unchanged
- Tag input field works as before, accepts both manual and AI-suggested tags
- Notes field works as before, accepts both manual and AI-inserted text
- Link save flow remains unchanged - AI just helps pre-fill fields

**New Extension Dependencies:**
- @mozilla/readability for content extraction
- Private IP detection library (e.g., is-ip or ip-address npm package)
- HTTP client for calling new analyze endpoint

### 7.2 Backend Integration

**New Backend Endpoint:**
- `POST /api/v1/links/analyze` endpoint
- Accepts payload with pre-extracted content from extension:
  - `url` - Page URL
  - `content` - Main article text (Readability-extracted)
  - `title` - Page title (og:title, title tag, or h1)
  - `description` - Meta description (og:description or meta description)
  - `author` - Author info when available (optional)
- Returns `{suggested_note, suggested_tags: [{name, exists}]}` structure
- No link_id parameter needed (re-analysis deferred to future)

**Existing Backend Capabilities:**
- Tag model query for existing user tags (used for AI context)
- Authentication via API token (existing mechanism)
- Link save endpoint unchanged (handles both manual and AI-suggested tags)
- Tag creation at save time (existing behavior handles new AI-suggested tags)

**No Backend Content Extraction:**
- Backend does NOT fetch or extract page content
- Backend receives pre-extracted content from extension
- ContentExtractor code from archival feature not used for AI analysis

### 7.3 Third-Party Services

**RubyLLM Gem:**
- Required dependency: ruby_llm gem (~> 1.8)
- Provides unified API for calling OpenAI
- Handles API communication and response parsing
- May store tool call results (newer versions)

**OpenAI API:**
- Model: GPT-4o-mini (via RubyLLM)
- User monitors costs via OpenAI dashboard (no in-app cost tracking)
- API calls made from backend only (not directly from extension)

---

## 8. Development & Testing Approach

**Backend Testing:**
- Automated tests for analyze endpoint
- WebMock or VCR for mocking OpenAI API calls (avoid hitting API constantly)
- Basic smoke tests: endpoint returns results, error handling works, response format correct
- No quality testing of AI suggestions (subjective, manual verification)
- Test existing tag matching logic (case-insensitive detection)
- Test error scenarios (API failure, timeout, invalid input)

**Frontend Testing:**
- No testing framework in place for extension
- Manual testing only
- Test on real pages during development

**Integration Testing:**
- Manual end-to-end testing with real browser extension
- Test complete flow: click analyze → review suggestions → save link
- Verify tag merging behavior (AI + manual tags)
- Verify note insertion behavior

---

## 9. Success Criteria

**Primary Success Criterion:**
- AI returns decent suggestions that user accepts (some or most) more often than not
- Subjective evaluation by primary user (user will know it works when they see it)

**Functional Requirements Met:**
- Analysis completes successfully for typical web pages
- Existing tags correctly identified and marked as green
- New tags correctly identified and marked as blue
- Note suggestions are contextual and useful
- Tag suggestions are relevant to content
- User can toggle tags on/off before saving
- Both AI and manual input merge correctly on save
- Errors handled gracefully without breaking save workflow

**Quality Indicators:**
- User chooses to use AI analysis on most links (indicates value)
- User accepts at least some suggestions most of the time (indicates relevance)
- Tag consistency improves over time (fewer duplicates/variations)
- Capture flow feels faster and less like a chore

---

## 10. Constraints & Assumptions

**Scope Constraints:**
- v1 targets extension context only (web frontend deferred)
- Single user system (no multi-user concerns)
- Manual trigger only (auto-analyze deferred)
- HTML pages only (PDF/video support deferred)
- OpenAI only via RubyLLM (no multi-model support)
- No re-analysis feature (analyze when page is open in browser)

**Technical Requirements:**
- Backend: Ruby on Rails with RubyLLM gem
- Extension: Vue.js (existing stack)
- Content extraction: @mozilla/readability (browser-side)
- Private IP detection: npm package (similar to backend's Addressable)
- Authentication: Existing API token system
- No new infrastructure needed

**Assumptions:**
- User has OpenAI API key configured in backend
- User monitors API costs via OpenAI dashboard
- User has existing tags to leverage for suggestions
- Page content is primarily English (GPT-4 is multilingual but not optimized)
- Browser extensions have sufficient permissions for DOM access
- User understands privacy implications of sending content to OpenAI

**Known Limitations (Acceptable for v1):**
- Extension-extracted content sent to OpenAI (privacy implication)
- Not optimized for non-English content
- No advanced content extraction (no headless browser)
- No sensitive content detection
- No learning from user patterns (AI doesn't adapt over time)
- No confidence scoring on suggestions
- No bulk/batch analysis
- No result caching (pages change, simplicity prioritized)

**Future Expansion:**
See [future.md](future.md) for deferred features and enhancement opportunities.

---

## References

- [Vision Document](vision.md) - Business context and feature overview
- [Future Enhancements](future.md) - Deferred features for Phase 2+

