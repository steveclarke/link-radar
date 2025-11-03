# LR003 - Future Enhancements

This document captures features and enhancements explicitly deferred from v1 for future development phases.

## Table of Contents

- [Phase 2: Intelligence & Automation](#phase-2-intelligence--automation)
- [Phase 3: Advanced Features](#phase-3-advanced-features)
- [Strategic Future Vision](#strategic-future-vision)

## Phase 2: Intelligence & Automation

### Auto-Analyze Mode

**What:** Automatically trigger AI analysis when user opens extension popup (optional setting)

**Why deferred:** v1 focuses on manual trigger to give users full control and validate usefulness before adding automatic behavior

**User story:** As a power user who analyzes most links, I want analysis to start automatically so I don't have to click the button every time

**Implementation notes:**
- Add user preference toggle in settings
- Default to OFF (respect opt-in philosophy)
- Show cancel button prominently
- Consider smart triggers (only auto-analyze if content is substantial)

### Learning from User Patterns

**What:** Track which suggestions users accept/reject and adapt over time

**Why deferred:** Need baseline data from v1 usage before building learning system. Adds complexity that's not justified without proven usage patterns.

**User story:** As a frequent user, I want the AI to learn my preferences so suggestions improve over time

**Implementation notes:**
- Track acceptance rates per tag and per note
- Store user feedback (accepted/rejected/modified suggestions)
- Feed historical patterns into prompts
- Build tag affinity models (user prefers "JS" over "JavaScript")
- Implement feedback loop to improve prompts

### Content Archival Integration

**What:** Use stored content from content archival feature instead of re-fetching

**Why deferred:** Content archival is a separate feature on its own timeline. Keeping AI analysis independent allows parallel development.

**User story:** As a user with archived content, I want AI to analyze my stored version so it works even if the page goes offline

**Implementation notes:**
- Check if link has archived content before fetching
- Prefer archived content over live fetch
- Fall back to live fetch if no archive exists
- Update prompts to note whether using current or archived content
- Consider re-analysis when content is updated

### Confidence Scoring

**What:** Show confidence levels for each suggestion (high/medium/low)

**Why deferred:** Adds UI complexity. Need to validate that users find basic suggestions useful before adding confidence layers.

**User story:** As a careful user, I want to know which suggestions the AI is confident about so I can focus my review

**Implementation notes:**
- Request probability scores from OpenAI
- Display visual indicators (color, opacity, icons)
- Consider auto-selecting only high-confidence suggestions
- Threshold tuning based on user feedback

### Suggestion History

**What:** Track and display previous AI suggestions for each link

**Why deferred:** Requires additional storage and adds complexity. V1 focuses on current analysis only.

**User story:** As a researcher, I want to see how AI analysis has evolved for a link over time

**Implementation notes:**
- Store analysis results in database
- Show history timeline in extension
- Allow comparison between analyses
- Track which version user accepted
- Consider showing "what changed" diffs

## Phase 3: Advanced Features

### Multi-Model Support

**What:** Let users choose between OpenAI, Claude, local models, or other providers

**Why deferred:** OpenAI GPT-4o-mini provides excellent results at low cost. Adding multiple models increases complexity without clear benefit until we have specific use cases.

**User story:** As a privacy-conscious user, I want to use a local model so my content stays on my machine

**Implementation notes:**
- Abstract AI provider interface
- Add model selection in settings
- Support RubyLLM's multi-provider capabilities
- Compare quality/cost across models
- Allow per-analysis model override
- Consider hybrid approaches (cheap model for quick scan, expensive model for deep analysis)

### Custom Prompt Templates

**What:** User-defined prompt templates with variables

**Why deferred:** Most users will be satisfied with default prompts. Custom prompts require sophisticated UI and understanding of prompt engineering.

**User story:** As a domain expert, I want to customize prompts for my specific field (academic research, code snippets, recipes, etc.)

**Implementation notes:**
- Template syntax with variables ({{title}}, {{content}}, {{existing_tags}})
- Prompt library/marketplace
- Validation and preview
- Version control for prompts
- Share templates between users
- Prompt testing framework

### Bulk/Batch Analysis

**What:** Analyze multiple links at once

**Why deferred:** V1 focuses on single-link workflow. Batch operations add complexity and cost concerns.

**User story:** As a user importing bookmarks, I want to analyze hundreds of links so I can organize my backlog

**Implementation notes:**
- Queue system for batch jobs
- Progress tracking UI
- Cost estimation before running
- Rate limiting to avoid API throttling
- Pause/resume capability
- Background processing with notifications

### Tag Hierarchy Support

**What:** Suggest nested/hierarchical tags (JavaScript > Testing > Jest)

**Why deferred:** Requires tag hierarchy system in core platform first

**User story:** As an organized user, I want hierarchical tags so my JavaScript testing tags are grouped properly

**Implementation notes:**
- Design hierarchy structure
- Update AI prompts to understand hierarchy
- Suggest parent tags when suggesting child tags
- UI for displaying hierarchical tags
- Migration path from flat tags

### Smart Tag Synonyms

**What:** Merge and suggest synonyms (js/javascript, ML/machine-learning)

**Why deferred:** Requires building synonym detection and merging logic. Complex problem that needs dedicated feature.

**User story:** As a user with messy tags, I want the system to recognize "ML" and "machine-learning" are the same

**Implementation notes:**
- Build synonym dictionary
- AI-powered synonym detection
- Suggest tag merges to user
- Handle during analysis (suggest canonical form)
- User confirmation before merging tags

### Advanced Content Extraction

**What:** Use headless browser for JavaScript-rendered content, better text extraction

**Why deferred:** Simple HTTP fetch works for most content. Headless browser adds significant infrastructure complexity and cost.

**User story:** As a user bookmarking modern SPAs, I want full content analysis including JS-rendered content

**Implementation notes:**
- Puppeteer/Playwright integration
- Separate service for browser automation
- Cost/performance considerations
- Fallback to simple fetch
- Smart detection of when to use browser

### A/B Testing for Prompts

**What:** Automatically test different prompt variations and measure effectiveness

**Why deferred:** Need baseline data and multiple users before A/B testing makes sense

**User story:** As a system administrator, I want to continuously improve prompt quality without manual testing

**Implementation notes:**
- Prompt variant framework
- Metric collection (acceptance rates, user ratings)
- Statistical significance testing
- Automatic promotion of winning variants
- Per-user or cohort-based testing

### Feedback Loop

**What:** Explicit "This suggestion was good/bad" rating to improve prompts

**Why deferred:** Need to validate basic feature usefulness before adding rating systems

**User story:** As a user, I want to tell the system when suggestions are bad so it improves

**Implementation notes:**
- Thumbs up/down UI
- Collect feedback with context
- Feed into learning system
- Aggregate feedback for prompt improvement
- Show users how their feedback helped

## Strategic Future Vision

### Integration with Radar Feature

When the radar feature is built, AI analysis can:
- Suggest tags that will create useful radar intersections
- Analyze your radar patterns and recommend tags for better insights
- Auto-tag links to maintain radar accuracy

### Content Summarization

Expand beyond tags/notes to:
- Full article summaries
- Key takeaways extraction
- Quote highlights
- Related link suggestions

### Collaborative Intelligence

For multi-user scenarios:
- Learn from team's collective tagging patterns
- Suggest tags based on how teammates organize similar content
- Team-specific prompt customization
- Shared tag taxonomies

### Cross-Link Intelligence

- Detect similar content already saved
- Suggest merging duplicate links
- Build knowledge graphs between related links
- Temporal analysis (how your interests evolve)

---

**Note:** This is a living document. Features will be promoted to active development based on user feedback, usage patterns, and strategic priorities.

