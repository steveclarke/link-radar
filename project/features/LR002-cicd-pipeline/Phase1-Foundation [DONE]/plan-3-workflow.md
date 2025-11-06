# Plan 3: Development Workflow Documentation

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Superthread Card:** Card #130 — LR002-P3: Phase 1 – Development Workflow Documentation  
**Status:** ✅ Complete

## Goal

Document the complete Git/GitHub development workflow for LinkRadar. This creates the single source of truth for branching strategy, commit conventions, PR process, labeling, reviews, and release tagging that you'll follow and eventually share with team members.

## Why This Matters

Clear workflow documentation:
- **Establishes consistency** - Same process every time
- **Reduces decisions** - Don't reinvent the wheel for each PR
- **Enables testing** - You can verify the workflow works before automating
- **Scales to teams** - Ready to onboard collaborators
- **Prevents mistakes** - Clear practices reduce errors

This is especially valuable as a pattern to lift to your bigger team project.

## What You'll Create

### 1. Comprehensive Workflow Guide
**Location:** `project/guides/development-workflow.md`

## Implementation Steps

### Step 1: Review Existing Project Workflow

**Time Estimate:** 30 minutes

**Review Checklist:**
- [ ] Read `project/guides/project-workflow.md` completely
- [ ] Understand how Superthread workflow integrates with Git/GitHub
- [ ] Note where Superthread cards connect to GitHub PRs
- [ ] Understand when to create branches
- [ ] Understand how feature cards flow to development work
- [ ] Document key insights

### Step 2: Define Branching Strategy

**Time Estimate:** 30 minutes

**Branching Documentation Checklist:**
- [ ] Document branch naming conventions (feat/, fix/, etc.)
- [ ] Define when to create a branch
- [ ] Define how to name branches (lowercase, hyphenated, descriptive)
- [ ] **Document Superthread card ID integration in branch names**
- [ ] Decide merge vs rebase strategy
- [ ] Define when to delete branches
- [ ] Document that master branch is always deployable
- [ ] Write clear examples for each branch type with Superthread card IDs

**Recommended Strategy:**
```
master (protected)
  ├── feat/ST-128-pr-template
  ├── fix/ST-145-backend-link-validation
  ├── chore/ST-156-update-dependencies
  └── docs/ST-130-workflow-guide
```

**Branch Naming Conventions:**
- `feat/ST-XXX-description` - New features
- `fix/ST-XXX-description` - Bug fixes
- `chore/ST-XXX-description` - Maintenance, dependencies, tooling
- `docs/ST-XXX-description` - Documentation updates
- `refactor/ST-XXX-description` - Code restructuring
- `test/ST-XXX-description` - Test additions/changes

**Superthread Integration:**
- Always include Superthread card ID (`ST-XXX`) in branch name
- Format: `{type}/ST-{number}-{brief-description}`
- Enables automatic card linking and status updates
- Can use Superthread's "Copy git branch name" but convert to our format (replace underscores with hyphens, ensure type prefix)

### Step 3: Document Commit Conventions

**Time Estimate:** 45 minutes

**Commit Documentation Checklist:**
- [ ] Document Conventional Commits format structure
- [ ] List all commit types with definitions
- [ ] Document optional scope usage
- [ ] Write good commit subject guidelines
- [ ] Document when to include body text
- [ ] Document how to reference issues/cards
- [ ] **Document commit frequency best practices**
- [ ] **Document "no uncommitted work at end of day" rule**
- [ ] Create 5+ LinkRadar-specific examples
- [ ] Include examples of good vs bad commits
- [ ] Explain benefits of frequent, small commits

Detail Conventional Commits format with LinkRadar-specific examples:

**Format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:** (matching your labels)
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `style:` - Formatting
- `refactor:` - Code restructuring
- `test:` - Tests
- `chore:` - Build/tools

**Scope:** (optional, matching your areas)
- `backend`, `extension`, `frontend`, `cli`, `infrastructure`, `project`

**Examples:**
```
feat(backend): add link archival endpoint

Implement POST /api/v1/links/:id/archive endpoint to allow
marking links as archived without deletion. Includes validation
and database migration.

Closes #42
```

```
fix(extension): resolve popup not opening on Firefox

The popup.html failed to load on Firefox due to CSP issues.
Updated manifest.json with proper permissions.
```

```
chore(infrastructure): update Docker base image to Ruby 3.4.2

Bump base image for security patches and performance improvements.
```

**Include:**
- When to use each type
- How to write good subjects (imperative mood, <50 chars)
- When to include body text
- How to reference issues/cards

### Step 4: Detail PR Process

**Time Estimate:** 60 minutes

**PR Process Documentation Checklist:**
- [ ] Document complete PR workflow (11 steps)
- [ ] Document draft PR creation immediately upon starting work
- [ ] Document frequent commit practices
- [ ] **Document Superthread card ID in branch names and PR titles**
- [ ] Define how to handle merge conflicts
- [ ] Define when to update from master
- [ ] Document PR description best practices
- [ ] Document how to link to Superthread cards
- [ ] Create review checklist items
- [ ] Include troubleshooting common issues
- [ ] Add examples of good PR descriptions

**Steps:**
1. **Create branch** from `master`
2. **Make initial empty commit** to enable PR creation:
   ```bash
   git commit --allow-empty -m "feat(area): initialize [feature name]"
   ```
3. **Push branch** to GitHub immediately
4. **Create DRAFT PR** right away (template loads automatically)
5. **Fill out template** as much as possible (can be refined later)
6. **Add labels** (type + area, required)
7. **Link Superthread card** in description
8. **Commit frequently** as you work (multiple times per day)
9. **Mark ready for review** when complete
10. **Request review** (even for solo dev, good habit)
11. **Address feedback** if any
12. **Merge when approved** using squash merge
13. **Delete branch** after merge

**Critical Practices:**
- **Use empty commits to start** - `git commit --allow-empty` enables immediate PR creation
- **Create draft PR immediately** - Don't wait until work is done
- **Commit multiple times per day** - Small, incremental commits
- **Never leave uncommitted changes** - Push work at end of each day
- **Draft PRs make work visible** - Others can see progress and provide early feedback
- **Commits are your backup** - Protect your work by committing often

**Include:**
- How to handle merge conflicts
- When to update from master
- PR description best practices
- How to link to Superthread cards
- Review checklist items
- Benefits of draft PRs and frequent commits

### Step 5: Explain Label Usage

**Time Estimate:** 20 minutes

**Label Documentation Checklist:**
- [ ] Reference Plan 2's label taxonomy
- [ ] Document label requirements (type + area)
- [ ] Document when multiple area labels are OK
- [ ] Create 5+ label combination examples
- [ ] Document what happens if labels are missing

Reference Plan 2's label taxonomy and document:

**Label Requirements:**
- Every PR needs at least one type label
- Every PR needs at least one area label
- Multiple area labels OK if change spans modules

**Examples:**
- Backend feature: `type: feat` + `area: backend`
- Extension bug: `type: fix` + `area: extension`
- Cross-module refactor: `type: refactor` + `area: backend` + `area: extension`
- Documentation: `type: docs` + `area: project`

### Step 6: Document Merge Strategy

**Time Estimate:** 20 minutes

**Merge Strategy Documentation Checklist:**
- [ ] Explain squash merge concept
- [ ] Document why squash merges are used
- [ ] Document squash commit message format
- [ ] Create examples of good squash messages
- [ ] Document what happens to PR commits
- [ ] Explain benefits (clean history, easy revert, etc.)

Explain the merge approach:

**Squash Merges:**
- All PRs use squash merge to `master`
- Creates single commit with clean message
- Preserves linear history
- Makes revert easier if needed

**Why Squash:**
- Clean history without "fix typo" commits
- Easier to understand what changed
- Simpler to bisect when debugging
- Professional Git history for team review

**Squash Commit Message Format:**
```
feat(backend): add link archival endpoint (#42)

* Implement POST /api/v1/links/:id/archive endpoint
* Add database migration for archived_at column
* Include validation and tests

Superthread Card: https://clevertakes.superthread.com/card/123
```

### Step 7: Document Release Tagging

**Time Estimate:** 30 minutes

**Release Tagging Documentation Checklist:**
- [ ] Document semantic versioning format
- [ ] Explain MAJOR, MINOR, PATCH meanings
- [ ] Document when to create tags
- [ ] Document how to create tags (commands)
- [ ] Document tag message format
- [ ] Create example tags with messages
- [ ] Document tag push commands

Define versioning and tagging strategy:

**Semantic Versioning:**
- `vMAJOR.MINOR.PATCH` (e.g., `v1.2.3`)
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

**When to Tag:**
- After merging to `master` when ready for production
- Typically after related PRs are merged
- When releasing to users

**How to Tag:**
```bash
git checkout master
git pull
git tag -a v1.2.0 -m "Release v1.2.0: Add link archival feature"
git push origin v1.2.0
```

**Tag Message Format:**
```
Release v1.2.0: Brief description

New Features:
- Feature 1
- Feature 2

Bug Fixes:
- Fix 1
- Fix 2
```

### Step 8: Include Code Review Guidelines

**Time Estimate:** 30 minutes

**Code Review Documentation Checklist:**
- [ ] Create "Before Requesting Review" checklist
- [ ] Document what to look for in reviews
- [ ] Create self-review checklist
- [ ] Document how to use GitHub review feature
- [ ] Include solo development considerations

Document review best practices (even for solo dev):

**Before Requesting Review:**
- [ ] All tests pass
- [ ] No linter errors
- [ ] Code is self-documented or commented
- [ ] PR description is complete
- [ ] Labels are applied

**What to Look For:**
- Code correctness
- Test coverage
- Performance considerations
- Security implications
- Documentation needs
- Alignment with architecture

**Self-Review Checklist:**
Use GitHub's review feature to review your own code before merging.

### Step 9: Write the Complete Guide

**Time Estimate:** 120 minutes

**Guide Creation Checklist:**
- [ ] Create file `project/guides/development-workflow.md`
- [ ] Create file `guide.md` in the directory
- [ ] Write Overview section
- [ ] Write Branching Strategy section
- [ ] Write Commit Conventions section with examples
- [ ] Write Pull Request Process section
- [ ] Write Code Review section
- [ ] Write Merging section
- [ ] Write Release Tagging section
- [ ] Write Common Scenarios section
- [ ] Write Troubleshooting section
- [ ] Write Quick Reference section
- [ ] Write For Future Team Members section
- [ ] Proofread and refine entire guide

Create `project/guides/development-workflow.md`:

**Guide Structure:**

```markdown
# Git/GitHub Development Workflow

## Overview
How we use Git and GitHub for LinkRadar development.

## Branching Strategy

### Branch Naming
Conventions and examples for different types of work.

**Include Superthread card IDs:**
- Format: `{type}/ST-{number}-{description}`
- Enables automatic card linking
- Examples: `feat/ST-128-add-auth`, `docs/ST-130-workflow-guide`

### Master Branch Protection
Master is protected and always deployable.

### Working with Branches
Creating, pushing, updating, and deleting branches.

### Draft PR Workflow
Creating draft PRs immediately and converting to ready when complete.

## Commit Conventions

### Conventional Commits Format
Type, scope, subject, body, footer explained with examples.

### Writing Good Commits
- Imperative mood
- Clear, concise subjects
- Detailed bodies when needed
- References to issues/cards
- **Commit frequently** - Multiple small commits per day
- **Push regularly** - At minimum, push at end of each work session

### Commit Frequency Best Practices
- Make 3-5+ commits per day when actively working
- Commit after each logical change or milestone
- Never end the day with uncommitted changes
- Small, incremental commits are better than large ones
- Each commit should represent a complete thought/change

### Example Commits
Good and bad examples with explanations.

## Pull Request Process

### Creating a Draft PR Immediately
Why and how to create draft PRs at the start of work.

**Why Draft PRs First:**
- Makes work visible to team (even if solo dev)
- Enables early feedback and discussion
- Creates backup of your work
- Shows progress on Superthread cards
- Prevents "surprise" large PRs
- Allows CI checks to run early (Phase 2)

**When to Create:**
- Immediately after creating branch and first commit
- When starting any Superthread card
- Before significant work begins
- Even for small changes (good habit)

**Initial Commit Approach:**
GitHub requires at least one commit to create a PR. Use an empty commit:
```bash
git commit --allow-empty -m "feat(backend): initialize user authentication"
```

**Why empty commits:**
- Quick and consistent
- No need to create placeholder code
- Clear signal that work is just starting
- Gets squashed away in final merge anyway
- Enables immediate PR creation without artificial changes

### Creating a PR
Step-by-step from branch creation to merge.

### PR Template Usage
How to fill out the template completely (can be refined as work progresses).

### Labeling Requirements
Type and area labels explained.

### Linking to Superthread
How to reference Superthread cards in PRs.

**Automatic Linking:**
- Include card ID (`ST-XXX`) in branch name: `feat/ST-128-description`
- Include card ID in PR title: `feat(backend): Add feature ST-128`
- Enables automatic card linking and status updates
- Card status updates automatically when PR is merged

## Code Review

### Self-Review
Reviewing your own code before merging.

### Review Checklist
What to look for in reviews.

### Addressing Feedback
How to respond to review comments.

## Merging

### Squash Merge Strategy
Why we use squash merges and how they work.

### Merge Checklist
Final checks before merging.

### After Merge
Branch cleanup and next steps.

## Release Tagging

### Semantic Versioning
How we version releases.

### Creating Tags
Commands and conventions.

### Tag Messages
What to include in tag messages.

## Common Scenarios

### Feature Development
Complete workflow example with draft PR and incremental commits.

**Workflow:**
1. Start Superthread card (move to "In Progress")
2. Create branch: `feat/ST-XXX-add-archival-endpoint` (include card ID)
3. Make empty initial commit to enable PR creation:
   ```bash
   git checkout master
   git pull
   git checkout -b feat/ST-XXX-add-archival-endpoint
   git commit --allow-empty -m "feat(backend): initialize link archival feature"
   git push -u origin feat/ST-XXX-add-archival-endpoint
   ```
4. Create DRAFT PR on GitHub immediately (card ID in branch name enables auto-linking)
5. Fill out PR template (link Superthread card)
6. Add labels: `type: feat` + `area: backend`
7. Work in small increments, committing 3-5+ times per day
8. Push commits regularly (at minimum, at end of each day)
9. Mark PR as "Ready for review" when complete
10. Self-review, then merge
11. Move Superthread card to "Done" (or it auto-updates on merge)

### Bug Fix
Quick bug fix workflow with immediate draft PR.

### Documentation Update
Simple doc change workflow (can still use draft PR for visibility).

### Multi-Module Changes
Working across backend and extension with frequent commits.

## Troubleshooting

### Merge Conflicts
How to resolve conflicts.

### Failed CI Checks
What to do when checks fail (Phase 2).

### Fixing Commit Messages
Amending commits before merge.

## Quick Reference

### Daily Workflow Checklist
- [ ] Create branch from `master`
- [ ] Make empty commit: `git commit --allow-empty -m "..."`
- [ ] Push branch to GitHub
- [ ] Create DRAFT PR immediately
- [ ] Add labels and link Superthread card
- [ ] Commit 3-5+ times during work session
- [ ] Push commits at end of day (no uncommitted work!)
- [ ] Mark PR ready when complete
- [ ] Self-review and merge

### Commands Cheat Sheet
Common Git commands for the workflow.

### Branch Naming Examples
Quick reference for branch names.

### Commit Message Examples
Quick reference for good commits.

## For Future Team Members

### Onboarding Checklist
What new team members need to know.

### Getting Started
First PR walkthrough emphasizing draft PRs and frequent commits.

### Critical Team Practices
**Non-negotiable workflows:**
- Always create draft PRs immediately when starting work
- Commit multiple times per day (3-5+ commits minimum)
- Never leave uncommitted work at end of day
- All work must be visible in draft PRs

### Team Practices
Other conventions specific to LinkRadar.
```

## Deliverables

- [x] `project/guides/development-workflow.md` - Complete comprehensive guide
- [x] All sections filled with LinkRadar-specific examples
- [x] Quick reference sections for common tasks
- [x] Ready to follow immediately and share with future team
- [ ] Superthread card #130 moved to "Done" (pending PR merge)

## Success Criteria

- ✅ Complete workflow documented from branch to merge
- ✅ Conventional Commits explained with examples
- ✅ Branching strategy clear and practical
- ✅ PR process documented step-by-step
- ✅ **Draft PR workflow emphasized and documented**
- ✅ **Frequent commit practices clearly defined**
- ✅ **"No uncommitted work" rule established**
- ✅ Labels and tagging covered
- ✅ Self-review guidelines included
- ✅ Ready to use as daily reference
- ✅ Suitable for team member onboarding

## Time Estimate

**Total:** ~6 hours

## Next Steps

After completing this plan:
1. Move Superthread card #130 to "Done"
2. Proceed to Plan 4 (Branch Protection)
3. Follow this workflow for all development work

## Notes

- This is your opportunity to think through the complete workflow
- Start simple, you can always expand later
- Include specific examples from LinkRadar
- Make it practical, not theoretical
- This document will evolve as your workflow does
- The guide you create here can be directly lifted to your bigger team project
- **The draft PR + frequent commit pattern is critical** - This prevents work from being lost, makes progress visible, enables early feedback, and creates good habits for team collaboration

## Completion Summary

**What Was Delivered:**
- Comprehensive workflow guide at `project/guides/development-workflow.md` (608 lines)
- Table of contents for easy navigation
- Branching strategy with flexible Superthread integration (optional card IDs)
- Commit conventions with Conventional Commits format
- Complete PR workflow (draft PRs, labels, review process)
- Code review guidelines with self-review checklist
- Merge strategy (squash merges)
- Troubleshooting section with VS Code and Cursor AI merge conflict tools
- Quick reference section with daily workflow checklist and essential commands
- Created `/suggest-commit-message` AI command for generating conventional commit messages
- Updated `/create-pr` AI command to leverage Superthread MCP integration

**Key Refinements Made:**
- Streamlined Superthread integration to be helpful but not mandatory
- Downplayed prescriptive language around early PRs and frequent commits (gentle nudge vs rocket science)
- Removed Release Tagging section (belongs in separate release guide)
- Removed redundant sections (Common Scenarios, For Future Team Members, duplicate quality checklists)
- Added practical tooling tips (GitHub PR extension, VS Code merge editor, Cursor AI)
- Changed branch naming from strict `{type}/ST-XXX-{description}` to flexible `{type}/{description}` or `{type}/{feature-id}-{description}`
- Card IDs now preferred in PR title rather than branch name for cleaner git history
- Updated all empty commit examples from "initialize" to "start work" for clarity

**Guide Philosophy:**
The final guide balances professionalism with practicality. It establishes clear conventions without being overly prescriptive, encouraging good practices (early PRs, regular commits, end-of-day pushes) as natural workflow habits rather than rigid rules.

