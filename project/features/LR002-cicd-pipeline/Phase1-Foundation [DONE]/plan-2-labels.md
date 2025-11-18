# Plan 2: GitHub Labels

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Superthread Card:** Card #129 — LR002-P2: Phase 1 – GitHub Labels  
**Status:** Ready to Execute

## Goal

Set up a comprehensive label taxonomy in GitHub that combines industry-standard Conventional Commits types with LinkRadar's monorepo structure. Create both the labels manually (learning) and automation scripts (reproducibility).

## Why This Matters

Labels enable:
- **PR organization** - Quickly identify what type of change
- **Filtering** - Find all backend work, all bug fixes, etc.
- **Automation** - Phase 2 will enforce label requirements via GitHub Actions
- **Team scaling** - Clear categorization when collaborators join

The two-axis approach (type + area) provides powerful filtering: "Show me all feature work in the backend" or "Show me all infrastructure changes."

## Label Taxonomy

### Type Labels (Based on Conventional Commits)

- `type: feat` - New features
- `type: fix` - Bug fixes
- `type: docs` - Documentation changes
- `type: style` - Code style/formatting (no logic changes)
- `type: refactor` - Code restructuring (no behavior changes)
- `type: test` - Test additions/changes
- `type: chore` - Build, tools, dependencies

### Area Labels (Based on Monorepo Structure)

- `area: backend` - Rails API backend
- `area: extension` - Browser extension
- `area: frontend` - Frontend SPA (future)
- `area: cli` - CLI tool (future)
- `area: infrastructure` - Docker, deployment, CI/CD
- `area: project` - Project docs and planning

## What You'll Create

### 1. Labels in GitHub
**Location:** GitHub repository settings

### 2. Automation Script
**Location:** `project/guides/github/setup/labels/setup.sh`

### 3. Guide Documentation
**Location:** `project/guides/github/setup/labels/guide.md`

## Implementation Steps

### Step 1: Understand GitHub Labels

**Time Estimate:** 20 minutes

**Research Checklist:**
- [ ] Read GitHub Labels documentation
- [ ] Review popular open-source projects' label schemes
- [ ] Review Conventional Commits specification
- [ ] Document how GitHub labels work
- [ ] Document label colors and their conventions
- [ ] Document how labels affect PR workflows
- [ ] Document label management best practices

### Step 2: Plan Label Colors

**Time Estimate:** 15 minutes

**Planning Checklist:**
- [ ] Review suggested color scheme below
- [ ] Adjust colors if needed for visual distinction
- [ ] Consider semantic meaning of colors
- [ ] Check accessibility (colorblind-friendly)
- [ ] Document final color choices and reasoning

**Suggested Color Scheme:**

**Type Labels:**
- `type: feat` - Blue (#0052CC) - New, positive
- `type: fix` - Red (#FF5630) - Fixing problems
- `type: docs` - Gray (#6B778C) - Informational
- `type: style` - Light blue (#00B8D9) - Surface-level
- `type: refactor` - Purple (#6554C0) - Transformation
- `type: test` - Green (#36B37E) - Quality assurance
- `type: chore` - Yellow (#FFAB00) - Maintenance

**Area Labels:**
- `area: backend` - Orange (#FF8B00)
- `area: extension` - Teal (#00C7B7)
- `area: frontend` - Green (#36B37E)
- `area: cli` - Blue (#0065FF)
- `area: infrastructure` - Gray (#6B778C)
- `area: project` - Purple (#8777D9)

### Step 3: Create Labels Manually in GitHub

**Time Estimate:** 30 minutes

**Setup Checklist:**
- [ ] Navigate to GitHub repository Settings → Labels

**Type Labels Creation:**
- [ ] Create `type: feat` - Description: `New features` - Color: `0052CC`
- [ ] Create `type: fix` - Description: `Bug fixes` - Color: `FF5630`
- [ ] Create `type: docs` - Description: `Documentation changes` - Color: `6B778C`
- [ ] Create `type: style` - Description: `Code style/formatting` - Color: `00B8D9`
- [ ] Create `type: refactor` - Description: `Code restructuring` - Color: `6554C0`
- [ ] Create `type: test` - Description: `Test additions/changes` - Color: `36B37E`
- [ ] Create `type: chore` - Description: `Build, tools, dependencies` - Color: `FFAB00`

**Area Labels Creation:**
- [ ] Create `area: backend` - Description: `Rails API backend` - Color: `FF8B00`
- [ ] Create `area: extension` - Description: `Browser extension` - Color: `00C7B7`
- [ ] Create `area: frontend` - Description: `Frontend SPA` - Color: `36B37E`
- [ ] Create `area: cli` - Description: `CLI tool` - Color: `0065FF`
- [ ] Create `area: infrastructure` - Description: `Docker, deployment, CI/CD` - Color: `6B778C`
- [ ] Create `area: project` - Description: `Project docs and planning` - Color: `8777D9`

**Documentation:**
- [ ] Screenshot the labels page (optional)
- [ ] Note any difficulties or confusions
- [ ] Record exact color codes used

### Step 4: Test Labels on PRs

**Time Estimate:** 15 minutes

**Testing Checklist:**
- [ ] Apply type label to existing or test PR
- [ ] Apply area label to existing or test PR
- [ ] Verify labels display correctly on PR
- [ ] Try filtering PRs by labels
- [ ] Try filtering by multiple labels
- [ ] Document what works well
- [ ] Note any issues or improvements needed

### Step 5: Create Automation Script

**Time Estimate:** 45 minutes

**Script Creation Checklist:**
- [ ] Create directory `project/guides/github/setup/labels/`
- [ ] Create file `setup.sh` in the directory
- [ ] Add script header and documentation
- [ ] Add repository variable configuration
- [ ] Add `create_label()` function
- [ ] Add all 7 type label creation calls
- [ ] Add all 6 area label creation calls
- [ ] Add success message and verification link
- [ ] Make script executable: `chmod +x setup.sh`

**Script Testing:**
- [ ] Run script against your repository
- [ ] Verify all labels created/updated correctly
- [ ] Verify colors are correct
- [ ] Verify descriptions are correct
- [ ] Document any issues encountered
- [ ] Fix any script errors

Create `project/guides/github/setup/labels/setup.sh`:

```bash
#!/bin/bash
# GitHub Labels Setup Script
# Sets up type + area label taxonomy for LinkRadar
#
# Prerequisites:
# - GitHub CLI (gh) installed and authenticated
# - Repository name set (modify REPO variable below)
#
# Usage:
#   ./setup.sh

set -e

REPO="username/link-radar"  # Update with your repo

echo "Setting up GitHub labels for $REPO..."

# Function to create or update label
create_label() {
  local name="$1"
  local color="$2"
  local description="$3"
  
  gh label create "$name" \
    --repo "$REPO" \
    --color "$color" \
    --description "$description" \
    --force
}

# Type Labels
echo "Creating type labels..."
create_label "type: feat" "0052CC" "New features"
create_label "type: fix" "FF5630" "Bug fixes"
create_label "type: docs" "6B778C" "Documentation changes"
create_label "type: style" "00B8D9" "Code style/formatting"
create_label "type: refactor" "6554C0" "Code restructuring"
create_label "type: test" "36B37E" "Test additions/changes"
create_label "type: chore" "FFAB00" "Build, tools, dependencies"

# Area Labels
echo "Creating area labels..."
create_label "area: backend" "FF8B00" "Rails API backend"
create_label "area: extension" "00C7B7" "Browser extension"
create_label "area: frontend" "36B37E" "Frontend SPA"
create_label "area: cli" "0065FF" "CLI tool"
create_label "area: infrastructure" "6B778C" "Docker, deployment, CI/CD"
create_label "area: project" "8777D9" "Project docs and planning"

echo "✅ Labels setup complete!"
echo "View labels: https://github.com/$REPO/labels"
```

### Step 6: Document in Guide

**Time Estimate:** 60 minutes

**Guide Creation Checklist:**
- [ ] Create directory `project/guides/github/setup/labels/` (if not exists)
- [ ] Create file `guide.md` in the directory
- [ ] Write Overview section
- [ ] Write Label Taxonomy section with all type labels
- [ ] Write Label Taxonomy section with all area labels  
- [ ] Write Applying Labels section with examples
- [ ] Write Manual Setup section with step-by-step
- [ ] Write Automated Setup section referencing script
- [ ] Write For Future Projects section
- [ ] Write Label Management section
- [ ] Add Examples section with screenshots/links
- [ ] Proofread and refine guide

Create `project/guides/github/setup/labels/guide.md`:

**Guide Structure:**

```markdown
# GitHub Labels Setup Guide

## Overview

Explanation of our two-axis label taxonomy and why we use it.

## Label Taxonomy

### Type Labels (Conventional Commits)
- `type: feat` - When to use, examples
- `type: fix` - When to use, examples
- [etc for each type]

### Area Labels (Monorepo Structure)
- `area: backend` - When to use, examples
- `area: extension` - When to use, examples
- [etc for each area]

## Applying Labels

### During PR Creation
1. Review your changes
2. Select one type label
3. Select one or more area labels
4. Both are typically required

### Label Combinations
Examples of common combinations:
- `type: feat` + `area: backend` - New backend feature
- `type: fix` + `area: extension` - Browser extension bug fix
- `type: docs` + `area: project` - Project documentation update

## Manual Setup

Step-by-step instructions for creating labels via GitHub UI.

## Automated Setup

How to use the setup script:
```bash
cd project/guides/github/labels
./setup.sh
```

## For Future Projects

How to adapt this label scheme:
- Modify for different monorepo structures
- Add/remove types as needed
- Adjust colors for team preferences

## Label Management

- When to add new labels
- How to deprecate old labels
- Keeping labels consistent

## Examples

Screenshots or links showing:
- PRs with proper labeling
- Filtered views by label
- Good label usage patterns
```

## Deliverables

- [ ] All 13 labels created in GitHub
- [ ] `project/guides/github/setup/labels/setup.sh` - Executable automation script
- [ ] `project/guides/github/setup/labels/guide.md` - Complete documentation
- [ ] Script tested and verified
- [ ] Superthread card #129 moved to "Done"

## Success Criteria

- ✅ All type and area labels exist in GitHub
- ✅ Labels have appropriate colors and descriptions
- ✅ Automation script successfully creates labels
- ✅ Guide documents taxonomy and usage
- ✅ Ready to use labels on all PRs
- ✅ Foundation for Phase 2 label enforcement

## Time Estimate

**Total:** ~3 hours

## Next Steps

After completing this plan:
1. Move Superthread card #129 to "Done"
2. Proceed to Plan 3 (Development Workflow Documentation)
3. Start using labels on all PRs

## Notes

- The script uses `--force` to update existing labels without errors
- Colors are chosen for visual distinction and semantic meaning
- Labels work with GitHub's search and filter features
- This taxonomy can easily scale to team use

