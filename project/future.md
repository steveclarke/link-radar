# LinkRadar - Future Enhancements

This document captures features and capabilities deferred from v1 for future development phases.

## Table of Contents

- [Phase 2: Intelligence Layer](#phase-2-intelligence-layer)
- [Phase 3: Collaboration & Integration](#phase-3-collaboration--integration)
- [Phase 4: Advanced Features](#phase-4-advanced-features)

## Phase 2: Intelligence Layer

The "radar" capabilities that make LinkRadar special - surfacing trends and patterns in your captured content.

### LLM-Powered Auto-Tagging

**What it does:**
- Automatically fetch and analyze page content when link is captured
- Generate relevant tags based on content
- Learn from user's tagging patterns over time
- Suggest hierarchical tag structures (e.g., "JavaScript > Tooling > Biome")

**User experience:**
- User drops link → system extracts content, generates tags automatically
- User can accept/reject/modify suggested tags
- Option for "full auto mode" where user trusts LLM completely
- System learns which tags user keeps vs rejects

**Why deferred:** Adds complexity and LLM API costs. v1 focuses on establishing the repository foundation.

### Radar Visualization

**What it does:**
- Multiple visual lenses into your saved content showing trends and momentum
- Tag cloud showing frequency of topics
- Sparklines/microcharts showing topic momentum over time  
- Radar chart with hot topics moving toward center as they heat up
- Ability to "dismiss from radar" for topics you've already adopted or aren't interested in

**User scenarios:**
- "Wow, Biome keeps showing up in red in the middle - I should dive deeper"
- "I've saved 8 JavaScript tooling articles this quarter - maybe that's where my interests are shifting"
- "This is what I'm currently working on" - reflective view of your attention and interests

**Why deferred:** Requires content analysis and trend detection algorithms. v1 focuses on capture and search.

### Workspaces & Contexts

**What it does:**
- Separate link collections into contexts: work, personal, specific projects, research areas
- Each workspace has its own radar view
- Toggle between "show everything" and specific context views
- Move links between workspaces during review

**User scenarios:**
- "Show me my JavaScript tooling radar for the work project"
- "What am I personally interested in for side projects?"
- "Keep my philosophy and religious studies separate from technology"

**Why deferred:** Adds data model complexity. v1 establishes single unified repository first.

### Review/Triage Queue

**What it does:**
- Queue of newly captured links that haven't been human-reviewed
- Bulk triage interface for reviewing LLM-suggested tags
- Accept, reject, or modify tags
- Move items to different workspaces
- Delete items that aren't worth keeping
- Option to mark items "review later" during capture

**User experience:**
- Sweet spot between "dump and forget" (for non-organized users) and "everything in its place" (for organized users)
- System works at 100% capacity even without review, but review adds extra power
- Friend with 100 open tabs can dump links fast and close tabs, knowing they're safely captured

**Why deferred:** Depends on auto-tagging and workspaces features. v1 focuses on manual organization.

## Phase 3: Collaboration & Integration

Features enabling sharing, team use, and importing existing link collections.

### Collaborative Features

**What it does:**
- Shared workspaces where teams can collectively save and tag links
- Shared radar views showing team interests and trends
- "Link dump for colleagues" - central place for project-related resources

**Use cases:**
- Development team maintaining shared technology research
- Project-specific link collections accessible to all contributors
- Seeing what your team is collectively interested in

**Why deferred:** Requires multi-user architecture, permissions, and sharing infrastructure.

### Import from Other Services

**What it does:**
- Import existing bookmarks from Raindrop, Pocket, Pinboard, browser bookmarks
- Preserve existing tags and metadata where possible
- One-time migration to consolidate scattered link collections

**Why deferred:** Each service has different export formats. v1 focuses on capturing new links going forward.

### Advanced Full-Text Search

**What it does:**
- Elasticsearch or similar for sophisticated search
- Fuzzy matching, relevance ranking
- Search operators (AND, OR, NOT)
- Saved searches

**Why deferred:** Database native full-text search (Postgres) is sufficient for v1. Add advanced search as corpus grows.

### Sharing & Export

**What it does:**
- Export your links in various formats (JSON, CSV, markdown)
- Share individual links or collections
- Generate public "reading lists" from your saved content
- API for programmatic access

**Why deferred:** v1 focuses on personal use. Sharing adds complexity around privacy and access control.

## Phase 4: Advanced Features

Lower priority enhancements and integrations.

### RSS/Feed Integration

**What it does:**
- Subscribe to RSS feeds
- Automatically capture and tag interesting articles from feeds
- Integrate feed content into radar trend detection

**Why considered:** Could automate discovery of trending topics in your areas of interest.

**Why lowest priority:** RSS is somewhat legacy technology. Manual capture likely sufficient.

### PWA for Mobile Access

**What it does:**
- Progressive Web App providing mobile-friendly interface
- Add to home screen on iOS/Android
- Responsive design for phone/tablet viewing and capture

**Why considered:** Capture links on mobile devices.

**Why deferred:** Web UI should work on mobile browsers for v1. PWA adds polish later.

**Why absolutely NOT native apps:** App stores are painful for independent developers. Not worth the hassle.

### Public API & Integrations

**What it does:**
- RESTful API for third-party integrations
- Webhooks for automation
- Integration with IFTTT, Zapier, etc.
- MCP server for LLM agent access

**Why deferred:** v1 has API for CLI/extension. Public API requires documentation, versioning, and support.

### Full Page Content Rendering

**What it does:**
- Store rendered page snapshots, not just HTML/text
- Preserve images, layout, formatting
- Screenshot archival

**Why deferred:** Storage intensive. Text content sufficient for v1 search and archival needs.

