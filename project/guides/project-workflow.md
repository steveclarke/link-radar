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
    - [1. Modules Board](#1-modules-board)
    - [2. Features Board](#2-features-board)
    - [3. Development Board](#3-development-board)
  - [Feature Documents in Monorepo](#feature-documents-in-monorepo)
    - [Location](#location)
    - [Document Types](#document-types)
    - [Why Feature Docs in Monorepo?](#why-feature-docs-in-monorepo)
    - [Superthread Card → Feature Doc Link](#superthread-card--feature-doc-link)
  - [Complete End-to-End Workflow](#complete-end-to-end-workflow)
    - [Early Stage: Direct Module Development](#early-stage-direct-module-development)
    - [Later Stage: Feature Planning (Features Board)](#later-stage-feature-planning-features-board)
    - [Development (Development Board)](#development-development-board)
    - [Shipping \& Module Updates](#shipping--module-updates)
  - [Tagging Strategy](#tagging-strategy)
    - [Priority Tags](#priority-tags)
    - [Type Tags](#type-tags)
    - [Status Tags](#status-tags)
  - [Common Scenarios](#common-scenarios)
    - [Early Stage: Spiking and Roughing In](#early-stage-spiking-and-roughing-in)
    - [Later Stage: Planned Feature](#later-stage-planned-feature)
    - [Quick Bug Fix](#quick-bug-fix)
    - [Working on Module for First Time](#working-on-module-for-first-time)
    - [Handling Blockers](#handling-blockers)
    - [Testing \& Validation](#testing--validation)
  - [Reporting and Progress Tracking](#reporting-and-progress-tracking)
    - [High-Level Progress](#high-level-progress)
    - [Detailed Progress](#detailed-progress)
    - [Filtering and Views](#filtering-and-views)
  - [Tips for Solo Development](#tips-for-solo-development)

## Project Structure

### Workspace Organization

**Spaces**:
- **LinkRadar** - Main project space with all boards
- **Side Projects** - Separate space for side project ideas and experiments

### LinkRadar Space Boards

1. **Modules** - Core application components (5 cards)
2. **Features** - Feature planning workflow (optional, used as project matures)
3. **Development** - Main work area for implementation

## Hierarchy and Card Relationships

### Project Hierarchy

```
LinkRadar Project (Roadmap)
├── Backend (Module)
│   ├── LR001 - Auto-Tagging System (Feature - optional)
│   │   └── Implement LLM integration (Dev)
│   └── Set up basic API structure (Dev - direct link, no feature)
├── Frontend (Module)
│   └── LR002 - Dashboard UI (Feature - optional)
│       └── Build search interface (Dev)
├── CLI (Module)
├── Browser Extension (Module)
└── Infrastructure (Module)
    └── Docker compose setup (Dev - direct link, no feature)
```

### Card Linking Rules

**CRITICAL**: All cards must be linked for full traceability. The hierarchy is flexible and managed through parent-child relationships.

**Linking Options** (choose based on project stage):

1. **Module cards link directly to LinkRadar Project**
2. **Feature cards (LR###) are children of their relevant Module** (optional - use when planning major features)
3. **Development cards link to EITHER:**
   - A feature card (when working on a planned feature), OR
   - Directly to a module (for early-stage work, spikes, quick fixes)

**Project Inheritance**: Cards automatically inherit the LinkRadar project from their parent, creating full traceability back to the main project.

**Flexibility for Early Stage**: In early development, you can skip feature cards entirely and link dev cards directly to modules. As the project matures, use feature cards for planned work.

This creates rollup progress tracking:
- LinkRadar Project shows overall project completion
- Module cards show progress from all their work (features + direct dev cards)
- Feature cards show progress from their development work (when used)

## Board Details

### 1. Modules Board

**Purpose**: Track the 5 core application components and their development status

**Lists**:
- **Not Started** - Haven't built this yet
- **In Development** - Actively working on this component
- **MVP Complete** - Basic functionality is done

**5 Module Cards**:
1. **Backend** - Rails API, database models, background jobs, LLM integration, content extraction
2. **Frontend** - Nuxt web app, UI components, search interface, dashboards
3. **CLI** - Go command-line tool for link capture and management
4. **Browser Extension** - Chrome extension for one-click link capture
5. **Infrastructure** - Docker setup, deployment, CI/CD, supporting tooling

**Usage**:
- All 5 modules are permanent organizational cards
- Move to "In Development" when you start working on that component
- Move to "MVP Complete" when basic functionality ships
- Module stays there as more work enhances it over time
- Each module links directly to the LinkRadar Project
- Feature cards and dev cards are children of modules
- Each module has a vision document at `/project/modules/{module-name}/vision.md`

### 2. Features Board

**Purpose**: Feature planning and documentation workflow (optional - mainly for later stages)

**Lists**:
- **Backlog** - Ideas and upcoming features
- **Vision** - Writing vision document
- **Requirements** - Writing requirements document
- **Spec** - Writing technical specification
- **Plan** - Writing implementation plan
- **Distributed** - Planning complete, development cards created and in progress

**Card Numbering**: Use **LR###** format (e.g., LR001, LR002, LR003)

**Workflow** (when used):
1. Create LR### card in Backlog
2. Link to appropriate Module card as its child
3. Move through planning stages as you write documentation
4. At "Plan" stage: Create child cards for development work
5. Move feature card to "Distributed" once dev cards are created
6. Feature docs live in monorepo at `/project/features/LR###-feature-name/`
7. Project inheritance flows from Module → Feature → Development cards

**When to Use Feature Cards**:
- **Early stage**: Skip feature cards entirely - create dev cards directly linked to modules
- **Later stage**: Use feature cards for planned, complex features that need documentation
- **Always optional**: You can work effectively without ever using this board

**Lightweight Approach**:
- Write vision docs for major features when helpful
- Requirements/Spec as needed for complexity
- For early-stage spikes and subsystem roughing-in, skip this board entirely
- Use the process loosely - it's for solo development, not ceremony

### 3. Development Board

**Purpose**: Main work area for solo development

**Lists**:
- **Backlog** - Ideas and upcoming work you might tackle
- **To Do** - Work ready to be picked up
- **Doing** - Actively working on
- **Blocked** - Stuck or waiting on dependencies (e.g., extension feature blocked by backend work)
- **In Review** - Code review, testing, or validation before marking done
- **Done** - Completed work (archive periodically)

**Workflow**:
- Continuous flow without formal sprints
- Cards move through Backlog → To Do → Doing → In Review → Done
- Use "Blocked" when stuck or waiting on dependencies
- Use "In Review" for code review and testing before marking done

**Card Linking**:
- Link to a feature card (if working on a planned feature)
- OR link directly to a module (for early work, spikes, quick fixes)

**Card Types**:
- Subsystem roughing-in (early stage)
- Feature components (from feature cards)
- Quick spikes and experiments
- Bug fixes
- Infrastructure work

## Feature Documents in Monorepo

### Location

All feature documents live in the LinkRadar monorepo at `/project/features/`:

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

- **vision.md** - High-level goals, user stories, success criteria (write for major features when helpful)
- **requirements.md** - Functional and non-functional requirements (as needed for complexity)
- **spec.md** - Technical design and architecture decisions (as needed for complexity)
- **plan.md** - Implementation tasks and sequencing (break down into development cards)

### Why Feature Docs in Monorepo?

- **Version control** - Feature planning evolves with the code
- **LLM access** - AI tools can read entire context
- **Single source of truth** - Everything in one place
- **Living documents** - Easy to update as you learn

### Superthread Card → Feature Doc Link

- **Card Title**: "LR001 - Auto-Tagging System"
- **Feature Docs**: `/project/features/LR001-auto-tagging/`
- **Card Description**: Should link to the feature directory in monorepo

The LR### numbering creates a clear 1:1 relationship between Superthread feature cards and monorepo documentation directories.

**Note**: These are only created when using feature cards - early-stage work doesn't need documentation.

## Complete End-to-End Workflow

### Early Stage: Direct Module Development

**Use this approach when**: Spiking, roughing in subsystems, early bootstrapping

1. **Identify the module** you're working on (Backend, Frontend, CLI, Browser Extension, Infrastructure)

2. **Create dev card** directly on Development board "Backlog" or "To Do"
   - Link as child of the module (no feature card needed)
   - Add brief description of what you're roughing in
   - Add relevant tags

3. **Move through workflow**: Backlog → To Do → Doing → In Review → Done
   - Work on the task
   - Test as appropriate
   - Use "In Review" for code review before marking done
   - Complete and move to Done

4. **Update module status** if needed
   - First work in module? Move module to "In Development"
   - Basic functionality complete? Move to "MVP Complete"

### Later Stage: Feature Planning (Features Board)

**Use this approach when**: Planning complex, documented features

1. **Create LR### feature card** in Backlog list
   - Use LR### numbering (e.g., LR001)
   - Link to appropriate Module card as its child
   - Add relevant tags (mvp, feature, phase-1, etc.)

2. **Write feature documents** in monorepo (optional)
   - Create `/project/features/LR###-feature-name/` directory
   - Move card through: Backlog → Vision → Requirements → Spec → Plan → Distributed
   - Write docs as needed (vision when helpful, requirements/spec for complexity)

3. **At Plan stage**: Create child cards for development work
   - Break feature into implementable tasks
   - Child cards go to Development board "Backlog" or "To Do" list
   - Each dev card is a child of the feature card
   - Move feature card to "Distributed" once dev cards are created

### Development (Development Board)

1. **Pull work** from "To Do" to "Doing"
   - Focus on one task at a time
   - Update card status as you work

2. **Handle blockers** with "Blocked"
   - Move to "Blocked" if stuck or waiting on dependencies
   - Add comment explaining what you're waiting for
   - Pull next task from "To Do"

3. **Test and validate** before moving to Done
   - Test the implementation
   - Validate against requirements (if documented)
   - Review code quality

4. **Complete work** by moving to "Done"
   - All validation passed
   - Ready to deploy

### Shipping & Module Updates

1. **Deploy** to production

2. **Update Module card status** if needed
   - First work in module? Move to "In Development"
   - Module MVP complete? Move to "MVP Complete"

3. **Update feature card** (if using features)
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

### Early Stage: Spiking and Roughing In

**Use case**: Bootstrapping the system, roughing in subsystems, quick spikes

1. Create dev card directly on Development board "Backlog" or "To Do"
2. Link as child of relevant module (Backend, Frontend, CLI, etc.)
3. Add descriptive title: "Set up basic Rails API structure" or "Spike browser extension popup"
4. Add relevant tags (infrastructure, spike, etc.)
5. Skip feature cards and documentation entirely
6. Move through Backlog → To Do → Doing → In Review → Done
7. Update module status when appropriate

### Later Stage: Planned Feature

**Use case**: Complex feature that benefits from planning and documentation

1. Create LR### feature card on Features board
2. Link to appropriate Module as its child
3. Add tags (mvp, feature, phase-1)
4. Write vision document in monorepo (if helpful)
5. Move through planning stages as needed (Vision → Requirements → Spec → Plan)
6. Create development tasks as children of feature card
7. Move feature to "Distributed" once dev cards are created
8. Project inheritance flows automatically from Module

### Quick Bug Fix

1. Create card directly on Development board "Backlog" or "To Do"
2. Link to relevant module OR feature card (if it's part of a feature)
3. Add `bug` tag
4. Skip feature cards and docs entirely
5. Move through workflow and ship

### Working on Module for First Time

1. Create dev card (early stage) or feature card (later stage)
2. Link as child of the module
3. When you start work, move Module to "In Development"
4. When basic functionality ships, move Module to "MVP Complete"
5. Module stays there as you add more work over time
6. Project inheritance flows from Module → Feature (optional) → Development

### Handling Blockers

1. Move card from "Doing" to "Blocked"
2. Add comment: what you're waiting for
3. Pull next card from "To Do"
4. Return to blocked work when unblocked

### Testing & Validation

1. Move card to "In Review" when work is complete
2. Test the implementation thoroughly
3. Check against requirements/spec
4. Review code quality
5. Run validation checklist
6. Move to "Done" when satisfied

## Reporting and Progress Tracking

### High-Level Progress

- **LinkRadar Project** (Roadmap) shows overall project completion
- **Modules Board** shows which components are built vs not started vs in progress

### Detailed Progress

- **Module cards** show rollup from all their work (features + direct dev cards)
- **Features Board** shows what features are being planned (when using feature cards)
- **Development Board** shows what's currently being built

### Filtering and Views

Use Superthread's filtering to answer questions:
- "What's in MVP?" → Filter by `mvp` tag
- "What features are planned?" → Check Features board (if using it)
- "What modules are complete?" → Check Modules board "MVP Complete" list
- "What am I working on?" → Check Development board "Doing" list
- "What component needs work?" → Check Modules board for "Not Started"

## Tips for Solo Development

1. **Start simple** - Early stage? Skip feature cards, link dev cards directly to modules
2. **Don't over-plan** - Feature cards and docs are optional, use them when they help
3. **Use continuous flow** - No need for formal sprint planning
4. **Keep Development board clean** - Archive or delete done cards regularly
5. **Update Module status** - Helps with high-level progress tracking (In Development, MVP Complete)
6. **Tag consistently** - Makes filtering and reporting easier
7. **Link cards flexibly** - Direct to module for spikes, to feature card for planned work
8. **Write docs when helpful** - Feature docs are for you when planning helps, not ceremony

---

This workflow keeps the project organized while staying flexible for solo development. It embraces early-stage chaos while providing structure when the project matures. The key is flexibility: use what helps, skip what doesn't.

