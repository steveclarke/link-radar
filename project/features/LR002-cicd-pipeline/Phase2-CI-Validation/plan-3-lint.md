# Plan 3: Lint Checker

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Superthread Card:** TBD  
**Status:** Ready to Execute

## Goal

Create a GitHub Actions workflow that automatically validates YAML and Markdown file syntax on every PR. This catches common formatting errors before they're merged and maintains code quality standards.

## Why This Matters

Automated linting:
- **Catches errors early** - Syntax errors found before merge
- **Maintains consistency** - All files follow same formatting standards
- **Prevents breaks** - Invalid YAML can break workflows/configs
- **Improves quality** - Enforces best practices automatically
- **Saves time** - No manual file review needed

This is especially important for:
- GitHub Actions workflow files (`.github/workflows/*.yml`)
- Documentation files (`*.md`)
- Configuration files (`*.yml`, `*.yaml`)

## What You'll Check

### YAML Files
**Tools:** `yamllint` or `actionlint`

**Files to check:**
- `.github/workflows/*.yml` - GitHub Actions workflows
- `*.yml`, `*.yaml` - Configuration files
- `compose.yml` - Docker Compose files

**Common errors to catch:**
- Syntax errors (invalid YAML)
- Indentation issues
- Duplicate keys
- Trailing spaces
- Line length violations

### Markdown Files  
**Tools:** `markdownlint` or `remark-lint`

**Files to check:**
- `README.md`
- `project/**/*.md`
- `*.md` throughout repo

**Common errors to catch:**
- Heading hierarchy issues
- Missing blank lines
- Inconsistent list formatting
- Trailing spaces
- Multiple consecutive blank lines

## What You'll Create

### 1. GitHub Actions Workflow
**Location:** `.github/workflows/lint.yml`

**Triggers:**
- `pull_request` (opened, synchronize, reopened)
- `push` to master (for catching issues on merge)

**Jobs:**
- Lint YAML files
- Lint Markdown files
- Report results as status check

### 2. Linter Configuration Files
**Locations:**
- `.yamllint.yml` - YAML linting rules
- `.markdownlint.json` - Markdown linting rules

**Purpose:**
- Customize rules to match project needs
- Disable overly strict rules
- Document exceptions

### 3. Documentation
**Location:** Update development guides

**Add:**
- How to run linters locally
- How to fix common linting errors
- How to configure IDE integrations

## Implementation Steps

### Step 1: Research and Choose Linters

**Time Estimate:** 30 minutes

**YAML Linting Options:**
- `yamllint` - Python-based, highly configurable
- `actionlint` - Specifically for GitHub Actions workflows
- Both? Use `actionlint` for workflows, `yamllint` for other YAML

**Markdown Linting Options:**
- `markdownlint-cli` - JavaScript-based, popular
- `remark-lint` - More extensible but complex
- `mdl` - Ruby-based

**Recommendation:** 
- YAML: `actionlint` (workflows are critical)
- Markdown: `markdownlint-cli` (simple and effective)

### Step 2: Create Configuration Files

**Time Estimate:** 45 minutes

**Create `.yamllint.yml`:**

```yaml
---
extends: default

rules:
  line-length:
    max: 120
    level: warning
  
  indentation:
    spaces: 2
    indent-sequences: true
  
  comments:
    min-spaces-from-content: 1
  
  document-start: disable
  truthy: disable  # Allow 'on:' in GitHub Actions
```

**Create `.markdownlint.json`:**

```json
{
  "default": true,
  "MD013": {
    "line_length": 120,
    "heading_line_length": 80,
    "code_block_line_length": 120,
    "tables": false
  },
  "MD033": false,
  "MD041": false,
  "MD046": {
    "style": "fenced"
  }
}
```

**Explanation:**
- `MD013`: Line length (relaxed to 120)
- `MD033`: Allow inline HTML (useful for GitHub features)
- `MD041`: First line doesn't need to be H1 (allow frontmatter)
- `MD046`: Prefer fenced code blocks (```)

### Step 3: Create the Workflow

**Time Estimate:** 60 minutes

Create `.github/workflows/lint.yml`:

```yaml
name: Lint

on:
  pull_request:
    types: [opened, synchronize, reopened]
  push:
    branches: [master]

jobs:
  yaml-lint:
    name: Lint YAML
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Run actionlint
        uses: reviewdog/action-actionlint@v1
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          reporter: github-pr-review
          fail_on_error: true
      
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      
      - name: Install yamllint
        run: pip install yamllint
      
      - name: Run yamllint
        run: yamllint .

  markdown-lint:
    name: Lint Markdown
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Run markdownlint
        uses: DavidAnson/markdownlint-cli2-action@v17
        with:
          globs: '**/*.md'
```

**Features:**
- Separate jobs for YAML and Markdown (can run in parallel)
- Uses proven actions from marketplace
- Integrates with PR reviews
- Fails on errors (blocks merge)

### Step 4: Test the Workflow

**Time Estimate:** 60 minutes

**Test Case 1: Valid files**
- Create PR with properly formatted YAML and Markdown
- Verify both checks pass

**Test Case 2: Invalid YAML**
- Create file with bad YAML syntax:
  ```yaml
  # Bad indentation
  name: Test
    bad: indentation
  ```
- Verify workflow fails with helpful error

**Test Case 3: Invalid Markdown**
- Create file with markdown issues:
  ```markdown
  # Title
  No blank line before list
  - Item 1
  - Item 2
  ```
- Verify workflow fails with helpful error

**Test Case 4: Fix and retest**
- Fix the errors
- Push changes
- Verify checks now pass

### Step 5: Add Local Development Support

**Time Estimate:** 30 minutes

**Create scripts for local linting:**

**`scripts/lint-yaml.sh`:**
```bash
#!/bin/bash
# Lint YAML files locally

set -e

echo "Installing yamllint..."
pip install yamllint

echo "Linting YAML files..."
yamllint .

echo "✅ YAML linting passed!"
```

**`scripts/lint-markdown.sh`:**
```bash
#!/bin/bash
# Lint Markdown files locally

set -e

echo "Installing markdownlint-cli2..."
npm install -g markdownlint-cli2

echo "Linting Markdown files..."
markdownlint-cli2 '**/*.md'

echo "✅ Markdown linting passed!"
```

**Make executable:**
```bash
chmod +x scripts/lint-*.sh
```

### Step 6: Update Documentation

**Time Estimate:** 45 minutes

**Create `project/guides/development/linting.md`:**

```markdown
# Linting Guide

## Overview

We use automated linters to maintain code quality and consistency.

## Running Locally

**Lint YAML files:**
```bash
./scripts/lint-yaml.sh
```

**Lint Markdown files:**
```bash
./scripts/lint-markdown.sh
```

**Lint everything:**
```bash
./scripts/lint-yaml.sh && ./scripts/lint-markdown.sh
```

## IDE Integration

### VS Code

Install these extensions:
- [YAML](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)
- [markdownlint](https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint)

### IntelliJ/RubyMine

Enable built-in linters:
- Settings → Editor → Inspections → YAML
- Settings → Editor → Inspections → Markdown

## Common Issues

### YAML: "line too long"

**Problem:** Lines exceed 120 characters

**Fix:** Break long lines using YAML's folding:
```yaml
# Before
description: This is a very long description that exceeds the line length limit

# After
description: >
  This is a very long description that exceeds
  the line length limit
```

### Markdown: "MD013/line-length"

**Problem:** Lines exceed 120 characters

**Fix:** Break long lines (wrap text) or disable for specific blocks:
```markdown
<!-- markdownlint-disable MD013 -->
This line can be as long as needed
<!-- markdownlint-enable MD013 -->
```

### YAML: "truthy value should be quoted"

**Problem:** `on:` in GitHub Actions triggers this

**Fix:** Already disabled in `.yamllint.yml`

## Configuration

**YAML:** See `.yamllint.yml`  
**Markdown:** See `.markdownlint.json`

## Disabling Rules

**Per-file (Markdown):**
```markdown
<!-- markdownlint-disable MD013 -->
Content here...
<!-- markdownlint-enable MD013 -->
```

**Per-file (YAML):**
```yaml
# yamllint disable-line rule:line-length
long_line: "This line is allowed to be long"
```
```

### Step 7: Handle Edge Cases

**Time Estimate:** 30 minutes

**Consider:**
- Should `node_modules/` be excluded? (Yes, add to `.markdownlintignore`)
- Should generated files be excluded? (Yes, add to ignore files)
- Should vendor directories be excluded? (Yes)

**Create `.markdownlintignore`:**
```
node_modules/
vendor/
.bundle/
tmp/
```

**Create `.yamlignore` or use excludes in config:**
```yaml
ignore: |
  node_modules/
  vendor/
  .bundle/
```

## Deliverables

- [ ] `.github/workflows/lint.yml` - Lint workflow
- [ ] `.yamllint.yml` - YAML linting configuration
- [ ] `.markdownlint.json` - Markdown linting configuration
- [ ] `scripts/lint-yaml.sh` - Local YAML linting script
- [ ] `scripts/lint-markdown.sh` - Local Markdown linting script
- [ ] `project/guides/development/linting.md` - Linting documentation
- [ ] Test PRs demonstrating passing and failing lint checks

## Success Criteria

- ✅ Workflow runs on every PR
- ✅ Invalid YAML files fail the check
- ✅ Invalid Markdown files fail the check
- ✅ Valid files pass the check
- ✅ Error messages are helpful and actionable
- ✅ Developers can run linters locally
- ✅ IDE integration documented

## Time Estimate

**Total:** ~4.5 hours

## Next Steps

After completing this plan:
1. Test with real PRs
2. Proceed to Plan 4 (Update Branch Protection)
3. Add this check to branch protection as a required status check

## References

- [yamllint Documentation](https://yamllint.readthedocs.io/)
- [actionlint Documentation](https://github.com/rhysd/actionlint)
- [markdownlint Documentation](https://github.com/DavidAnson/markdownlint)
- [markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2)

