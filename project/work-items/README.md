# Work Items

This directory contains all LinkRadar work items (features, infrastructure, bugs, improvements) tracked using the **LR###** numbering scheme.

## Purpose

Work items are the planning and documentation artifacts for LinkRadar development. Each work item corresponds to cards in Superthread and provides the detailed context needed for implementation.

## Naming Convention

Work items follow the **LR###** format:
- **LR** = LinkRadar prefix
- **###** = Three-digit sequential number (e.g., 001, 002, 003)

Examples:
- `LR001` - Core Infrastructure Setup
- `LR002` - Link Capture Functionality
- `LR003` - Content Extraction and Archival

## Directory Structure

Each work item gets its own directory:

```
/project/work-items/
├── README.md (this file)
├── LR001-core-infrastructure/
│   ├── plan.md
│   ├── vision.md (optional)
│   ├── requirements.md (optional)
│   └── spec.md (optional)
├── LR002-link-capture/
│   ├── vision.md
│   ├── requirements.md
│   └── plan.md
└── LR003-content-extraction/
    └── plan.md
```

## Document Types

- **vision.md** - Strategic context, problem, solution, user needs (always write for major features)
- **requirements.md** - Business capabilities, workflows, quality attributes
- **spec.md** - Technical implementation details, architecture, data models
- **plan.md** - Implementation phases, sequencing, tasks, success criteria
- **tasks.md** - Granular task breakdown (only when needed)
- **future.md** - Deferred ideas and future enhancements (optional)

**For solo development**: Write what's useful. Infrastructure work might only need a `plan.md`. Complex features might need all documents.

## Superthread Integration

Each work item in this directory corresponds to cards in Superthread:

1. **Planning Card** - Created on Planning board, moves through: Backlog → Vision → Requirements → Spec → Plan
2. **Development Cards** - Child cards created on Development board at Plan stage
3. **Module Link** - Planning card links to appropriate Module card
4. **Domain Rollup** - Progress rolls up through Module → Domain → Project

See [Project Workflow](../project-workflow.md) for complete workflow details.

## LLM-Ready Documentation

All work item documents are written to be consumed by AI coding assistants:
- Clear, unambiguous language
- Sufficient detail (data shapes, edge cases, acceptance criteria)
- Consistent naming across documents
- Cross-references between documents

This enables AI tools to:
- Generate scaffolding code from specs
- Understand context for implementation decisions
- Maintain consistency across the codebase
- Answer questions about requirements and design

## Example Work Item Lifecycle

1. **Create Planning Card** in Superthread (Planning board → Backlog)
2. **Create Work Item Directory** (`/project/work-items/LR###-feature-name/`)
3. **Write Planning Documents** as you move card through planning stages
4. **Create Development Cards** when planning is complete (at Plan stage)
5. **Implement** by moving development cards through workflow
6. **Update Module Status** when work completes

## Quick Start

To create a new work item:

1. Determine the next LR### number (check existing directories)
2. Create directory: `/project/work-items/LR###-descriptive-name/`
3. Start with what you need:
   - Major feature? Write `vision.md` first
   - Infrastructure? Write `plan.md` directly
   - Complex system? Write `vision.md` → `requirements.md` → `spec.md` → `plan.md`
4. Create corresponding Superthread card
5. Link card to appropriate Module

## References

- [Project Workflow](../project-workflow.md) - Project management workflow (currently using Superthread)
- [Vision Document](../vision.md) - LinkRadar product vision
- [Tech Stack Proposal](../tech-stack-proposal.md) - Technology decisions and architecture

---

**Note**: This structure is designed for solo development. Use it flexibly - the goal is clarity and context, not bureaucracy.

