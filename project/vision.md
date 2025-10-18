# LinkRadar - Vision Document

**Vision:** A personal knowledge radar that captures interesting content effortlessly and surfaces emerging trends in your learning and interests over time.

## Table of Contents

- [LinkRadar - Vision Document](#linkradar---vision-document)
  - [Table of Contents](#table-of-contents)
  - [Problem](#problem)
  - [Solution](#solution)
  - [User Needs](#user-needs)
  - [Future Possibilities](#future-possibilities)
  - [Scope](#scope)
    - [What v1 Delivers](#what-v1-delivers)
    - [What v1 Does NOT Include](#what-v1-does-not-include)

## Problem

Voracious readers and researchers face a fundamental challenge: capturing interesting content is easy, but finding it later and recognizing patterns is nearly impossible.

**The pain points:**

1. **Lost Knowledge** - You know you saved that Biome article six months ago, but where? Was it in Raindrop? Notion? Obsidian? Todoist? An email to yourself? Hours wasted searching again or worse, giving up entirely.

2. **Scattered Silos** - Links spread across different tools mean no single place to search. Each tool seemed like "the answer" at the time, but now your knowledge is fragmented.

3. **Invisible Trends** - You can't see that you've saved five Biome-related articles over three months. Is this tool heating up? Should you invest time learning it now while there's competitive advantage? No way to know.

**The consequences:**

- Wasted time searching again for things you already found
- Missed opportunities to get in early on emerging trends
- Poor prioritization of learning efforts
- Decision paralysis about where to invest time

Current bookmark managers solve "save this link" but completely miss "show me what I'm actually interested in" and "tell me what's trending in my interests."

## Solution

LinkRadar is a personal knowledge repository that makes capturing effortless and intelligence automatic.

**Core philosophy:** 

Make dumping links as easy as breathing, but provide powerful organization for those who want it. The system works at 100% capacity even if you never review anything, but there's extra power when you want to refine.

**How it works:**

1. **Capture anywhere** - Browser extension, CLI tool, or web UI. Drop a link and move on.
2. **Archive automatically** - System saves the page content so links never die on you.
3. **Tag intelligently** - LLM analyzes content and suggests relevant tags automatically.
4. **Search powerfully** - Full-text search across everything you've saved.
5. **Organize optionally** - Accept, reject, or refine LLM suggestions, or run in full auto mode.

Later phases add the "radar" visualization: trend detection and visual dashboards showing what topics are heating up in your interests.

**Key capabilities:**

- **Multi-channel capture** - Get links into the system in under 5 seconds from any context
- **LLM-powered auto-tagging** - Intelligent tag suggestions from day one, with optional review and refinement
- **Content archival** - Preserve page content so you're never searching the internet again for something you already found
- **Full-text search** - Find that article about "microservices vs monoliths" even if you forgot how you tagged it
- **Portable storage** - Your data isn't locked in proprietary formats
- **Future intelligence** - Foundation ready for trend detection and radar visualization

## User Needs

**Primary User** (researchers, developers, continuous learners)

What they need to accomplish:
- Capture a link in under 5 seconds without breaking flow
- Get automatic tag suggestions without manual organization
- Find articles saved weeks or months ago
- Search by tags, keywords, or full content
- Review and refine LLM-suggested tags when they want deeper organization
- See basic stats about their saved content
- Know their links and content are preserved in one searchable place going forward

**Future capabilities they'll need:**
- See what topics are heating up (this month, this year)
- Separate work links from personal interests (workspaces/contexts)
- Identify patterns in their own interests and learning focus areas

## Future Possibilities

See [future.md](future.md) for detailed future enhancements organized by phase.

**Brief overview:**

- **Phase 2**: Radar visualization with trend detection, workspaces for siloing contexts, review/triage queue
- **Phase 3**: Collaborative features, import from other services, advanced search, sharing/export
- **Phase 4**: RSS integration, PWA for mobile, public API for integrations

## Scope

### What v1 Delivers

**Capture Tools:**
- Web UI for viewing, searching, and manually adding links
- CLI tool that accepts URLs and stores them
- Browser extension for one-click capture from any webpage
- API supporting the extension and CLI

**Core Data Model:**
- URL (required)
- Title (scraped from page)
- Date captured (automatic)
- Content snapshot (archived page content)
- Note/description (optional user-provided context)
- Tags (LLM-suggested, user can accept/reject/modify)
- Tag suggestions (stores LLM suggestions and user's tagging patterns)

**Search & Discovery:**
- Basic full-text search using database native capabilities (Postgres full-text search)
- Search by tags or keywords
- View basic stats (number of links, recent additions)

**LLM-Powered Auto-Tagging:**
- Automatically fetch and analyze page content when link is captured
- Generate relevant tags based on content using LLM
- Support both flat tags (Biome, JavaScript, Tooling) and hierarchical structures (JavaScript > Tooling > Biome)
- User can accept, reject, or modify suggested tags
- Option for "full auto mode" where system applies tags automatically without review
- System learns from user's tagging patterns over time (which tags are kept vs rejected)

**Content Preservation:**
- Archive page content at capture time (extract main content using existing tools if straightforward, otherwise store raw HTML)
- Ensures links never become dead ends (also makes it resilient against broken links)

### What v1 Does NOT Include

- Radar visualization showing trends and momentum (Phase 2)
- Multiple workspaces or contexts for siloing links (Phase 2)
- Review/triage queue for refining captures (Phase 2)
- Mobile apps (PWA maybe later, but absolutely no native app store apps)
- AI-powered notifications or alerts
- Collaborative/sharing features (Phase 3)
- Import from other services (Phase 3)
- Advanced search infrastructure like Elasticsearch (Phase 3)

