# LR005 - Content Archival & Storage: Requirements

## Overview

This document defines the requirements for automatically capturing and preserving web page content when links are saved to LinkRadar. Content archival provides insurance against link rot, enables full-text search, and powers LLM-based semantic search features.

**Vision Reference:** See [vision.md](vision.md) for business context and strategic goals.

## Table of Contents

- [1. User Stories & Business Needs](#1-user-stories--business-needs)
- [2. Core System Capabilities](#2-core-system-capabilities)
- [3. Business Data Requirements](#3-business-data-requirements)
- [4. Business Rules & Logic](#4-business-rules--logic)
- [5. User Experience Requirements](#5-user-experience-requirements)
- [6. Quality Attributes & Constraints](#6-quality-attributes--constraints)
- [7. Integration Touchpoints](#7-integration-touchpoints)
- [8. Development & Testing Approach](#8-development--testing-approach)
- [9. Success Criteria](#9-success-criteria)
- [10. Constraints & Assumptions](#10-constraints--assumptions)

## 1. User Stories & Business Needs

### 1.1 End Users (Link Savers)

**As an end user, I want:**

- **Persistent Content**: Content from saved links to remain accessible even when original URLs die, change, or go behind paywalls, so I don't lose valuable knowledge I've curated
  
- **Searchable Archive**: Full-text search capability across archived content so I can find information based on what I remember reading, not just tags or titles

- **Readable Fallback**: Clean, readable archived content when original websites are unavailable, so my bookmark collection remains useful over time

- **Transparent Process**: Clear visibility into archive status (pending, processing, success, failed) so I know which links have been preserved

- **Non-Blocking Capture**: Link saving to complete immediately without waiting for archival, so the capture workflow stays fast

- **Graceful Failures**: Archival failures to not prevent link capture, so I can always save links even if content extraction doesn't work

## 2. Core System Capabilities

### 2.1 Automatic Content Archival

**The system must:**

- Automatically trigger content archival whenever a link is saved to LinkRadar
- Process archival asynchronously in the background without blocking link creation
- Create an archive record immediately when a link is created, with initial status tracking
- Queue a background job to fetch and extract content after link creation

### 2.2 Content Extraction Pipeline

**The system must:**

- Fetch web page content via HTTP/HTTPS requests
- Extract clean main article content, removing ads, navigation, footers, and clutter
- Extract rich metadata including page title, description, and preview images
- Store both cleaned HTML (for display) and plain text (for search and LLM embeddings)
- Sanitize HTML content to remove potentially dangerous elements

### 2.3 Status Tracking & Visibility

**The system must:**

- Track archive status through multiple states: pending, processing, completed, failed
- Update status as archival progresses through the pipeline
- Store error_reason in transition metadata for failed archives (blocked, invalid_url, network_error, etc.)
- Store content_type in archive metadata for completed archives (html, pdf, image, video, other)
- Store error messages when archival fails, providing context for debugging
- Make status visible through API for future UI integration

### 2.4 Failure Handling & Retry Logic

**The system must:**

- Retry failed fetches automatically for network timeout errors
- Use exponential backoff between retry attempts (immediate, +2s, +4s)
- Fail immediately for non-retryable errors (404, 5xx server errors, etc.)
- Mark archive as failed after exhausting retry attempts
- Never block or fail link creation due to archival issues

### 2.5 Security & Safety

**The system must:**

- Validate URLs before attempting to fetch content
- Block requests to private IP ranges (prevent SSRF attacks)
- Only allow HTTP and HTTPS URL schemes
- Check file size before downloading, rejecting content over 10MB
- Follow redirects up to a maximum of 5 hops
- Identify itself with a proper User-Agent string including contact information

## 3. Business Data Requirements

### 3.1 Archive Records

**Each archive record must capture:**

- **Association**: One-to-one relationship with a link record
- **Content Data**: Cleaned HTML content and extracted plain text
- **Metadata**: Page title, description, preview image URL, OpenGraph data, content_type
- **Status Information**: Current archival state (pending, processing, completed, failed)
- **Error Details**: Simple error message and error_reason when archival fails
- **Timestamps**: When content was successfully fetched

### 3.2 Metadata Storage

**The system must store:**

- **OpenGraph Metadata**:
  - og:title (page title)
  - og:description (summary)
  - og:image (preview image URL)
  - og:type (content type: article, website, etc.)
  - og:url (canonical URL)

- **Fallback Metadata**:
  - HTML meta description (when OpenGraph unavailable)
  - Canonical link tag URL (when different from submitted URL)

### 3.3 Relationship to Links

**Archive records must:**

- Belong to exactly one link record
- Be automatically deleted when the associated link is deleted (cascade delete)
- Be created immediately when a link is created (eager creation, not lazy)

## 4. Business Rules & Logic

### 4.1 Pre-Validation Rules

**Before enqueueing archival job:**

1. **URL Scheme Validation**: Only HTTP and HTTPS schemes are allowed
2. **Private IP Detection**: URLs resolving to private IP ranges must be blocked
3. **Immediate Status Update**: If validation fails, set archive status to `blocked` without creating a job

### 4.2 Fetch Execution Rules

**During content fetching:**

1. **Size Check First**: Check Content-Length header before downloading; reject if >10MB
2. **Timeout Enforcement**: Apply 10-second connect timeout and 15-second read timeout to all attempts
3. **Redirect Following**: Follow HTTP redirects up to 5 hops; fail if exceeds limit
4. **User-Agent Identification**: Send requests with format "LinkRadar/1.0 (+contact_url)" where contact_url is configurable

### 4.3 Retry Logic Rules

**When fetch fails:**

1. **Retry Only Timeouts**: Only network/connection timeout errors trigger retries
2. **Immediate Failure**: 404, 5xx errors, DNS failures, rate limits fail immediately without retry
3. **Backoff Timing**: Wait 2 seconds before attempt 2, wait 4 seconds before attempt 3
4. **Same Timeouts**: All retry attempts use the same timeout settings (10s/15s)
5. **Maximum Attempts**: Fail permanently after 3 total attempts

### 4.4 Success Criteria

**Archive is marked successful when:**

1. HTTP fetch completes without errors
2. Content extraction produces any result (no minimum content requirements)
3. Any extracted content is considered valid (no quality thresholds)

**Archive status remains `processing` during:**
- Initial fetch attempt
- All retry attempts and backoff delays

### 4.5 Content Extraction Rules

**During extraction:**

1. **Best Effort Philosophy**: Accept whatever content is extracted, no validation
2. **Metadata Priority**: Prefer OpenGraph metadata over HTML meta tags over fallbacks
3. **Sanitization**: Apply standard HTML sanitization to remove scripts and dangerous elements
4. **Dual Format Storage**: Always generate both HTML and plain text versions

## 5. User Experience Requirements

### 5.1 Non-Blocking Workflow

**Users must experience:**

- Immediate link creation without waiting for archival to complete
- Fast capture workflow regardless of archival complexity
- Clear status indication when viewing links (archived, processing, failed)

### 5.2 Graceful Degradation

**When archival fails:**

- Link remains fully functional with URL, tags, and notes
- Users can still search and find the link via tags and notes
- Failure doesn't break or block any part of the link capture workflow

## 6. Quality Attributes & Constraints

### 6.1 Security Requirements

**SSRF Prevention:**
- Block all private IP ranges: 10.0.0.0/8, 127.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12, 169.254.0.0/16
- Validate IP addresses before making HTTP requests
- Reject URLs with non-HTTP/HTTPS schemes

**Content Security:**
- Sanitize HTML using standard sanitization library settings
- Remove script tags, event handlers, and XSS vectors
- Store sanitized content only

**Network Security:**
- Enforce timeout limits to prevent hung connections
- Limit file sizes to prevent resource exhaustion
- Limit redirect chains to prevent redirect loops

### 6.2 Reliability Requirements

**Failure Handling:**
- Archival failures must never prevent link creation
- System must gracefully handle network failures, timeouts, and invalid content
- Failed archives must store diagnostic information for debugging

**Data Integrity:**
- Archive records must always exist for every link (created immediately)
- Cascade deletion must maintain referential integrity
- Status transitions must be atomic and consistent

### 6.3 Performance Expectations

**For v1:**
- No specific performance requirements
- Processing speed depends on external website response times
- Background job processing prevents user-facing performance impact
- Single-user scale with low volume (no optimization needed)

### 6.4 Scalability Considerations

**For v1:**
- System designed for single-user personal use
- No concurrency limits needed for job processing
- Default job queue behavior is sufficient
- Future multi-user scenarios deferred to later phases

### 6.5 Compliance & Privacy

**For v1:**
- No compliance requirements (GDPR, data retention policies, etc.)
- Self-hosted single-user deployment
- User owns all data on their own infrastructure

## 7. Integration Touchpoints

### 7.1 Link Management System

**Dependencies:**
- Requires link records to exist before creating archives
- Archive creation triggered by link creation event
- Archive lifecycle tied to link lifecycle (cascade delete)

### 7.2 Background Job Queue

**Integration:**
- Uses GoodJob (PostgreSQL-backed Active Job) for background processing
- Jobs enqueued asynchronously after link creation
- Default GoodJob configuration sufficient for v1 scale

### 7.3 Future Feature Integration

**Archive data available to:**
- Full-text search features (future)
- LLM embedding generation (future)
- Semantic search capabilities (future)
- Web UI display (future)

**Separation from AI Analysis:**
- AI Analysis (LR003) uses separate content fetch mechanism
- Extension sends client-extracted content for AI analysis
- Content archival always fetches server-side for consistency
- Acceptable for extension to fetch content twice (AI + archive)

## 8. Development & Testing Approach

### 8.1 Development Approach

**Implementation sequence:**
1. Database schema for archive records
2. Pre-validation logic (URL schemes, private IPs)
3. Background job implementation
4. HTTP fetch with timeouts and redirects
5. Content extraction pipeline
6. Retry logic and error handling
7. Status tracking and updates

**Technology choices:**
- Ruby gems: metainspector, ruby-readability, loofah, faraday, addressable
- PostgreSQL for data storage
- GoodJob for background job processing

### 8.2 Testing Strategy

**For v1:**
- Manual testing only (no automated test framework yet)
- Test with variety of real-world URLs (articles, blogs, documentation, product pages)
- Verify successful archival for common page types
- Verify graceful failure handling
- Verify status transitions through the pipeline

**Test scenarios:**
- Normal article page (success case)
- 404 not found (immediate failure)
- Timeout scenario (retry logic)
- Large file >10MB (size rejection)
- Private IP URL (blocked)
- Redirect chain (follow redirects)

## 9. Success Criteria

### 9.1 Functional Success

**The feature is complete when:**

1. **Content Archival Works**: Successfully archives content for common page types (news articles, blog posts, documentation, product pages)

2. **Graceful Failures**: Handles failures without breaking link capture workflow

3. **Data Format**: Stores content in usable format (cleaned HTML + plain text) that future features can consume

4. **Status Tracking**: Accurately tracks and updates archive status throughout pipeline

5. **Error Reporting**: Stores meaningful error messages when archival fails

### 9.2 Acceptance Criteria

**Must demonstrate:**

- Link saved → archive record created immediately with `pending` status
- Background job processes archive asynchronously
- Successful archival updates status to `success` and stores content
- Failed archival after retries updates status to `failed` with error message
- Blocked URLs marked as `blocked` without job creation
- Private IP requests prevented (SSRF protection working)
- Files >10MB rejected before download
- Network timeouts trigger retry logic
- Cascade delete removes archive when link deleted

### 9.3 Quality Success

**Must demonstrate:**

- No impact to link capture speed (archival is truly async)
- HTML sanitization removes dangerous content
- Dual format storage (HTML + text) works correctly
- Metadata extraction captures OpenGraph data when present
- User-Agent properly identifies LinkRadar in requests

## 10. Constraints & Assumptions

### 10.1 Scope Constraints

**Explicitly NOT in v1:**
- JavaScript rendering for SPA sites (requires headless browser)
- Local image storage (images stored as URLs only)
- Content re-fetch/update capability
- Content compression
- TTL/expiration policies
- Domain-level rate limiting
- PDF generation from archives
- Full page screenshots
- Archive.org integration
- Detailed retry attempt tracking in UI
- Frontend UI for viewing archives
- Full-text search implementation

### 10.2 Known Limitations

**Acceptable limitations for v1:**

- **Authentication-Walled Content**: Cannot archive content behind login/paywalls (backend has no session)
- **Heavy SPA Sites**: Simple HTTP fetch may miss content on JavaScript-heavy sites
- **Image Link Rot**: Images stored as URLs only, vulnerable to external image links dying
- **No Re-Fetch**: First archive is permanent; no way to update or improve it later
- **Single Attempt for Most Errors**: Only network timeouts retry; 404s, 5xx errors fail immediately

### 10.3 Assumptions

**Design assumptions:**

1. **Single User**: System designed for personal use by one user
2. **Low Volume**: User saves links one at a time throughout day, not bulk importing thousands
3. **Manual URL Validation**: Link-level URL validation/normalization handled separately (not part of content archival)
4. **Backend Only**: No frontend implementation in v1; purely infrastructure
5. **External Dependencies**: Relies on external Ruby gems for extraction (metainspector, ruby-readability, loofah)
6. **PostgreSQL Full-Text Search**: Future search features will use PostgreSQL's native FTS capabilities
7. **Best Effort Sufficient**: Imperfect content extraction is acceptable; tags and notes are primary search signals

### 10.4 Future Considerations

**Phase 2 priorities** (from vision):
- JavaScript rendering capability
- Local image archival
- Content re-fetch functionality
- Content compression

**Architecture supports:**
- Adding re-fetch without schema changes (update existing archive record)
- Adding multiple archive versions per link (future versioning capability)
- Improving extraction algorithms without breaking existing archives

---

**References:**
- Vision: [vision.md](vision.md)
- Future Enhancements: [future.md](future.md)
- Feature Development Process: `~/.local/share/dotfiles/ai/guides/feature-development-process.md`

