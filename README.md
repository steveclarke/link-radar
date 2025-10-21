# LinkRadar

**A personal knowledge radar that captures interesting content effortlessly and surfaces emerging trends in your learning and interests over time.**

## Overview

LinkRadar is a personal knowledge repository designed for voracious readers, researchers, and continuous learners who want to capture interesting content quickly and discover patterns in their interests over time.

Unlike traditional bookmark managers that simply save links, LinkRadar acts as your personal "radar" — intelligently visualizing trends, momentum, and patterns in the content you save, helping you identify emerging technologies and topics worth your attention.

## Table of Contents

- [LinkRadar](#linkradar)
  - [Overview](#overview)
  - [Table of Contents](#table-of-contents)
  - [The Problem](#the-problem)
  - [The Solution](#the-solution)
  - [Key Features](#key-features)
    - [Version 1 (In Development)](#version-1-in-development)
    - [Future Phases](#future-phases)
  - [Core Philosophy](#core-philosophy)
  - [Project Structure](#project-structure)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Development](#development)
    - [Development Setup](#development-setup)
    - [Tech Stack](#tech-stack)
  - [Project Status](#project-status)
  - [Contributing](#contributing)
  - [Documentation](#documentation)
  - [License](#license)

## The Problem

Voracious readers and researchers face three fundamental challenges:

1. **Lost Knowledge** - You know you saved that Biome article six months ago, but where? Hours wasted re-searching or giving up entirely.

2. **Scattered Silos** - Links spread across Notion, Obsidian, Raindrop, Todoist, and email-to-self with no single place to search.

3. **Invisible Trends** - You can't see that you've saved five Biome-related articles over three months. Is this tool heating up? Should you invest time learning it now? No way to know.

## The Solution

LinkRadar makes capturing effortless and intelligence automatic:

- **Capture anywhere** - Browser extension, CLI tool, or web UI. Drop a link in under 5 seconds.
- **Archive automatically** - System saves page content so links never die on you.
- **Tag intelligently** - LLM analyzes content and suggests relevant tags automatically.
- **Search powerfully** - Full-text search across everything you've saved.
- **Organize optionally** - Accept, reject, or refine LLM suggestions, or run in full auto mode.
- **Spot trends** _(coming soon)_ - Visualize what topics are heating up in your learning.

## Key Features

### Version 1 (In Development)

- **Multi-channel capture**
  - Web UI for viewing, searching, and manually adding links
  - CLI tool for command-line workflows
  - Browser extension for one-click capture from any webpage
  
- **LLM-powered auto-tagging**
  - Automatic tag suggestions based on content analysis
  - Support for flat and hierarchical tag structures
  - Accept/reject/modify suggestions or use full auto mode
  - System learns from your tagging patterns over time
  
- **Content preservation**
  - Archive page content at capture time
  - Ensure links never become dead ends
  
- **Full-text search**
  - Database-native search across all content
  - Search by tags, keywords, or full content
  
- **Organization & insights**
  - Optional notes and descriptions
  - View statistics on saved content

### Future Phases

**Phase 2: Intelligence Layer**
- Radar visualization showing trends and momentum
- Workspaces/contexts for organizing by topic
- Review/triage queue

**Phase 3: Collaboration & Integration**
- Collaborative workspaces for teams
- Import from other services (Raindrop, Pocket, browser bookmarks)
- Advanced search capabilities
- Sharing and export features

**Phase 4: Advanced Features**
- RSS/feed integration
- Progressive Web App for mobile
- Public API for integrations
- Enhanced content archival

See [project/future.md](project/future.md) for detailed roadmap.

## Core Philosophy

> "Make it as easy as breathing to capture a link, but provide powerful organization for those who want it."

LinkRadar works at 100% capacity even if you never review anything. Just dump links and search later. But if you want to organize and refine, the power is there.

## Project Structure

LinkRadar is a monorepo containing:

- **`backend/`** - Rails 8.1 API (Ruby 3.4.x, PostgreSQL 18)
- **`project/`** - Planning documents and work items

Additional components coming soon:
- Frontend SPA (Vue 3 + Nuxt)
- CLI tool
- Browser extension

## Installation

See component-specific READMEs for setup instructions:

- **Backend**: [backend/README.md](backend/README.md)

_Note: Additional components will have installation instructions added as they are built._

## Usage

_Note: Usage documentation will be added as features are implemented._

## Development

LinkRadar is being developed in the open as a personal project to solve a real problem. The project values:

- Portable, technology-agnostic data formats
- CLI-first workflows
- LLM agent integration capabilities
- Self-hosted deployment options

### Development Setup

**Quick Start**

Run the initialization script to set up your development environment:

```bash
bin/dev-init
```

This creates your personal workspace file with all formatter/linter settings pre-configured.

**Using VSCode/Cursor (Recommended)**

After running `bin/dev-init`, open the workspace:

```bash
code link-radar.code-workspace  # or 'cursor' if using Cursor
```

Install recommended extensions when prompted. Formatting and linting work automatically.

**Two Workflows Supported:**

1. **Workspace workflow** (recommended): See all folders (backend, project, docs)
   - Run `bin/dev-init` then open `link-radar.code-workspace`
   
2. **Single-folder workflow**: Focused backend development
   - Open `backend/` directly: `code backend/` or `cursor backend/`

Both workflows get identical formatter/linter settings automatically.

**Settings Documentation**

Settings are intentionally duplicated to work in both workflows:
- `backend/.vscode/settings.json` - Works when opening backend directly
- `link-radar.code-workspace` - Works when opening via workspace (personal, gitignored)

For complete documentation on why settings are structured this way, see:
- [VSCode Guide](project/guides/vscode-guide.md)

**Note:** Your workspace file is gitignored. You can customize folder structure without affecting other developers.

### Tech Stack

- **Backend**: Rails 8.1 (API-only), Ruby 3.4.x, PostgreSQL 18, Falcon
- **Frontend**: Vue 3, Nuxt, TypeScript (planned)
- **CLI**: Ruby (planned)
- **Extension**: JavaScript/TypeScript (planned)

## Project Status

🚧 **Currently in active development**

- [x] Vision document
- [x] Future roadmap
- [x] Technical specification
- [x] Core infrastructure setup (in progress - LR001)
  - [x] Rails 8.1 API skeleton
  - [ ] Database configuration with UUIDv7
  - [ ] API versioning structure
  - [ ] CORS configuration
- [ ] Core features implementation

## Contributing

This project is currently in early development, and we're open to contributors to help shape the vision of this product.

If you're interested, open an issue and make your suggestion — we can talk! Whether it's feature ideas, technical approaches, improvements to the roadmap, or even if you want to guinea pig it, your input is welcome.

## Documentation

- [Vision Document](project/vision.md) - Detailed vision and problem statement
- [Future Enhancements](project/future.md) - Planned features by phase
- [Vision Discussion Summary](project/vision-discussion-summary.md) - Complete planning context

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Status**: Active Development | **Version**: 0.1.0-alpha | **Current Work**: LR001 Core Infrastructure

