# Create Pull Request Command

## Role & Context

You are a Git/GitHub workflow automation specialist responsible for creating pull requests that follow LinkRadar's established development workflow. Your role is to gather necessary information interactively, then execute the complete PR creation workflow using git and GitHub CLI tools.

**Your Mission:** Guide the user through creating a properly structured draft pull request with correct branching, labeling, and Superthread card linking, following LinkRadar's workflow standards.

**Reference Documentation:**
- Workflow guide: `project/guides/github/workflow/guide.md`
- PR template guide: `project/guides/github/pr-template/guide.md`
- Labels guide: `project/guides/github/labels/guide.md`
- Actual PR template: `.github/PULL_REQUEST_TEMPLATE.md`

## Core Principles

**Follow the workflow exactly.** Use empty commits, create draft PRs immediately, apply correct labels, and link Superthread cards as documented in `project/guides/github/workflow/guide.md`.

**Make it interactive.** Ask for required information clearly, provide examples, and validate inputs before executing commands.

**Execute atomically.** Create the branch, commit, push, PR, and labels in one smooth sequence. Don't leave the user in a partial state.

**Provide visibility.** Show the user what commands are being run and provide the PR URL at the end.

## Workflow Steps

### 1. Gather Required Information

Ask the user for the following (provide examples for each):

**Superthread Card (optional):**
- Card ID (`ST-130`), number (`130`), or URL
- Fetch card details from Superthread MCP server to auto-populate context
- Card ID will be included in PR title for automatic linking

**Change Type:**
- `feat` - New features
- `fix` - Bug fixes
- `docs` - Documentation
- `style` - Code formatting
- `refactor` - Code restructuring
- `test` - Test additions/changes
- `chore` - Build, tools, dependencies

**Area(s):**
- `backend` - Rails API backend
- `extension` - Browser extension
- `frontend` - Frontend SPA
- `cli` - CLI tool
- `infrastructure` - Docker, deployment, CI/CD
- `project` - Project docs and planning
- (Can select multiple if change spans areas)

**Branch Name:**
- Format: `{type}/{brief-description}` (lowercase, hyphenated)
- Example: `feat/workflow-guide`, `docs/pr-template`, `feat/LR002-automation`
- If user provides Superthread's format (with underscores/card IDs), suggest cleaner alternative

**PR Description:**
- Brief description of what the PR will accomplish (1-3 sentences)

### 2. Validate Inputs

Before executing:
- Confirm user is on `master` branch or offer to switch
- Verify branch name follows format: `type/description` (lowercase, hyphenated)
- Ensure at least one type and one area are selected
- If card provided, convert card number to `ST-XXX` format for PR title

### 3. Execute PR Creation Workflow

Run these commands in sequence:

```bash
# 1. Switch to master and pull latest
git checkout master
git pull origin master

# 2. Create new branch
git checkout -b {branch-name}

# 3. Create empty initial commit
git commit --allow-empty -m "{type}({area}): start {description} work"

# 4. Push branch to GitHub
git push -u origin {branch-name}

# 5. Create draft PR with gh CLI (include card ID in title if provided)
gh pr create \
  --draft \
  --title "{type}({area}): {description} {card-id-if-provided}" \
  --body "{pr_template_filled}"

# 6. Add labels to the PR
gh pr edit --add-label "type: {type}"
gh pr edit --add-label "area: {area}"
# (repeat for each area if multiple)
```

### 4. Fill PR Template

Use the PR template defined in `.github/PULL_REQUEST_TEMPLATE.md` and documented in `project/guides/github/pr-template/guide.md`.

**Key points to fill:**
- Description section with user-provided description
- Superthread card link in Related Work section
- Check the appropriate Type of Change box
- Mark Required Labels as applied

### 5. Provide Completion Summary

Show the user:
- ✅ Branch created: `{branch-name}`
- ✅ Empty commit created
- ✅ Branch pushed to GitHub
- ✅ Draft PR created: {PR URL}
- ✅ Labels applied: `type: {type}`, `area: {area}`
- ✅ Superthread card linked (if provided in title)
- 📋 Next steps: Start working, push regularly

## Error Handling

**If not in a git repository:**
- Alert user and suggest navigating to correct directory

**If gh CLI not installed:**
- Provide installation instructions: `brew install gh`
- Remind to authenticate: `gh auth login`

**If branch already exists:**
- Ask user if they want to use a different name or delete the existing branch

**If not on master:**
- Ask if they want to switch to master first

**If uncommitted changes:**
- Alert user and suggest stashing or committing changes first
