# LR003 - AI-Powered Link Analysis

**Status:** Planning  
**Timeline:** 2-3 days  
**Dependencies:** RubyLLM (installed ✓), OpenAI API Key (configured ✓)

## Quick Links

- [Vision Document](vision.md) - Problem, solution, design decisions, and goals
- [Implementation Plan](plan.md) - Detailed 3-phase implementation with code examples
- [LinkRadar Vision](../../vision.md) - Overall product vision

## Overview

Add intelligent AI analysis to the browser extension that suggests relevant tags and notes when users request it. The AI analyzes page content and provides suggestions that users can selectively accept, combining them with their own manual input.

**Key principles:**
- **Manual trigger** - User clicks button to request analysis
- **Non-destructive** - Suggestions never overwrite user input
- **Selective acceptance** - User picks which suggestions to use
- **Works everywhere** - Analyzes new links (before save) or existing links (re-analysis)

## What's Being Built

### User Experience

1. User opens extension on an interesting article
2. Clicks "✨ Analyze with AI" button
3. Waits ~3-5 seconds while AI processes (cancellable)
4. Sees suggestions in separate "🤖 AI Suggestions" section:
   - **Suggested Note**: Brief explanation with "[+ Add to Notes]" button
   - **Suggested Tags**: Toggleable chips (green=existing, blue=new)
5. User reviews and selects what to accept:
   - Can type their own notes AND accept AI note
   - Can add their own tags AND select AI tags
   - Can ignore all suggestions
6. Clicks Save to persist link with combined input

### UI Mockup

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
│  "A guide to async/await patterns"  │
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

## Technical Architecture

### Backend: Analysis Endpoint

```
POST /api/v1/links/analyze
Authorization: Bearer <token>

Request:
  { "url": "https://example.com" }
  OR
  { "link_id": "uuid-here" }

Response:
  {
    "suggested_note": "...",
    "suggested_tags": [
      { "name": "JavaScript", "exists": true },
      { "name": "async-patterns", "exists": false }
    ]
  }
```

**What it does:**
1. Fetches page content (title, meta, ~2000 chars of text)
2. Queries user's existing tags
3. Sends to OpenAI GPT-4o-mini via RubyLLM
4. Returns structured suggestions with tag existence markers

### Extension: Analysis UI

**New components:**
- "✨ Analyze with AI" button
- Loading state (spinner, cancellable, 15s timeout)
- "🤖 AI Suggestions" section
- Suggested note with add button
- Suggested tag chips (toggleable, color-coded)
- Privacy notice

**State management:**
- Track suggestions from AI
- Track user selections (which tags, whether to include note)
- Merge selections with manual input on save

## Implementation Phases

### Phase 1: Backend AI Endpoint (1 day)

- Create `POST /api/v1/links/analyze` endpoint
- Add `LinkAnalysisService` for content fetching and AI calls
- Integrate with RubyLLM + OpenAI
- Handle errors gracefully
- Add logging for cost monitoring

### Phase 2: Extension UI (1 day)

- Add `analyzeLink()` to API client
- Add analysis button and suggestions UI
- Implement loading and error states
- Add tag selection and note add functionality
- Update save logic to merge selections

### Phase 3: Prompt Engineering & Polish (0.5-1 day)

- Test with real articles
- Refine prompts for quality
- Tune content extraction
- Handle edge cases
- Polish UI and error messages
- Create usage documentation

## Design Decisions Summary

### Content Strategy
- **Backend fetches content** (extension just sends URL)
- **No storage during analysis** (content archival is separate feature)
- **On-demand fetch** (~2000 chars of text for analysis)

### Tag Matching
- **Case-insensitive matching** (JavaScript === javascript)
- **Mark existing vs new** (so user knows what's in their system)
- **Preserve user's casing** (respect their preferred style)

### UI Approach
- **Separate suggestion area** (non-destructive, never overwrites user input)
- **Selective acceptance** (user picks which suggestions to use)
- **Visual distinction** (green chips = existing, blue = new)

### Analysis Timing
- **Separate from save** (analyze whenever, save whenever)
- **Works for new links** (before they're persisted)
- **Works for existing links** (re-analysis anytime)

## What's NOT Included (Out of Scope)

- ❌ Content archival/storage (separate feature)
- ❌ Auto-analyze mode (manual trigger only)
- ❌ Learning from patterns (no adaptation yet)
- ❌ Rate limiting (single-user MVP)
- ❌ Result caching (pages change)
- ❌ Multiple AI models (OpenAI only)
- ❌ Confidence scoring
- ❌ Suggestion history tracking

## Cost & Performance

**Cost per analysis:** ~$0.0004 (less than a penny)

**At 5 analyses/day:**
- Daily: $0.002
- Monthly: $0.06
- Yearly: $0.73

**Performance:**
- Typical response: 3-5 seconds
- Timeout: 15 seconds
- Cancellable by user

**Model:** OpenAI GPT-4o-mini (fast, cheap, good quality)

## Dependencies Checklist

- ✅ RubyLLM gem installed
- ✅ OpenAI API key configured
- ✅ Links and Tags models exist
- ✅ Extension popup exists
- ✅ API authentication working
- ⚠️ Need to add: Faraday gem
- ⚠️ Need to add: Nokogiri gem

## Success Criteria

**Must Have:**
- [ ] Analysis endpoint works for URLs and link IDs
- [ ] Backend fetches content and analyzes with AI
- [ ] Extension shows analysis button and suggestions UI
- [ ] User can select which suggestions to accept
- [ ] Selected suggestions merge with manual input on save
- [ ] Works for new links (before save) and existing links (re-analysis)
- [ ] Graceful error handling
- [ ] Privacy notice displayed

**Should Have:**
- [ ] Case-insensitive tag matching
- [ ] 3-7 relevant tags suggested
- [ ] 1-2 sentence notes
- [ ] Prefers existing tags over creating new ones
- [ ] Logs analysis events for cost monitoring

**Nice to Have:**
- [ ] Smooth UI transitions
- [ ] Demo video/GIF
- [ ] Usage documentation

## Testing the Feature

### Backend Test (curl)

```bash
curl -X POST http://localhost:3000/api/v1/links/analyze \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise"}'
```

### Extension Test

1. Open extension on MDN Promise docs
2. Click "✨ Analyze with AI"
3. Wait for suggestions
4. Verify tags include "JavaScript" (existing) and "promises" (new)
5. Click some tags to select
6. Click "[+ Add to Notes]"
7. Add manual tag
8. Click Save
9. Verify backend received all tags

## Known Limitations

1. **Auth-walled content**: Backend can't fetch pages requiring login
2. **Paywalls**: Can't analyze content behind paywalls (from backend perspective)
3. **Very dynamic SPAs**: Simple fetch may miss JS-rendered content
4. **Non-English**: Works but not optimized (GPT-4 is multilingual)

These are **acceptable trade-offs for MVP**. Content archival feature will improve this later.

## Future Enhancements

**Phase 2:**
- Auto-analyze mode (automatic on popup open)
- Content archival integration (use stored content)
- Learning system (improve from user patterns)

**Phase 3:**
- Multiple AI models (Claude, local models)
- Confidence scoring
- Custom prompt templates
- Batch analysis

## Questions?

See the full [Vision Document](vision.md) for design rationale and detailed decisions, or the [Implementation Plan](plan.md) for step-by-step code examples.

---

**Last Updated:** January 2025  
**Status:** Ready for Implementation
