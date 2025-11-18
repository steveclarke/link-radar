# LR003 - AI-Powered Link Analysis

## Vision

Transform link capture from a manual categorization chore into an intelligent, assisted experience where users get AI-powered tag and note suggestions without sacrificing control.

## Table of Contents

- [Problem](#problem)
- [Solution](#solution)
- [User Needs](#user-needs)
- [Future Possibilities](#future-possibilities)
- [Scope](#scope)

## Problem

Users face friction when organizing saved links:

1. **Manual Tag Entry** - Must remember and type tag names, creating friction
2. **Tag Discovery Gap** - Don't know what tags already exist, leading to duplicates ("javascript" vs "JavaScript" vs "JS")
3. **Context Loss** - Writing meaningful notes breaks flow, so users skip them entirely
4. **Inconsistent Organization** - Manual tagging leads to inconsistent categorization over time
5. **Time Cost** - Thoughtful organization takes time, forcing choice between fast capture OR good organization

This creates two failure modes:
- **Fast but messy**: Skip tags/notes to save time, losing organization benefits
- **Slow but organized**: Spend cognitive effort on categorization, making capture feel like a chore

## Solution

Add an "Analyze with AI" feature that provides intelligent tag and note suggestions in a separate, non-destructive UI area.

### Core Approach

**Manual trigger with selective acceptance** - User clicks button when they want suggestions. AI never auto-fills or overwrites their work. They pick which suggestions to accept.

**Backend-powered analysis** - Extension extracts page content (DOM) and sends it with URL to backend for OpenAI analysis. Backend never fetches content for AI analysis - it receives pre-extracted content from extension.

**Works everywhere** - Analyze new links before saving OR re-analyze existing links anytime.

### Key Capabilities

1. **Smart Tag Suggestions** - AI suggests 3-7 relevant tags, preferring user's existing tags to avoid creating unnecessary new ones
2. **Contextual Notes** - AI generates 1-2 sentence note explaining why the content is worth saving
3. **Existing Tag Recognition** - Shows which suggested tags already exist (green) vs new ones (blue)
4. **Non-Destructive UI** - Suggestions appear in separate section, user can mix AI suggestions with their own input
5. **Graceful Degradation** - If AI fails, user can still save manually (never blocks core workflow)

### User Flow

1. User opens extension on interesting article
2. Clicks "✨ Analyze with AI" button
3. Waits 3-5 seconds (cancellable, with spinner)
4. Reviews suggestions in separate "🤖 AI Suggestions" section
5. Toggles tag selections, clicks to add note
6. Combines AI suggestions with their own input
7. Saves link with merged tags and notes

## User Needs

### End Users (Link Savers)

**Need to accomplish:**
- Quickly capture links without forgetting organization
- Discover what tags already exist in their collection
- Get meaningful notes without breaking capture flow
- Maintain consistent tagging over time
- Choose between manual precision OR AI speed for any given link

## Future Possibilities

Phase 2 and beyond will explore auto-analyze mode, learning from user patterns, content archival integration, and more. See [future.md](future.md) for detailed roadmap.

## Scope

### What v1 Delivers

**Backend Analysis Endpoint:**
- `POST /api/v1/links/analyze` accepts `{url, content}` from extension or `{link_id}` (for re-analysis with archived content)
- Receives pre-extracted page content from extension (title, meta, ~2000 chars text)
- Queries user's existing tags for context
- Calls OpenAI GPT-4o-mini via RubyLLM
- Returns structured JSON: `{suggested_note, suggested_tags: [{name, exists}]}`
- Error handling with timeouts and graceful failures
- Logging for cost monitoring

**Extension UI Enhancement:**
- "✨ Analyze with AI" button in popup
- Loading state with spinner (cancellable, 15s timeout)
- "🤖 AI Suggestions" section displaying:
  - Suggested note with "[+ Add to Notes]" button
  - Suggested tags as toggleable chips (green=existing, blue=new)
  - Privacy notice: "⚠️ Content sent to OpenAI"
- Selected suggestions merge with user's manual input on save
- Works for new links (before save) and existing links (re-analysis)

**Intelligent Behavior:**
- Case-insensitive tag matching (JavaScript === javascript)
- AI prefers existing tags over creating new ones
- 3-7 tag limit
- 1-2 sentence notes
- Respects user's chosen tag casing

### What's Not in v1

**Explicitly Deferred:**
- Auto-analyze mode (manual trigger only in v1)
- Learning from user patterns (no adaptation yet)
- Rate limiting per user (single-user MVP)
- Result caching (pages change, keep it simple)
- Multi-model support (OpenAI only via RubyLLM)
- Confidence scoring
- Bulk/batch analysis
- Advanced content extraction (no headless browser)
- Sensitive content detection
- Multi-language optimization

**Known Limitations (Acceptable for v1):**
- Extension-extracted content sent to OpenAI (privacy implication noted in UI)
- Not optimized for non-English content (but GPT-4 is multilingual)
