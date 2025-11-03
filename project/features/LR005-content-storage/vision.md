# LR005 - Content Archival & Storage

## Vision

Automatically capture and preserve web page content so users can search and access their saved knowledge even when links die, change, or go behind paywalls.

## Table of Contents

- [Problem](#problem)
- [Solution](#solution)
- [User Needs](#user-needs)
- [Future Possibilities](#future-possibilities)
- [Scope](#scope)

## Problem

Saved links become useless when content disappears:

1. **Links Die** - Pages get taken down, domains expire, content moves
2. **Paywalls Appear** - Free articles get moved behind subscriptions
3. **Content Changes** - Original content gets edited or replaced
4. **Lost Knowledge** - Can't recover information you already found once

Real impact: User saves "Docker Compose watch feature" article for future reference, but when they finally need it months later, the link returns 404. They waste time re-searching Google from scratch, or worse, never find it again.

**Why archival matters for LinkRadar specifically:**
- Tags and notes help you find links, but archived content makes them **useful** when you find them
- LLM-powered semantic search requires actual content, not just metadata
- Building a personal knowledge base requires the knowledge to persist

## Solution

Fetch and archive web page content automatically in the background whenever a link is saved to LinkRadar.

### Core Philosophy

**Best effort, graceful degradation** - Content archival is valuable insurance and enables better search, but failure to archive shouldn't block link capture. Tags and notes are primary; archived content enhances.

**Server-side, controlled extraction** - Always fetch content server-side (not client-side from extension) for consistency, security, and ability to improve extraction over time.

**Storage optimized for search** - Store both clean HTML (for display) and plain text (for full-text search and LLM embeddings).

### Key Capabilities

1. **Clean Content Extraction** - Extract main article content, stripping ads, navigation, and clutter using Readability algorithm
2. **Rich Metadata Capture** - Store title, description, preview images, OpenGraph/Twitter Card data
3. **Dual Format Storage** - Save both cleaned HTML (for display) and plain text (optimized for search and embeddings)
4. **Graceful Failure Handling** - Retry failed fetches with exponential backoff; store error details; never block link capture

### How It Works

1. User saves link (via extension, CLI, or web UI)
2. Link record created immediately with URL, tags, notes
3. Background job enqueued for content fetching (user doesn't wait)
4. Job fetches page, extracts content, stores HTML + text
5. User sees "processing" state, then "archived" when complete
6. If extraction fails after retries, link saved as URL-only (user can still search by tags/notes)

### Architecture Decision

**Content Archival (LR005) vs. AI Analysis (LR003) separation:**

AI analysis needs content quickly (3-5 seconds for user feedback), so it uses opportunistic fetching:
- Extension: Sends client-extracted DOM content directly
- Web UI/CLI: Fetches server-side on-demand

Content archival happens separately in background for reliability, consistency, and future re-fetch capability. This separation means extension might fetch content twice (once for AI, once for archival), which is acceptable for v1.

## User Needs

### End Users

**Need to accomplish:**
- Trust that saved content will remain accessible even if original link dies
- Search archived content by full-text when tags alone aren't enough
- View readable archived content when original URL becomes unavailable
- Build a reliable personal knowledge base powered by LLM embeddings

## Future Possibilities

Phase 2 and beyond will add JavaScript rendering for SPA sites, local image archival, content re-fetching, PDF generation, and more. See [future.md](future.md) for detailed roadmap.

## Scope

### What v1 Delivers

**Content Extraction Pipeline:**
- Background job (`FetchContentJob`) processes each saved link asynchronously
- HTTP fetch with proper User-Agent, timeouts (10s connect, 15s read), redirect limits (5 max)
- Metadata extraction via `metainspector` gem (title, description, og:image, twitter:card)
- Main content extraction via `ruby-readability` gem (Mozilla's Readability algorithm)
- HTML sanitization via `loofah` gem (strip `<script>` tags, event handlers, XSS vectors)
- Plain text extraction for full-text search and embeddings
- URL normalization via `addressable` gem (strip tracking params, follow canonical)

**Security & Quality (v1):**
- Block private IP ranges (10.0.0.0/8, 127.0.0.0/8, 192.168.0.0/16, etc.) - prevent SSRF
- Only allow http/https schemes
- File size limits (reject pages over 10MB)
- Rate limiting per domain (respectful crawling)
- Exponential backoff retry (3 attempts: immediate, +2s, +4s)
- Store fetch errors for debugging
- Identify as LinkRadar bot with contact URL in User-Agent

**Data Storage:**
```ruby
# Stored in links table (or separate content_archives table)
url:           string    # Normalized URL
title:         string    # Extracted title (og:title > twitter:title > <title>)
description:   text      # Meta description
image_url:     string    # Preview image (og:image, stored as URL only in v1)
content_html:  text      # Cleaned HTML from Readability
content_text:  text      # Plain text for search/embeddings
metadata:      jsonb     # OpenGraph, Twitter Card, JSON-LD data
fetch_status:  enum      # pending, success, failed
fetch_error:   text      # Error message if failed
fetched_at:    datetime  # Last successful fetch timestamp
```

**PostgreSQL Full-Text Search:**
- Index `content_text` with `tsvector` for fast full-text search
- Combined with tag/note search for comprehensive results

### What's Not in v1

**Explicitly Deferred:**
- JavaScript rendering (headless Chrome via Ferrum) - Phase 2
- Local image archival (download and store images) - Phase 2
- Re-fetch/update capability - Phase 2
- Content compression (gzip storage) - Phase 2
- TTL/expiration policies - Phase 2
- PDF generation from archived content - Phase 3
- Full page screenshots - Phase 3
- Archive.org integration - Phase 3

**Known Limitations (Acceptable for v1):**
- Can't archive auth-walled content (backend has no session)
- Simple HTTP fetch may miss content on heavy SPA sites
- Images stored as URLs only (vulnerable to link rot)
- No re-fetch capability (first archive is permanent)

---

**Dependencies:** metainspector, ruby-readability, loofah, faraday, addressable, PostgreSQL  
**Integration:** Works with LR003 (AI Analysis) - separate fetch paths  
**Timeline:** 3-5 days (2 days backend pipeline, 1 day testing, 1-2 days polish)

