# LinkRadar - Vision Discussion Summary

This document summarizes the complete conversation during vision planning, including technical context, decisions made, and rationale.

## Table of Contents

- [Core Problem Identified](#core-problem-identified)
- [Current Workflow & Pain Points](#current-workflow--pain-points)
- [Solution Approach](#solution-approach)
- [Key Concepts](#key-concepts)
- [User Needs & Scenarios](#user-needs--scenarios)
- [Technical Considerations](#technical-considerations)
- [Scope Decisions](#scope-decisions)
- [Future Roadmap](#future-roadmap)
- [Open Questions](#open-questions)

## Core Problem Identified

**Primary pain:** Voracious readers and researchers capture interesting content throughout the day, but can never find it later or recognize emerging trends in their learning.

**Three specific consequences:**

1. **Lost Knowledge** - Wasted hours trying to re-find "that article about Biome I saved somewhere" or giving up and re-searching the entire internet
2. **Scattered Silos** - Links spread across Notion, Obsidian, Raindrop, Delicious, Todoist, email-to-self, with no single searchable repository
3. **Invisible Trends** - No way to see that Biome kept appearing in saved content over 3 months, signaling it's time to invest learning effort for competitive advantage

**Real-world impact:**
- Time waste from re-searching
- Missed opportunities to be early adopter of valuable technologies/techniques
- Poor prioritization of learning and professional development efforts
- Decision paralysis about where to invest limited time

**Example scenario:** Biome in 2023 appeared interesting but not ready for prime time. Over time, it kept appearing in Hacker News and various articles. If user could have seen this momentum building on a "radar" view, they would have known "this is heating up, time to dive deeper now while there's competitive advantage in being early."

## Current Workflow & Pain Points

**Existing workflow:**

User currently uses Todoist with web clipper extension to quickly capture links as tasks. They tag items with "today" for later processing. They've created a Cursor agent workflow that:

1. Uses Todoist CLI to fetch today's tasks
2. For each link, fetches content and summarizes it
3. Saves summaries to Obsidian daily notes in markdown format
4. Marks tasks complete in Todoist

**What works:**
- Fast capture (web clipper is quick)
- Links eventually get into searchable markdown files (Obsidian vault)
- Technology-agnostic storage format (portable markdown)
- LLM helps with summarization

**What doesn't work:**
- Manual, time-consuming workflow (have to trigger the agent, review each item)
- No trend detection or pattern recognition
- Still requires organizing/tagging manually or just dumping in daily notes
- No way to see "what topics am I actually interested in?"
- Content siloed in date-based daily notes, hard to find by topic later

**Tools tried and abandoned:**
- Notion - too heavy, proprietary lock-in
- Obsidian - good for notes, not purpose-built for link management with trends
- Delicious (back in the day) - dead service
- Raindrop - another silo
- Todoist - not designed for knowledge management, just task management

## Solution Approach

**Core philosophy:** "Make it as easy as breathing to capture a link, but provide powerful organization for those who want it."

**Key insight:** System must work at 100% capacity even if user never reviews/organizes anything (for non-organized users like "friend with 100 browser tabs"), but provide extra power for users who want to refine and organize.

**Two user archetypes:**
1. **Non-organizer** - Just wants to dump links fast, close tabs, trust they can find things later. Never wants to be forced to organize up front.
2. **Organizer** - Likes to organize but doesn't want to be forced to organize during capture. Wants ability to review and refine later.

LinkRadar serves both by decoupling capture (fast and easy) from organization (optional and powerful).

**Differentiator from existing bookmark managers:** The "radar" aspect - intelligent visualization showing trends, momentum, and patterns in saved content over time.

## Key Concepts

### The Radar

**Visualization approaches discussed:**
- Tag cloud (frequency-based sizing)
- Sparklines/microcharts (momentum over time)
- Actual radar chart with hot topics migrating toward center as they heat up
- Color coding (e.g., red for hot topics)

**What the radar shows:**
- "What topics are heating up?" - Biome appearing more frequently over time
- "What am I actually interested in?" - Reflective view of user's attention
- "What should I prioritize learning?" - Competitive advantage from being early

**Interaction:**
- Ability to "dismiss from radar" for topics already adopted or not interesting
- Toggleable views (all contexts, just work, just personal)
- Historical views (this month, this quarter, this year)

**Example insight:** User discovers 90% of their bookmarks are JavaScript tooling-related, revealing hidden career interests they hadn't consciously recognized.

### Workspaces/Contexts

**Purpose:** Silo link collections by context to prevent noise and enable focused radar views.

**Examples:**
- Work project A
- Personal side projects
- Religious/philosophy studies (separate from technology)
- Research area X

**Key capability:** Toggle between "show everything" (global radar) and specific context views.

### Capture Everywhere

**Goal:** User should be able to dump a link in under 5 seconds from any context.

**Capture mechanisms:**
- Browser extension (one-click from any webpage)
- CLI tool (for command-line workflows and LLM agent integration)
- Web UI (manual entry and management)
- Future: MCP server (for LLM agent direct access)
- Future: Mobile (PWA only - absolutely no native apps, user hates app stores)

**Why multiple mechanisms matter:** User works in different contexts throughout the day. If any context makes capture friction-full, they'll stop using the system.

### LLM-Powered Intelligence (Future)

**Auto-tagging workflow:**
1. User drops link
2. System fetches page content
3. LLM analyzes content and suggests tags
4. User can accept/reject/modify (or run in full auto mode)
5. System learns from user's accepts/rejects over time

**Tag suggestions:**
- Flat tags (Biome, JavaScript, Tooling)
- Hierarchical tags (JavaScript > Tooling > Biome)
- Learns user's preferred tagging vocabulary

**Review queue:**
- Newly captured items flagged for review
- Bulk triage interface
- Accept/reject tags, move between workspaces, delete, or skip review entirely

## User Needs & Scenarios

**Primary user:** The individual using LinkRadar (initially creator scratching their own itch, but eventually any researcher/developer/continuous learner).

**Concrete needs:**

1. **Capture in under 5 seconds** - No friction during the moment of discovery
2. **Find articles saved months ago** - "That Biome thing I read in March"
3. **Search by tags** - "Show me everything tagged Biome"
4. **Full-text search** - Find content even when tags fail
5. **See trending topics** - "What's heating up this month/quarter/year?"
6. **Review and organize later** - Accept/reject tags, move between contexts, delete
7. **Preserve content** - Links die; need archived content

**Success scenario:** Friend with 100 open browser tabs can confidently close tabs because they know links are safely captured and searchable in LinkRadar. No more tab anxiety.

**Use case - early adoption advantage:**
- User sees Biome appearing repeatedly in their radar
- Realizes "this is heating up, I should learn it now"
- Gets in early, gains competitive advantage in job market
- Makes informed decisions about where to invest learning time

**Use case - self-discovery:**
- User bookmarks things naturally over months
- Radar reveals 80% of bookmarks are JavaScript tooling-related
- User realizes hidden career interest or pivot direction
- Data-driven career decisions

## Technical Considerations

### Storage & Data Model

**V1 data model:**
```
Link {
  url: string (required, unique)
  title: string (scraped from page)
  date_captured: timestamp (automatic)
  content_snapshot: text (archived page content)
  note: text (optional user-provided context)
  tags: array (manual entry in v1)
}
```

**Storage philosophy:** Technology-agnostic, portable formats preferred. Ability to export/migrate data is essential (learned from Obsidian markdown approach).

**Future additions:**
- workspace_id (for contexts)
- suggested_tags (LLM-generated)
- reviewed: boolean
- dismissed_from_radar: boolean
- view_count, last_accessed (usage tracking for radar intelligence)

### Content Archival

**Decision:** Archive page content at capture time so links never become dead ends.

**V1 approach:**
- Look for existing tools to extract main content (Obsidian web clipper as reference example)
- If existing tools make it straightforward, extract clean text content
- If not straightforward, store raw HTML for now
- Future pass can process raw HTML to extract main content

**Rationale:** Links die constantly. Being able to search archived content is critical value proposition.

### Search Implementation

**V1 approach:** Use database native full-text search capabilities (Postgres full-text search mentioned specifically).

**Rationale:** Sufficient for v1 corpus size. Postgres FTS handles:
- Full-text search across content and notes
- Tag matching
- Basic ranking

**Future consideration:** Elasticsearch or similar for advanced search when corpus grows large or sophisticated ranking becomes important.

### Database Choice

**Mentioned:** Postgres preferred for native full-text search capabilities.

**Not decided:** This is spec-level decision. Vision simply notes that basic database-native search is sufficient for v1.

### LLM Integration (Future)

**Discussed but deferred:**
- Which LLM API to use (OpenAI, Anthropic, local models?)
- Cost implications of auto-tagging every captured link
- Learning mechanism for tag suggestions
- Full auto mode vs. review mode

**Rationale for deferral:** Foundation must work first (capture, store, search). Intelligence layer comes after repository is established and user is consistently using it.

### Browser Extension Architecture

**V1 requirement:** Browser extension that can capture current page and send to API.

**Not decided:**
- Which browsers to support (Chrome, Firefox, Safari?)
- Extension manifest v2 vs v3
- How to handle authentication

**Reference mentioned:** Obsidian web clipper as potential example for content extraction.

### CLI Tool

**V1 requirement:** Command-line tool that accepts URL and stores it.

**Not decided:** CLI framework/implementation language (but should be lightweight and cross-platform).

### API Design

**V1 requirement:** API to support browser extension and CLI tool.

**Basic operations needed:**
- POST /links (create new link)
- GET /links (list/search links)
- GET /links/:id (retrieve specific link)
- PUT /links/:id (update tags, notes)
- DELETE /links/:id (remove link)

**Not decided:** REST vs GraphQL, authentication mechanism, rate limiting.

**Future consideration:** Public API requires versioning, documentation, and support. V1 API is internal only.

## Scope Decisions

### Why These Features Are In V1

**Web UI with search:**
- **Rationale:** User needs to view and search their links. This is table stakes.
- **Concrete deliverable:** View all links, search by tags/keywords/full-text, see basic stats (count, recent additions)

**CLI tool:**
- **Rationale:** Enables LLM agent integration in creator's current workflow. Creator already uses CLI-based workflows (Todoist CLI example).
- **Concrete deliverable:** Single command to add a URL with optional tags and notes
```bash
linkradar add https://example.com/article --tags biome,javascript --note "Interesting approach to linting and formatting"
```

**Browser extension:**
- **Rationale:** Creator captures links while browsing. This is primary capture mechanism during daily research.
- **Concrete deliverable:** One-click capture from any webpage sends to API

**Page content archival:**
- **Rationale:** Links die constantly. Archival transforms "bookmark manager" into "knowledge repository."
- **Decision evolution:** Initially not in v1, but determined this is critical value. Bumped to v1.
- **Concrete deliverable:** Store page content (main text if easy, raw HTML otherwise) at capture time

**Basic full-text search:**
- **Rationale:** Without search, it's just a list. Search makes repository useful.
- **Decision evolution:** Initially "consider for v1", but realized it's essential with content archival.
- **Concrete deliverable:** Database-native full-text search (Postgres) across content, titles, and notes

**Manual tags:**
- **Rationale:** Some organization is essential. Manual tags in v1 keep it simple while LLM complexity is deferred.
- **Concrete deliverable:** Users can add comma-separated tags during capture or edit later

### Why These Features Are NOT In V1

**LLM-powered auto-tagging:**
- **Deferred to Phase 2**
- **Rationale:** Adds complexity (LLM API integration, cost management, learning algorithm). V1 focuses on establishing repository foundation. Users can add tags manually initially.

**Radar visualization:**
- **Deferred to Phase 2**
- **Rationale:** This is the killer feature, but it requires trend detection algorithms and content analysis. Must have content corpus first. V1 establishes the corpus.

**Workspaces/contexts:**
- **Deferred to Phase 2**
- **Rationale:** Adds data model complexity. V1 establishes single unified repository. Users can use tag prefixes as workaround initially (work-biome, personal-philosophy).

**Review/triage queue:**
- **Deferred to Phase 2**
- **Rationale:** Depends on auto-tagging. No auto-suggestions means no review needed in v1.

**Mobile apps:**
- **Explicitly rejected for native apps**
- **Rationale:** App stores are painful for independent developers - submission, maintenance, and fees create unnecessary friction
- **Future consideration:** PWA (Progressive Web App) only, and even that is Phase 4

**AI-powered notifications:**
- **Explicitly rejected**
- **Rationale:** No nagging. System should surface insights when users view radar, not push notifications.

## Future Roadmap

### Phase 2: Intelligence Layer

**Priority features:**
1. LLM-powered auto-tagging with accept/reject workflow
2. Radar visualization (tag cloud, sparklines, radar chart)
3. Workspaces/contexts for siloing collections
4. Review/triage queue

**Rationale:** This phase delivers the unique value proposition - the "radar" that surfaces trends and patterns. Phase 1 establishes the foundation; Phase 2 adds the intelligence.

### Phase 3: Collaboration & Integration

**Priority features:**
1. Collaborative features (shared workspaces, team radars)
2. Import from other services (Raindrop, Pocket, browser bookmarks)
3. Advanced full-text search (Elasticsearch)
4. Sharing/exporting capabilities

**Rationale:** Once personal use is solid, enable team use and data migration from legacy tools.

**Context:** Maintaining "link dump for colleagues" is a clear use case for collaboration features.

### Phase 4: Advanced Features

**Lower priority features:**
1. RSS/feed integration
2. PWA for mobile access
3. Public API for third-party integrations
4. Full page rendering/screenshot archival

**Rationale:** Nice-to-haves that add polish but aren't core to solving the primary problem.

**Context:** RSS feeds are somewhat legacy technology - acknowledged value but low priority.

## Open Questions

### For Requirements Phase

1. **Search ranking:** How should search results be ranked? Most recent? Most relevant? Most viewed?
2. **Tag structure:** Free-form tags, hierarchical tags, or both?
3. **Duplicate detection:** What happens if user saves same URL twice?
4. **Edit history:** Should system track when tags/notes are modified?
5. **Bulk operations:** Import existing bookmarks? Bulk tagging? Bulk delete?

### For Spec Phase

1. **Database choice:** Postgres confirmed or consider alternatives?
2. **Content extraction:** Which library/tool for extracting main content from HTML?
3. **Browser extension platform:** Manifest v2 vs v3? Which browsers to support first?
4. **CLI implementation:** Language/framework? Package management?
5. **API authentication:** JWT? Session-based? API keys?
6. **Deployment:** Self-hosted only? Offer hosted version? Docker container?
7. **LLM future-proofing:** Structure database/API to accommodate future auto-tagging without schema changes?

### For Implementation Phase

1. **Content extraction:** Test Obsidian web clipper approach vs. existing libraries (Readability, Trafilatura, etc.)
2. **Postgres full-text search:** Test performance and relevance with realistic corpus size
3. **Browser extension:** Build Chrome extension first, then port to Firefox?
4. **CLI packaging:** How to distribute (npm, pip, cargo, standalone binary)?

### Strategic Questions

1. **Open source timing:** Release as open source from day 1 or after v1 is working?
2. **SaaS possibility:** If this becomes popular, offer hosted version? Freemium model?
3. **Community:** Develop in public? Where to share progress (GitHub, Twitter, Hacker News)?
4. **Branding:** Domain registration and final naming confirmation

## Project Context

**Development approach:**
- Personal project scratching a real itch
- Plan to develop in public and open source
- Could become SaaS later but not primary goal for v1
- Small team (initially solo developer)

**Technical context:**
- CLI-first workflows are important
- LLM agent integration is a priority (Cursor, custom prompts)
- Values portable, technology-agnostic data formats
- Strong preference for avoiding mobile app stores
- Current integrations with Todoist, Obsidian, command-line tools

**Target users beyond creator:**
- Developers and researchers (primary)
- Anyone who reads voraciously and wants to track interests
- "Friend with 100 browser tabs" archetype (non-organized users)
- Continuous learners wanting to identify skill gaps and trends

**Success metrics (implicit):**
- Daily usage (vs. abandoned like previous tools)
- Find articles saved months ago in under 30 seconds
- Users gain insights about their interests they didn't consciously know
- Users identify trending topics early enough to gain competitive advantage
- "Friend with 100 tabs" archetype closes tabs confidently and uses the system

## Naming Considerations

**Original name:** "Topic Radar" - discovered to have conflicts with existing meanings during vision phase.

**Requirement:** User wants to keep "radar" in the name as it's core to the concept.

### Radar-Focused Name Options

**LinkRadar**
- Straightforward and descriptive
- Clearly communicates: link management + radar detection
- Available domains likely: linkradar.io, linkradar.dev
- Natural usage: "Check your LinkRadar to see what's trending"

**ContentRadar**
- Emphasizes the broader knowledge aspect beyond just links
- Works well: "Your personal content radar"
- Slightly more professional sounding

**SaveRadar**
- Short, action-oriented (saving + radar)
- Friendly and approachable
- Easy to remember

**ReadRadar**
- Focuses on the reading/research aspect
- "What's on your ReadRadar this week?"
- Alliterative, memorable

**ResearchRadar**
- More professional, academic tone
- Clearly positions for researchers and developers
- Might feel too formal for personal tool

**KnowledgeRadar**
- Emphasizes the knowledge management aspect
- Positions as more than just bookmarks
- Longer but descriptive

### Other Radar Metaphors

**Blip** (radar blips)
- Short, memorable single word
- Could work: "Save it to Blip"
- Domain availability likely good

**Sonar**
- Single word, very memorable
- Perfect metaphor: detecting approaching signals
- Domain might be challenging but .dev/.io alternatives

### Recommendation

**Top choice: LinkRadar**
- Balances descriptive clarity with memorability
- "Radar" clearly communicates the trending/momentum feature
- "Link" makes it immediately understandable what it does
- Not too corporate, not too casual - just right for open source tool

## Next Steps

After vision approval:

1. **Requirements Document** - Detail user stories, workflows, data requirements, acceptance criteria
2. **Technical Specification** - Database schema, API endpoints, content extraction approach, architecture
3. **Implementation Plan** - Phase 1 sequencing, effort estimation, validation approach

**Estimated complexity:** Medium-sized project. V1 is achievable as solo developer project. Future phases may benefit from contributors if open-sourced.

