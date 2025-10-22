# LinkRadar Project Workflow

## Overview

This document describes the project management workflow for LinkRadar. Currently using Superthread for task management and planning.

## Table of Contents

- [LinkRadar Project Workflow](#linkradar-project-workflow)
  - [Overview](#overview)
  - [Table of Contents](#table-of-contents)
  - [Project Structure](#project-structure)
    - [Workspace Organization](#workspace-organization)
    - [LinkRadar Space Boards](#linkradar-space-boards)
  - [Hierarchy and Card Relationships](#hierarchy-and-card-relationships)
    - [Project Hierarchy](#project-hierarchy)
    - [Card Linking Rules](#card-linking-rules)
  - [Board Details](#board-details)
    - [1. Domains Board](#1-domains-board)
    - [2. Modules Board](#2-modules-board)
    - [3. Planning Board](#3-planning-board)
    - [4. Development Board](#4-development-board)
  - [Planning Documents in Monorepo](#planning-documents-in-monorepo)
    - [Location](#location)
    - [Document Types](#document-types)
    - [Why Planning Docs in Monorepo?](#why-planning-docs-in-monorepo)
    - [Superthread Card → Planning Doc Link](#superthread-card--planning-doc-link)
  - [Complete End-to-End Workflow](#complete-end-to-end-workflow)
    - [Phase 1: Planning (Planning Board)](#phase-1-planning-planning-board)
    - [Phase 2: Development (Development Board)](#phase-2-development-development-board)
    - [Phase 3: Shipping \& Module Updates](#phase-3-shipping--module-updates)
  - [Tagging Strategy](#tagging-strategy)
    - [Priority Tags](#priority-tags)
    - [Type Tags](#type-tags)
    - [Status Tags](#status-tags)
  - [Common Scenarios](#common-scenarios)
    - [Starting a New Feature](#starting-a-new-feature)
    - [Quick Bug Fix](#quick-bug-fix)
    - [Working on Module for First Time](#working-on-module-for-first-time)
    - [Handling Blockers](#handling-blockers)
    - [Testing \& Validation](#testing--validation)
  - [Reporting and Progress Tracking](#reporting-and-progress-tracking)
    - [High-Level Progress](#high-level-progress)
    - [Feature Progress](#feature-progress)
    - [Filtering and Views](#filtering-and-views)
  - [Tips for Solo Development](#tips-for-solo-development)

## Project Structure

### Workspace Organization

**Spaces**:
- **LinkRadar** - Main project space with all boards
- **Side Projects** - Separate space for side project ideas and experiments

### LinkRadar Space Boards

1. **Domains** - High-level business areas (5 permanent cards)
2. **Modules** - System capabilities that persist over time (19 cards)
3. **Planning** - Feature documentation workflow
4. **Development** - Main work area for implementation

## Hierarchy and Card Relationships

### Project Hierarchy

```
LinkRadar Project (Roadmap)
├── Content Capture (Domain)
│   ├── Browser Extension (Module)
│   ├── Link Ingestion System (Module)
│   └── Content Extraction Engine (Module)
├── Intelligence Layer (Domain)
│   ├── LLM Integration Service (Module)
│   ├── Auto-Tagging Engine (Module)
│   └── Trend Analysis Engine (Module)
├── User Interface (Domain)
│   ├── Dashboard Interface (Module)
│   ├── Search & Filter System (Module)
│   ├── Trend Visualization (Module)
│   └── Settings & Preferences (Module)
├── Data Management (Domain)
│   ├── Database Schema (Module)
│   ├── Search Engine (Module)
│   ├── Data Export System (Module)
│   └── API Endpoints (Module)
└── Platform (Domain)
    ├── Infrastructure (Module)
    └── CLI Tool (Module)
```

### Card Linking Rules

**CRITICAL**: All cards must be linked to the LinkRadar project for full traceability. The hierarchy is managed through parent-child relationships.

1. **All Domain cards link to LinkRadar Project**
2. **All Module cards are children of their parent Domain card**
3. **Planning cards are children of their relevant Module card**
4. **Development work cards are children of Planning cards**

**Project Inheritance**: Cards automatically inherit the LinkRadar project from their parent, creating full traceability back to the main project.

**IMPORTANT**: Module cards should be children of their Domain card, not directly linked to the project. This maintains proper hierarchy and traceability.

This creates rollup progress tracking:
- LinkRadar Project shows overall project completion
- Domain cards show progress across their modules
- Module cards show progress from planning cards
- Planning cards show progress from development work

## Board Details

### 1. Domains Board

**Purpose**: High-level view of major business areas

**Lists**:
- **Active** - All domains live here (domains don't move)

**5 Domain Cards**:
1. **Content Capture** - Link saving, extraction, and ingestion capabilities
2. **Intelligence Layer** - LLM processing, auto-tagging, and trend analysis capabilities
3. **User Interface** - Web app interfaces and user experience
4. **Data Management** - Storage, search, archival, and API capabilities
5. **Platform** - Infrastructure, deployment, CLI, and platform operations

**Usage**:
- Domains are permanent organizational cards
- They never move between lists
- Each domain links to the LinkRadar Project (Roadmap)
- Use for high-level reporting and progress tracking

### 2. Modules Board

**Purpose**: Track persistent system capabilities over time

**Lists**:
- **Not Started** - Haven't built this yet
- **In Development** - Actively working on features in this area
- **MVP Complete** - Basic functionality is done

**19 Module Cards** organized by domain (see hierarchy above)

**Module Cards by Domain**:
- **Content Capture (3)**: Browser Extension, Link Ingestion System, Content Extraction Engine
- **Intelligence Layer (3)**: LLM Integration Service, Auto-Tagging Engine, Trend Analysis Engine  
- **User Interface (4)**: Dashboard Interface, Search & Filter System, Trend Visualization, Settings & Preferences
- **Data Management (4)**: Database Schema, Search Engine, Data Export System, API Endpoints
- **Platform (2)**: Infrastructure, CLI Tool

**Usage**:
- Create a module card when planning work in a new area
- Move to "In Development" when first feature begins
- Move to "MVP Complete" when first feature ships
- Module stays there as more features enhance it over time
- Each module is a child of its parent Domain card
- Project inheritance flows from Domain → Module → Planning → Development

### 3. Planning Board

**Purpose**: Lightweight feature documentation workflow

**Lists**:
- **Backlog** - Ideas and upcoming features
- **Vision** - Writing vision document
- **Requirements** - Writing requirements document
- **Spec** - Writing technical specification
- **Plan** - Writing implementation plan

**Card Numbering**: Use **LR###** format (e.g., LR001, LR002, LR003)

**Workflow**:
1. Create LR### card in Backlog
2. Link to appropriate Module card as its child
3. Move through planning stages as you write documentation
4. At "Plan" stage: Create child cards for development work
5. Planning docs live in monorepo at `/project/features/LR###-feature-name/`
6. Project inheritance flows from Module → Planning → Development cards

**Lightweight Approach**:
- Always write vision docs for major features
- Requirements/Spec as needed for complexity
- Skip documentation phases for simple features
- Use the process loosely - it's for solo development

### 4. Development Board

**Purpose**: Main work area for solo development

**Lists**:
- **To Do** - Work ready to be picked up
- **Doing** - Actively working on
- **Blocked** - Blocked or waiting on something
- **Done** - Completed work

**Workflow**:
- Continuous flow without formal sprints
- Cards move through To Do → Doing → Blocked (if needed) → Done
- Use "Blocked" for work that's stuck or waiting on dependencies

**Card Types**:
- Individual development tasks
- Feature components
- Bug fixes
- Infrastructure work

## Planning Documents in Monorepo

### Location

All planning documents live in the LinkRadar monorepo at `/project/features/`:

```
/project/features/
├── LR001-auto-tagging/
│   ├── vision.md
│   ├── requirements.md
│   ├── spec.md
│   └── plan.md
├── LR002-browser-extension/
│   ├── vision.md
│   └── plan.md
└── LR003-cli-tool/
    └── vision.md
```

### Document Types

- **vision.md** - High-level goals, user stories, success criteria (always write for major features)
- **requirements.md** - Functional and non-functional requirements (as needed for complexity)
- **spec.md** - Technical design and architecture decisions (as needed for complexity)
- **plan.md** - Implementation tasks and sequencing (break down into development cards)

### Why Planning Docs in Monorepo?

- **Version control** - Planning evolves with the code
- **LLM access** - AI tools can read entire context
- **Single source of truth** - Everything in one place
- **Living documents** - Easy to update as you learn

### Superthread Card → Planning Doc Link

- **Card Title**: "LR001 - Auto-Tagging System"
- **Planning Docs**: `/project/features/LR001-auto-tagging/`
- **Card Description**: Should link to the planning directory in monorepo

The LR### numbering creates a clear 1:1 relationship between Superthread planning cards and monorepo documentation directories.

## Complete End-to-End Workflow

### Phase 1: Planning (Planning Board)

1. **Create LR### card** in Backlog list
   - Use LR### numbering (e.g., LR001)
   - Link to appropriate Module card as its child
   - Add relevant tags (mvp, feature, phase-1, etc.)

2. **Write planning documents** in monorepo
   - Create `/project/features/LR###-feature-name/` directory
   - Move card through: Backlog → Vision → Requirements → Spec → Plan
   - Write docs as needed (vision always, requirements/spec as complexity demands)

3. **At Plan stage**: Create child cards for development work
   - Break feature into implementable tasks
   - Child cards go to Development board "To Do" list

### Phase 2: Development (Development Board)

1. **Pull work** from "To Do" to "Doing"
   - Focus on one task at a time
   - Update card status as you work

2. **Handle blockers** with "Blocked"
   - Move to "Blocked" if stuck or waiting on dependencies
   - Add comment explaining what you're waiting for
   - Pull next task from "To Do"

3. **Test and validate** before moving to Done
   - Test the implementation
   - Validate against requirements
   - Run through validation checklist
   - Review code quality

4. **Complete work** by moving to "Done"
   - All validation passed
   - Ready to deploy

### Phase 3: Shipping & Module Updates

1. **Deploy feature** to production

2. **Update Module card status** if needed
   - First feature in module? Move to "In Development"
   - Module MVP complete? Move to "MVP Complete"

3. **Update planning card**
   - Mark completed when all child cards done
   - Add retrospective notes if helpful

## Tagging Strategy

### Priority Tags
- `mvp` - Must have for initial release
- `post-mvp` - Nice to have, but not required
- `phase-1`, `phase-2`, `phase-3`, `phase-4` - Implementation phases

### Type Tags
- `feature` - New functionality
- `bug` - Bug fix
- `improvement` - Enhancement to existing feature
- `infrastructure` - Deployment, tooling, infrastructure work
- `documentation` - Documentation updates

### Status Tags
- `urgent` - Needs immediate attention
- `nice-to-have` - Low priority enhancement

**Usage**:
- Apply tags to cards at creation
- Use for filtering and reporting
- Helps with sprint planning (even in continuous flow)

## Common Scenarios

### Starting a New Feature

1. Create LR### card on Planning board
2. Link to appropriate Module as its child
3. Add tags (mvp, feature, phase-1)
4. Write vision document in monorepo
5. Move through planning stages
6. Create development tasks when ready
7. Project inheritance flows automatically from Module

### Quick Bug Fix

1. Create card directly on Development board "To Do"
2. Add `bug` tag
3. Skip planning docs entirely
4. Move through workflow and ship

### Working on Module for First Time

1. Planning card is a child of Module
2. When you start work, move Module to "In Development"
3. When first feature ships, move Module to "MVP Complete"
4. Module stays there as you add more features over time
5. Project inheritance flows from Domain → Module → Planning → Development

### Handling Blockers

1. Move card from "Doing" to "Blocked"
2. Add comment: what you're waiting for
3. Pull next card from "To Do"
4. Return to blocked work when unblocked

### Testing & Validation

1. While card is still in "Doing"
2. Test the implementation thoroughly
3. Check against requirements/spec
4. Review code quality
5. Run validation checklist
6. Move to "Done" when satisfied

## Reporting and Progress Tracking

### High-Level Progress

- **LinkRadar Project** (Roadmap) shows overall project completion
- **Domains Board** shows progress across business areas
- **Modules Board** shows what's built vs not started

### Feature Progress

- **Planning Board** shows what's being planned
- **Development Board** shows what's being built
- **Module cards** show rollup from planning cards

### Filtering and Views

Use Superthread's filtering to answer questions:
- "What's in MVP?" → Filter by `mvp` tag
- "What features are planned?" → Check Planning board
- "What modules are complete?" → Check Modules board "MVP Complete" list
- "What am I working on?" → Check Development board "Doing" list

## Tips for Solo Development

1. **Don't over-plan** - Vision docs for big features, skip for small ones
2. **Use continuous flow** - No need for formal sprint planning
3. **Keep Development board clean** - Archive or delete done cards regularly
4. **Update Module status** - Helps with high-level progress tracking
5. **Tag consistently** - Makes filtering and reporting easier
6. **Link cards properly** - Use parent-child relationships for hierarchy, project linking only for top-level cards
7. **Write just enough docs** - Planning docs are for you, not for show

---

This workflow keeps the project organized while staying flexible enough for solo development. It preserves the benefits of structured planning (when needed) without the overhead of team coordination.

