# Plan 3: Development Workflow Documentation

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Superthread Card:** [LR002-P3: Document Development Workflow](https://clevertakes.superthread.com/card/130)  
**Status:** Ready to Execute

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
**Location:** `project/guides/github/workflow/guide.md`

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
- [ ] Document branch naming conventions (feature/, fix/, etc.)
- [ ] Define when to create a branch
- [ ] Define how to name branches (lowercase, hyphenated, descriptive)
- [ ] Decide merge vs rebase strategy
- [ ] Define when to delete branches
- [ ] Document that main branch is always deployable
- [ ] Write clear examples for each branch type

**Recommended Strategy:**
```
main (protected)
  ├── feature/lr002-p1-pr-template
  ├── fix/backend-link-validation
  ├── chore/update-dependencies
  └── docs/improve-readme
```

**Branch Naming Conventions:**
- `feature/` - New features
- `fix/` - Bug fixes
- `chore/` - Maintenance, dependencies, tooling
- `docs/` - Documentation updates
- `refactor/` - Code restructuring
- `test/` - Test additions/changes

### Step 3: Document Commit Conventions

**Time Estimate:** 45 minutes

**Commit Documentation Checklist:**
- [ ] Document Conventional Commits format structure
- [ ] List all commit types with definitions
- [ ] Document optional scope usage
- [ ] Write good commit subject guidelines
- [ ] Document when to include body text
- [ ] Document how to reference issues/cards
- [ ] Create 5+ LinkRadar-specific examples
- [ ] Include examples of good vs bad commits

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

**Time Estimate:** 45 minutes

**PR Process Documentation Checklist:**
- [ ] Document complete PR workflow (10 steps)
- [ ] Define how to handle merge conflicts
- [ ] Define when to update from main
- [ ] Document PR description best practices
- [ ] Document how to link to Superthread cards
- [ ] Create review checklist items
- [ ] Include troubleshooting common issues
- [ ] Add examples of good PR descriptions

**Steps:**
1. **Create branch** from `main`
2. **Make changes** with good commits
3. **Push branch** to GitHub
4. **Create PR** (template loads automatically)
5. **Fill out template** completely
6. **Add labels** (type + area, required)
7. **Link Superthread card** in description
8. **Request review** (even for solo dev, good habit)
9. **Address feedback** if any
10. **Merge when approved** using squash merge
11. **Delete branch** after merge

**Include:**
- How to handle merge conflicts
- When to update from main
- PR description best practices
- How to link to Superthread cards
- Review checklist items

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
- All PRs use squash merge to `main`
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
- After merging to `main` when ready for production
- Typically after related PRs are merged
- When releasing to users

**How to Tag:**
```bash
git checkout main
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

**Time Estimate:** 90 minutes

**Guide Creation Checklist:**
- [ ] Create directory `project/guides/github/workflow/`
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

Create `project/guides/github/workflow/guide.md`:

**Guide Structure:**

```markdown
# Git/GitHub Development Workflow

## Overview
How we use Git and GitHub for LinkRadar development.

## Branching Strategy

### Branch Naming
Conventions and examples for different types of work.

### Main Branch Protection
Main is protected and always deployable.

### Working with Branches
Creating, pushing, updating, and deleting branches.

## Commit Conventions

### Conventional Commits Format
Type, scope, subject, body, footer explained with examples.

### Writing Good Commits
- Imperative mood
- Clear, concise subjects
- Detailed bodies when needed
- References to issues/cards

### Example Commits
Good and bad examples with explanations.

## Pull Request Process

### Creating a PR
Step-by-step from branch creation to merge.

### PR Template Usage
How to fill out the template completely.

### Labeling Requirements
Type and area labels explained.

### Linking to Superthread
How to reference Superthread cards in PRs.

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
Complete workflow example.

### Bug Fix
Quick bug fix workflow.

### Documentation Update
Simple doc change workflow.

### Multi-Module Changes
Working across backend and extension.

## Troubleshooting

### Merge Conflicts
How to resolve conflicts.

### Failed CI Checks
What to do when checks fail (Phase 2).

### Fixing Commit Messages
Amending commits before merge.

## Quick Reference

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
First PR walkthrough.

### Team Practices
Conventions specific to LinkRadar.
```

## Deliverables

- [ ] `project/guides/github/workflow/guide.md` - Complete comprehensive guide
- [ ] All sections filled with LinkRadar-specific examples
- [ ] Quick reference sections for common tasks
- [ ] Ready to follow immediately and share with future team
- [ ] Superthread card #130 moved to "Done"

## Success Criteria

- ✅ Complete workflow documented from branch to merge
- ✅ Conventional Commits explained with examples
- ✅ Branching strategy clear and practical
- ✅ PR process documented step-by-step
- ✅ Labels and tagging covered
- ✅ Self-review guidelines included
- ✅ Ready to use as daily reference
- ✅ Suitable for team member onboarding

## Time Estimate

**Total:** ~5 hours

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

