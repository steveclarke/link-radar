# LR003 - AI-Powered Link Analysis

## Vision

Transform link capture from a manual categorization chore into an intelligent, assisted experience. When users save links, they can request AI analysis that suggests relevant tags and notes based on the page content. Suggestions are presented separately for user review - they can accept, reject, or modify any suggestions before saving.

This feature delivers on the LinkRadar vision's promise: "Make dumping links as easy as breathing, but provide powerful organization for those who want it."

## Problem Statement

Currently, when users save links, they face several pain points:

1. **Manual Tag Entry** - Users must remember and type tag names manually, creating friction when they want to organize
2. **Tag Discovery Gap** - Users don't know what tags already exist, leading to duplicates and inconsistency (e.g., "javascript" vs "JavaScript" vs "JS")
3. **Context Loss** - The effort to write meaningful notes breaks flow, so users skip notes entirely
4. **Inconsistent Organization** - Manual tagging leads to inconsistent categorization over time
5. **Time Cost** - Thoughtful organization takes time, so users choose between fast capture OR good organization

These issues create two failure modes:
- **Fast but messy**: Users skip tags/notes to save time, losing organization benefits
- **Slow but organized**: Users spend cognitive effort on categorization, making capture feel like a chore

## Solution

Add an **"Analyze with AI"** feature to the browser extension that provides intelligent tag and note suggestions in a separate, non-destructive UI area.

### Key Principles

1. **Manual Trigger** - User clicks "✨ Analyze with AI" button when they want suggestions
2. **Separate Presentation** - AI suggestions shown in dedicated area, never overwriting user input
3. **Selective Acceptance** - User picks which suggestions to use (tags are checkboxes, note has "Add" button)
4. **Works Anywhere** - Analysis works for new links (before save) or existing links (re-analysis)
5. **Backend-Powered** - Extension sends URL to backend, backend fetches and analyzes content

### User Experience Flow

**For New Links (not yet saved):**
1. User clicks extension icon on interesting article
2. Sees URL and title (not saved yet)
3. Clicks "✨ Analyze with AI" button
4. Extension sends URL to `/api/v1/links/analyze`
5. Backend fetches page content, analyzes with OpenAI
6. _(3-5 seconds: "Analyzing..." with spinner, cancellable)_
7. Suggestions appear in separate "🤖 AI Suggestions" section:
   - **Suggested Note** in box with "[+ Add to Notes]" button
   - **Suggested Tags** as toggleable chips (existing tags green, new tags blue)
8. User reviews:
   - Can type their own notes in main note field
   - Can add their own tags manually
   - Can click to accept AI note (appends to their notes)
   - Can click tags to toggle selection
9. User clicks Save
10. Selected AI tags + user's manual tags all get saved together

**For Existing Links (re-analysis):**
1. User opens extension on previously saved link
2. Form loads with existing notes and tags
3. User clicks "✨ Analyze with AI"
4. Backend uses stored content if available, or re-fetches
5. New suggestions appear
6. User can add/update based on fresh AI analysis

### UI Layout

```
┌─────────────────────────────────────┐
│  LinkRadar                          │
├─────────────────────────────────────┤
│  URL: https://example.com/article   │
│                                     │
│  [✨ Analyze with AI]               │
│                                     │
├─────────────────────────────────────┤
│  📝 Your Notes:                     │
│  ┌─────────────────────────────┐   │
│  │ [User types here]           │   │
│  └─────────────────────────────┘   │
│                                     │
│  🏷️  Your Tags:                     │
│  [javascript] [tutorial] [+Add]     │
│                                     │
├─────────────────────────────────────┤
│  🤖 AI Suggestions:                 │
│                                     │
│  Suggested Note:                    │
│  "A comprehensive guide to async/   │
│   await patterns in JavaScript..."  │
│                  [+ Add to Notes]   │
│                                     │
│  Suggested Tags:                    │
│  [async]✓ [patterns]✓ [advanced]✓  │
│  (Click to toggle)                  │
│                                     │
│  ⚠️  Content sent to OpenAI         │
├─────────────────────────────────────┤
│                    [Save] [Cancel]  │
└─────────────────────────────────────┘
```

## Goals

### Primary Goals (LR003)

1. **Backend AI Endpoint**
   - `POST /api/v1/links/analyze` endpoint
   - Accepts: `{ url: "..." }` or `{ link_id: "uuid" }`
   - Backend fetches page content on-demand (quick fetch for analysis)
   - Integrates with existing RubyLLM + OpenAI infrastructure
   - Queries user's existing tags, sends to AI as context
   - Returns: `{ suggested_note: "...", suggested_tags: [{name, exists}] }`

2. **Extension UI Enhancement**
   - Add "✨ Analyze with AI" button in extension popup
   - Show loading state with spinner (cancellable, 15s timeout)
   - Display suggestions in separate "🤖 AI Suggestions" section
   - Suggested note with "[+ Add to Notes]" button (appends to user's notes)
   - Suggested tags as toggleable chips (green=existing, blue=new)
   - Privacy notice: "⚠️ Content sent to OpenAI"
   - Never overwrites user input (non-destructive)

3. **Intelligent Prompting**
   - AI receives: title, meta description, ~2000 chars of text
   - AI receives: user's existing tags list (normalized, case-insensitive)
   - Prompt constraints: 3-7 relevant tags, prefer existing over new
   - Prompt output: 1-2 sentence note explaining why link is worth saving
   - For re-analysis: Include existing notes/tags as context

4. **User Control**
   - Manual trigger only (no auto-analyze in MVP)
   - Works for new links (before save) AND existing links (re-analysis)
   - Full control: user picks which suggestions to accept
   - Graceful degradation: if AI fails, user can still save manually

### Secondary Goals

- Track analysis usage for cost monitoring (log each request)
- Basic error handling (timeouts, API failures, malformed responses)
- Case-insensitive tag matching (JavaScript === javascript)

### Explicitly Deferred

- Content archival/storage (separate feature, separate timeline)
- Rate limiting per user (single-user MVP, not needed yet)
- Result caching (pages change, keep it simple)
- Sensitive content detection
- Multi-language detection
- Learning from accept/reject patterns (Phase 2)
- Auto-analyze mode (automatic on popup open)
- Confidence scoring and selective suggestions

## Design Decisions

### Content Strategy

**Decision: Backend fetches content on-demand for analysis**

- Extension sends URL to backend, not content
- Backend fetches page with HTTP client (Faraday)
- Simple fetch: title, meta description, ~2000 chars of visible text
- No storage/archival during analysis (that's a separate feature)
- For existing links: Re-fetch from live page for fresh analysis

**Rationale:**
- Simpler extension code (no content scraping needed)
- Handles auth-walled, paywalled, or SPA content better when using existing link's stored content
- Decouples AI analysis from content archival feature
- Can implement either feature independently

**Trade-offs accepted:**
- Some content may be inaccessible to backend (login-walled)
- Fresh fetch means slight delay vs. pre-cached content
- These are acceptable for MVP; content archival feature will improve this later

### Tag Matching & Normalization

**Decision: Case-insensitive matching, preserve user's chosen casing**

- Backend compares tags case-insensitively (JavaScript == javascript)
- When tag exists, mark as `exists: true` in response
- AI prompted to match existing tags exactly (case-insensitive)
- On save, backend creates new tags with user's chosen casing

**Rationale:**
- Prevents duplicates from case differences
- Respects user's preferred tag style
- Critical for radar feature accuracy (tags need to be consistent)

**Out of scope for MVP:**
- Plurals (tutorial vs tutorials)
- Synonyms (js vs javascript)
- Spaces/dashes (machine-learning variations)

### UI Presentation

**Decision: Separate suggestion area, non-destructive**

- Two distinct sections: user input (top) + AI suggestions (bottom)
- AI never auto-fills or overwrites user's typed content
- For notes: "[+ Add to Notes]" button appends to user's field
- For tags: Toggleable chips, user clicks to select

**Rationale:**
- Non-destructive: AI can't erase user's work
- Clear separation: obvious what's AI vs what's user-entered
- Flexible: user can mix manual input + AI suggestions
- User stays in control

**Rejected alternatives:**
- Auto-fill form fields: Too aggressive, users lose their input
- Replace on accept: Confusing, loses user's manual work
- Modal/dialog: Breaks flow, feels too heavy

### Analysis Timing

**Decision: Analysis is separate action from save**

- Analysis doesn't save the link
- Save doesn't trigger analysis
- User can analyze before save, after save, or not at all
- Re-analysis is supported anytime

**Rationale:**
- Flexibility: analyze new links OR re-analyze existing links
- User control: analysis is opt-in, not forced
- Simpler architecture: two independent actions
- Better error handling: analysis failure doesn't block save

### Error Handling

**Decision: Graceful degradation, never block save**

- 15-second timeout on analysis request
- Show friendly error: "AI analysis unavailable, you can still save manually"
- Log errors for debugging (don't expose to user)
- Cancellable loading state (X button)

**Rationale:**
- AI is enhancement, not requirement
- User's workflow should never be blocked
- Save functionality always works, even if AI is down

### Privacy & Transparency

**Decision: Small notice, no blocking warnings**

- Show "⚠️ Content sent to OpenAI" in suggestions section
- No confirmation dialog or complex consent flow
- Single-user MVP: user is admin, they configured OpenAI key

**Rationale:**
- Transparency without friction
- User already opted in by configuring API key
- Multi-user version will need proper privacy controls

### Cost Management

**Decision: Monitor but don't limit**

- Log each analysis request with timestamp
- Track token counts if possible
- No hard rate limits for MVP
- Estimated cost: ~$0.0004 per analysis (sub-penny)

**Rationale:**
- Single-user MVP: cost is predictable and low
- At 5 analyses/day * 30 days = ~$0.06/month
- Can add limits later if needed
- Monitoring provides data for future decisions

### Performance Expectations

**Decision: 3-5 second typical response time**

- Simple loading state with spinner
- 15-second timeout (reasonable for AI)
- Cancellable by user
- No progress updates or complexity

**Rationale:**
- GPT-4o-mini is fast (~2-4 seconds typically)
- Network + fetch + AI = ~3-5 seconds total
- Users understand AI takes time
- No need for streaming or complex progress

## User Stories

### As a Developer Saving Technical Articles

- I want AI to recognize my existing tags like "JavaScript" and "TypeScript" so I don't create duplicates
- I want AI to suggest new tags like "Bun" when I'm exploring emerging tools
- I want a summary note that explains why I might care about this link later

### As a Researcher Collecting Papers

- I want AI to generate tags based on topic domains (ML, NLP, Computer Vision)
- I want concise notes capturing the paper's main contribution
- I want to quickly review and refine AI suggestions before saving

### As a Power User

- I want to see which tags are new vs. existing in my collection
- I want to edit AI-generated notes to add my own context
- I want confidence that AI understands my tagging taxonomy

## Success Criteria

### Must Have

- [ ] Backend endpoint `POST /api/v1/links/analyze` accepts `{ url }` or `{ link_id }`
- [ ] Backend fetches page content on-demand (title, meta, ~2000 chars text)
- [ ] Endpoint queries user's existing tags (case-insensitive)
- [ ] Endpoint sends structured prompt to RubyLLM with OpenAI GPT-4o-mini
- [ ] Endpoint returns: `{ suggested_note: "...", suggested_tags: [{name, exists: bool}] }`
- [ ] Extension shows "✨ Analyze with AI" button in popup
- [ ] Button triggers analysis API call with URL
- [ ] Loading state with spinner, cancellable, 15s timeout
- [ ] Suggestions appear in separate "🤖 AI Suggestions" section
- [ ] Suggested note with "[+ Add to Notes]" button (appends to user's notes)
- [ ] Suggested tags as toggleable chips (green=existing, blue=new)
- [ ] Privacy notice: "⚠️ Content sent to OpenAI"
- [ ] User can select which suggestions to accept
- [ ] Save works with or without AI suggestions
- [ ] Graceful error handling with friendly message
- [ ] Analysis works for new links (before save) and existing links (re-analysis)

### Should Have

- Case-insensitive tag matching (JavaScript === javascript)
- Prompt limits: 3-7 tags, 1-2 sentence note
- AI prefers existing tags over creating new ones
- For re-analysis: send existing notes/tags as context
- Log each analysis for cost monitoring
- Character limits on content (~2000 chars)

### Nice to Have

- Track which suggestions users accept/reject (foundation for learning)
- Example prompts in documentation
- Visual feedback when adding note (animation/highlight)

## Implementation Approach

### Phase 1: Backend AI Endpoint (1 day)

Build the Rails API endpoint that handles analysis:

1. **Endpoint Setup**: Create `POST /api/v1/links/analyze` in LinksController
2. **Content Fetching**: Use Faraday to fetch URL (title, meta, text excerpt)
3. **Tag Collection**: Query user's existing tags (case-insensitive normalized list)
4. **Prompt Engineering**: Design system and user prompts with constraints
5. **RubyLLM Integration**: Call OpenAI GPT-4o-mini via RubyLLM
6. **Response Parsing**: Parse AI response, mark which tags exist
7. **Return JSON**: `{ suggested_note, suggested_tags: [{name, exists}] }`
8. **Error Handling**: Timeouts, graceful failures, logging

### Phase 2: Extension UI Enhancement (1 day)

Add AI analysis UI to the browser extension:

1. **API Client**: Add `analyzeLink()` function to `apiClient.ts`
2. **UI Components**: Add "✨ Analyze with AI" button to popup
3. **Loading States**: Spinner, cancellable, 15s timeout
4. **Suggestions Section**: New "🤖 AI Suggestions" area (separate from user input)
5. **Note UI**: Suggested note box with "[+ Add to Notes]" button
6. **Tag UI**: Toggleable chips (green=existing, blue=new)
7. **Privacy Notice**: "⚠️ Content sent to OpenAI"
8. **State Management**: Track suggestions, selections, loading
9. **Integration**: Selected suggestions merge with user's manual input on save

### Phase 3: Prompt Engineering & Polish (0.5-1 day)

Optimize prompts and user experience:

1. **Prompt Iteration**: Test with real articles, refine for quality
2. **Content Limits**: Tune ~2000 char excerpt extraction
3. **Tag Quality**: Ensure AI reuses existing tags appropriately
4. **Note Quality**: Ensure notes are concise and useful (1-2 sentences)
5. **Error Messages**: User-friendly error text
6. **Edge Cases**: Empty results, timeouts, malformed content

## Technical Details

### Backend Endpoint Specification

```ruby
POST /api/v1/links/analyze
Content-Type: application/json
Authorization: Bearer <token>

# Request Option 1: New link (URL only)
{
  "url": "https://example.com/article"
}

# Request Option 2: Existing link (by ID)
{
  "link_id": "uuid-here"
}

# Response (success)
{
  "suggested_note": "A comprehensive guide to async/await patterns...",
  "suggested_tags": [
    { "name": "JavaScript", "exists": true },
    { "name": "async-patterns", "exists": false },
    { "name": "tutorial", "exists": true }
  ]
}

# Response (error)
{
  "error": "Unable to fetch content from URL"
}

# HTTP Status Codes
# 200 - Success
# 400 - Invalid request (missing url/link_id)
# 404 - Link not found (when using link_id)
# 422 - Unable to fetch content
# 500 - AI service error
# 504 - Timeout
```

### RubyLLM Integration Pattern

```ruby
class LinkAnalyzer
  def analyze(url:, title:, content:, user:)
    existing_tags = user.tags.order(usage_count: :desc).limit(50).pluck(:name)
    
    chat = RubyLLM.chat
    response = chat.ask(build_prompt(title, content, existing_tags))
    
    parse_response(response, existing_tags)
  end
  
  private
  
  def build_prompt(title, content, existing_tags)
    # System prompt + user prompt with content and tags
  end
  
  def parse_response(response, existing_tags)
    # Extract tags and note, classify as existing vs. new
  end
end
```

### Extension API Client Addition

```typescript
// lib/apiClient.ts

export interface SuggestedTag {
  name: string
  exists: boolean // true = existing tag, false = new suggestion
}

export interface AnalyzeLinkResponse {
  suggested_note: string
  suggested_tags: SuggestedTag[]
}

// Analyze a URL (new link)
export async function analyzeLink(url: string): Promise<AnalyzeLinkResponse> {
  const response = await authenticatedFetch("/api/v1/links/analyze", {
    method: "POST",
    body: JSON.stringify({ url }),
  })
  return response.data
}

// Re-analyze an existing link
export async function analyzeLinkById(linkId: string): Promise<AnalyzeLinkResponse> {
  const response = await authenticatedFetch("/api/v1/links/analyze", {
    method: "POST",
    body: JSON.stringify({ link_id: linkId }),
  })
  return response.data
}
```

## Non-Goals (Out of Scope for LR003)

- **Content archival/storage** - Separate feature, separate timeline
- **Auto-analyze mode** - Manual trigger only in MVP
- **Learning/adaptation** - AI doesn't learn from user's accept/reject patterns yet
- **Bulk analysis** - Only current link, no batch processing
- **Advanced content extraction** - Simple HTTP fetch, no headless browser
- **Multi-model support** - OpenAI GPT-4o-mini only via RubyLLM
- **Confidence scoring** - All suggestions presented equally
- **Suggestion history** - No tracking of previous AI suggestions per link
- **Rate limiting** - Single-user MVP, not needed yet
- **Result caching** - Pages change, keep it simple

## Risks and Mitigation

### Risk: AI suggestions are low quality or irrelevant

**Mitigation:**
- Iterate on prompts with real content
- Include existing tag context to ground suggestions
- Provide clear editing UI so users can fix bad suggestions
- Make AI analysis optional, not mandatory

### Risk: API costs scale unexpectedly with usage

**Mitigation:**
- Set content length limits (~2000 characters)
- Use cost-effective model (GPT-4o-mini: ~$0.0004 per analysis)
- Log each analysis for monitoring
- Single-user MVP keeps costs predictable
- Estimated $0.06/month at 5 analyses/day

### Risk: Slow response times frustrate users

**Mitigation:**
- Set reasonable timeout (15 seconds)
- Show clear loading state with spinner
- Allow users to cancel analysis (X button)
- Graceful degradation: user can always save manually
- GPT-4o-mini is fast (~2-4 seconds typically)

### Risk: Backend can't fetch auth-walled or paywall content

**Mitigation:**
- Document limitation in UI
- For MVP: acceptable trade-off
- Future: Content archival feature will store content, enabling re-analysis
- Works fine for public content (most use cases)

## Dependencies

- **RubyLLM**: Already installed and configured (✓)
- **OpenAI API Key**: Already configured (✓)
- **Existing Tag System**: Links and Tags models in place (✓)
- **Extension API Client**: Base structure exists, needs new endpoint (minor)

## Related Features

- **LR001 - Core Infrastructure** - Provides Rails API foundation
- **Future: LR004 - Auto-Analyze Mode** - Automatic AI analysis on link capture
- **Future: LR005 - AI Learning** - System learns from user's tag patterns
- **Future: Tag Hierarchies** - Support for nested/hierarchical tags (JavaScript > Testing > Jest)

## References

- [RubyLLM Documentation](https://rubyllm.com/)
- [OpenAI Best Practices](https://platform.openai.com/docs/guides/prompt-engineering)
- LinkRadar Vision Document - Auto-tagging and content preservation goals
- Existing Tag System Implementation (`app/models/tag.rb`, `app/models/link.rb`)

