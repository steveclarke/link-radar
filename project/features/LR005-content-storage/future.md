# LR005 - Content Archival & Storage: Future Enhancements

This document details future phases and enhancements for content archival beyond the v1 implementation.

## Table of Contents

- [Phase 2: Enhanced Extraction & Storage](#phase-2-enhanced-extraction--storage)
- [Phase 3: Advanced Archival Features](#phase-3-advanced-archival-features)
- [Phase 4: Integration & Optimization](#phase-4-integration--optimization)

## Phase 2: Enhanced Extraction & Storage

### JavaScript Rendering (High Priority)

**Problem:** Many modern sites (SPAs, React apps, Vue apps) render content with JavaScript. Simple HTTP fetch returns empty page or loading skeleton.

**Solution:** Integrate Ferrum gem (headless Chrome) for JavaScript-heavy sites.

**Approach:**
- Detect when simple fetch produces minimal content (heuristic: < 500 chars after cleaning)
- Fallback to Ferrum for second attempt
- Render page, wait for content to load, extract from rendered DOM
- Store metadata flag indicating "required JS rendering" for future re-fetch

**Tradeoffs:**
- Slower (3-5 seconds vs. < 1 second)
- More resource intensive (Chrome instance)
- More complex (browser lifecycle management)
- Higher costs if running on VPS

**Configuration:** Make JS rendering opt-in or automatic fallback based on content detection.

### Local Image Archival (High Priority)

**Problem:** Storing `image_url` as external URL means images can disappear just like page content.

**Solution:** Download and store images locally using file storage gem.

**Implementation:**
- Use Shrine gem (or ActiveStorage) for file management
- Download images referenced in metadata (og:image, twitter:image)
- Optionally download images embedded in content_html
- Store multiple sizes (thumbnail, medium, full)
- Generate local URLs to replace external image_url references

**Storage Options:**
- Local filesystem (simplest for self-hosted)
- S3-compatible storage (for scalability)
- Cloudflare R2 (cost-effective alternative)

**Scope Considerations:**
- All images or just metadata images?
- Size limits per image?
- Format conversion (WebP for efficiency)?

### Content Re-fetch Capability (High Priority)

**Problem:** V1 archives content once. If extraction improves or content changes, no way to update.

**Solution:** Add re-fetch functionality for existing archived links.

**Features:**
- Manual "Re-archive this link" button in web UI
- Bulk re-archive by tag or date range
- Detect extraction improvements (new Readability version) and re-fetch affected links
- Store multiple archive versions with timestamps (optional: keep history)

**Use Cases:**
- Improved extraction algorithm → re-archive all links
- Page content updated → user requests fresh archive
- Initial extraction failed → retry months later

### Content Compression

**Problem:** Archived HTML can be large (50KB-500KB per page), storage costs add up.

**Solution:** Compress `content_html` and `content_text` columns using Rails compression.

**Implementation:**
```ruby
# In migration
t.text :content_html, compression: :gzip
t.text :content_text, compression: :gzip
```

**Benefits:**
- 60-80% storage reduction typical
- Transparent to application code (Rails handles automatically)
- Lower database backup sizes

**Tradeoffs:**
- Slight CPU cost on read/write
- Not searchable while compressed (PostgreSQL can't index compressed columns directly)

### TTL & Expiration Policies

**Problem:** Some content is time-sensitive (news articles), some is evergreen (documentation).

**Solution:** Configurable TTL policies for archived content.

**Features:**
- Tag-based TTL rules (e.g., `news` tag → 30-day retention, `documentation` → forever)
- Automatic pruning of expired content (keep URL/metadata, delete archive)
- User-configurable retention preferences
- "Pin" capability to protect specific links from expiration

**Benefits:**
- Control storage growth
- Comply with content retention policies
- Focus storage on valuable evergreen content

## Phase 3: Advanced Archival Features

### PDF Generation from Archived Content (Priority #2)

**Problem:** Users want offline-readable, printable versions of archived content.

**Solution:** Generate PDF from archived HTML using headless Chrome print-to-PDF.

**Implementation:**
- Use Ferrum or Grover gem (both wrap Chrome print API)
- Generate PDF on-demand or proactively
- Store alongside HTML archive
- Styled for readability (remove background colors, optimize fonts)

**Use Cases:**
- "Export to PDF" button in web UI
- Bulk export for offline reading
- Archival for compliance/legal purposes

**Configuration:**
- PDF generation timing (on-demand vs. automatic)
- Include images or text-only
- Page size, margins, formatting options

### Full Page Screenshots (Priority #3)

**Problem:** Sometimes visual layout matters (design inspiration, UI examples), not just text content.

**Solution:** Capture full page screenshot using headless Chrome.

**Implementation:**
- Use Ferrum to render page and capture screenshot
- Store as WebP (efficient compression)
- Capture full scrolling page, not just viewport
- Store alongside text archive

**Use Cases:**
- Design inspiration archives
- UI pattern collections
- "What did this site look like?" historical reference

**Storage Considerations:**
- Screenshots are large (500KB-2MB typical)
- Optional feature (user-configurable per link or workspace)
- Thumbnail generation for grid views

### Archive.org Integration (Priority #4)

**Problem:** Even local archives can be lost (server failure, corruption). Archive.org provides redundant public archive.

**Solution:** Optionally submit URLs to Wayback Machine when archiving.

**Implementation:**
- After successful local archive, POST to Archive.org Save Page API
- Store Wayback Machine URL as fallback reference
- Check if page already archived before submitting
- Respect Archive.org rate limits

**Benefits:**
- Redundant public archive as ultimate fallback
- Support for Internet Archive's mission
- Additional assurance content is preserved

**Privacy Considerations:**
- Make this opt-in (user may not want public archival)
- Exclude private/sensitive content
- Workspace-level configuration (public vs. private collections)

## Phase 4: Integration & Optimization

### Content Versioning & Diff

**Feature:** Track content changes over time when re-fetching.

**Implementation:**
- Store multiple archive versions with timestamps
- Generate diffs showing what changed
- "View archive history" in UI
- Configurable retention (keep last N versions)

**Use Cases:**
- Track how article was updated over time
- Detect when page content significantly changed
- Research and fact-checking workflows

### Smart Re-fetch Triggers

**Feature:** Automatically re-fetch content based on heuristics.

**Triggers:**
- HTTP 200 but content significantly shorter (page might be broken)
- ETag/Last-Modified headers indicate change
- Scheduled re-fetch for frequently updated domains (news sites)
- User access triggers background re-check (lazy refresh)

**Configuration:**
- Per-domain refresh policies
- Global scheduling rules
- Cost controls (max re-fetches per month)

### Selective Content Archival

**Feature:** User chooses what to archive (full content, metadata only, URL only).

**Use Cases:**
- Quick reference links (metadata only, no archive)
- Full research articles (complete archival)
- Privacy-sensitive links (URL only)

**Implementation:**
- Archive level: `full`, `metadata`, `url_only`
- Set at capture time or via workspace defaults
- Bulk update existing links

### Content Quality Scoring

**Feature:** Rate quality of extracted content to surface extraction failures.

**Heuristics:**
- Content length (< 100 words might indicate failure)
- HTML/text ratio (too much markup vs. text)
- Image count (no images when expected)
- Readability score

**UI Integration:**
- Show quality score in link list
- Filter "low quality extractions" for manual review
- Automatic re-fetch if quality below threshold

### Multi-format Export

**Feature:** Export archived content in various formats.

**Formats:**
- Markdown (for Obsidian/Notion import)
- EPUB (for e-readers)
- HTML bundle (self-contained with embedded images)
- JSON (for data processing)

**Use Cases:**
- Migrate to other tools
- Offline reading on e-readers
- Backup and portability

### Enhanced Metadata Extraction

**Beyond OpenGraph:**
- JSON-LD structured data
- Schema.org markup
- Article publish/modified dates
- Author information
- Reading time estimates
- Language detection

**Value:**
- Better search filtering (filter by author, date)
- Enhanced LLM context
- Improved deduplication (same article, different URL)

## Strategic Considerations

### Phase 2 Priorities

Based on user needs discussion, Phase 2 should focus on:
1. **Local image archival** - Complete the archival story, prevent image link rot
2. **Content re-fetch** - Ability to improve archives over time
3. **JavaScript rendering** - Handle modern SPA sites

These three features make archival robust and future-proof.

### Performance & Cost Planning

**Storage growth estimation:**
- Average archived page: 100KB (compressed HTML + text + metadata)
- 10,000 links = ~1GB storage
- With images: 500KB average → ~5GB for 10,000 links

**Processing costs:**
- Headless Chrome adds ~2-3 seconds per page + CPU cost
- LLM embeddings (separate feature) dwarf archival costs

**Scalability threshold:**
- V1 approach scales to 100K+ links on modest VPS
- Phase 2 local image storage may require dedicated storage solution
- Phase 3 features (PDF, screenshots) are expensive, should be opt-in

### Multi-user Considerations

When LinkRadar adds multi-user support:
- Shared archive for identical URLs (deduplication)
- Per-user archive preferences (one user wants full, another wants metadata only)
- Workspace-level archival policies
- Cost allocation by user

---

**Note:** Phases are flexible based on user feedback and actual usage patterns. Start with v1, see what users need most, prioritize accordingly.

