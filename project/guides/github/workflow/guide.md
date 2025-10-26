# Git/GitHub Development Workflow

This guide documents how we use Git and GitHub for LinkRadar development. It covers everything from creating branches to merging pull requests, with a focus on practices that keep work visible, prevent lost code, and enable smooth collaboration.

## Why This Workflow Matters

Good workflow practices aren't just bureaucracy—they're your safety net. When you commit frequently and create draft PRs immediately, you're protecting your work and making progress visible. When you follow consistent naming conventions, you make it easy to understand what's happening across the project. And when you integrate with Superthread properly, you get automatic status updates that save you from manual card shuffling.

This workflow has three core goals:

1. **Never lose work** - Commit often, push regularly, work is always backed up
2. **Make progress visible** - Draft PRs show what's happening, even mid-development
3. **Enable automation** - Consistent patterns let tools help you

Now let's walk through how we do this.

## Branching Strategy

Every piece of work starts with a new branch from `master`. Our branches follow a specific naming pattern that serves two purposes: it tells you what kind of work is happening, and it connects to Superthread for automatic tracking.

### Branch Naming Format

```
{type}/ST-{card-number}-{brief-description}
```

**Examples:**
- `feat/ST-128-add-user-authentication`
- `fix/ST-145-resolve-link-validation`
- `docs/ST-130-create-workflow-guide`
- `chore/ST-156-update-ruby-version`

The `ST-XXX` part is critical—it enables Superthread to automatically link your branch and PR to the card. When the PR merges, Superthread updates the card status automatically.

### Branch Types

- **feat/** - New features or functionality
- **fix/** - Bug fixes
- **docs/** - Documentation changes
- **style/** - Code formatting (no logic changes)
- **refactor/** - Code restructuring (no behavior changes)
- **test/** - Adding or modifying tests
- **chore/** - Build tools, dependencies, configurations

### Working with Superthread Branch Names

Superthread provides a "Copy git branch name" button on each card that gives you a suggested name like `st-130_lr002_p3_document_development_workflow`. This works for auto-linking, but we prefer our own format for consistency.

**When you get Superthread's name:**
1. Note the card number (e.g., `130`)
2. Determine the work type (e.g., `docs`)
3. Create a brief description (e.g., `workflow-guide`)
4. Use our format: `docs/ST-130-workflow-guide`

You get both our consistent naming AND Superthread's automatic linking.

### Master Branch Protection

The `master` branch is always deployable. It's protected, meaning you can't push directly to it—all changes come through pull requests. This keeps master stable and gives you a known-good state to build from.

**Creating a new branch:**
```bash
git checkout master
git pull origin master
git checkout -b feat/ST-128-add-user-auth
```

## Commit Conventions

We use Conventional Commits—a standardized format that makes commit history readable and enables automated tooling. Each commit message tells you what changed and where.

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type:** Same as branch prefixes (feat, fix, docs, etc.)  
**Scope:** Which part of the codebase (optional but recommended)  
**Subject:** Brief description, imperative mood, no period  
**Body:** Detailed explanation (optional)  
**Footer:** References to issues or cards (optional)

### Scopes

Match your monorepo structure:
- `backend` - Rails API
- `extension` - Browser extension
- `frontend` - Frontend SPA
- `cli` - Command-line tool
- `infrastructure` - Docker, deployment, CI/CD
- `project` - Project documentation

### Examples

**Adding a feature:**
```
feat(backend): add link archival endpoint

Implement POST /api/v1/links/:id/archive endpoint to allow
marking links as archived without deletion. Includes validation
and database migration.

Closes #42
```

**Fixing a bug:**
```
fix(extension): resolve popup not opening on Firefox

The popup.html failed to load on Firefox due to CSP issues.
Updated manifest.json with proper permissions.
```

**Updating dependencies:**
```
chore(infrastructure): update Docker base image to Ruby 3.4.2

Bump base image for security patches and performance improvements.
```

**Simple documentation change:**
```
docs(project): fix typo in workflow guide
```

### Writing Good Commit Messages

**Use imperative mood** - "Add feature" not "Added feature" or "Adds feature"  
**Keep subjects under 50 characters** - Be concise  
**Capitalize the subject** - "Add feature" not "add feature"  
**No period at the end** - Save the character  
**Use the body to explain why** - Not how (code shows how)

### Commit Frequency: The Most Important Practice

Here's the rule that matters most: **commit multiple times per day when actively working**.

Aim for 3-5+ commits during a work session. Commit after each logical change or milestone. Never end the day with uncommitted work. Small, incremental commits are better than large ones.

**Why this matters:**
- **Backup** - Every commit is saved. Computer dies? Your work is on GitHub.
- **History** - Small commits are easier to review and understand
- **Revert** - Easy to undo specific changes without losing everything
- **Visibility** - Others can see progress in the draft PR

Think of commits like save points in a game—you want plenty of them.

**Good commit patterns:**
```bash
# Morning: Start work
git commit -m "feat(backend): add archival endpoint skeleton"

# Mid-morning: Add validation
git commit -m "feat(backend): add archival validation logic"

# Before lunch: Add tests
git commit -m "test(backend): add archival endpoint tests"

# Afternoon: Handle edge cases
git commit -m "feat(backend): handle already-archived links"

# End of day: Update docs
git commit -m "docs(backend): document archival API endpoint"
```

That's 5 commits in one day—all saved, all visible in your draft PR, all recoverable if needed.

## Pull Request Process

This is where our workflow differs from traditional approaches. Instead of waiting until work is "done" to create a PR, we create a **draft PR immediately** when starting work. This makes your work visible, enables early feedback, and ensures nothing gets lost.

### The Complete Workflow

**1. Start the Superthread card**  
Move it to "In Progress" so the team knows you're working on it.

**2. Create your branch**
```bash
git checkout master
git pull origin master
git checkout -b feat/ST-128-add-user-auth
```

**3. Make an empty commit**  
GitHub requires at least one commit to create a PR. We use an empty commit to enable immediate PR creation:
```bash
git commit --allow-empty -m "feat(backend): initialize user authentication"
```

**4. Push the branch**
```bash
git push -u origin feat/ST-128-add-user-auth
```

**5. Create a draft PR immediately**
```bash
gh pr create --draft
```

GitHub will prompt you to fill out the PR template. Do your best—you can refine it later.

**6. Add labels**  
Every PR needs two types of labels:
- **Type label:** `type: feat`, `type: fix`, `type: docs`, etc.
- **Area label:** `area: backend`, `area: extension`, etc.

Apply them in the GitHub UI or with:
```bash
gh pr edit --add-label "type: feat" --add-label "area: backend"
```

**7. Link to Superthread**  
Because you included `ST-128` in your branch name, Superthread automatically links the PR to the card. You'll see the PR appear on the card, and the card will update when you merge.

**8. Now do the actual work**  
Code, test, and commit frequently. Push your commits regularly (at minimum, end of each day).

**9. Mark ready for review**  
When the work is complete, mark the PR as "Ready for review" in GitHub.

**10. Self-review**  
Use GitHub's review feature to review your own code. Look at the diff as if someone else wrote it.

**11. Merge when ready**  
Use squash merge to combine all commits into one clean commit in master.

**12. Delete the branch**  
GitHub offers to delete it after merging. Click that button.

### Why Draft PRs From Day One?

**Makes work visible** - Your team (or future you) can see what's happening  
**Enables early feedback** - Catch issues before you've invested too much time  
**Acts as backup** - All your commits are on GitHub, not just your laptop  
**Shows progress** - Superthread card displays PR status and activity  
**Prevents surprises** - No large, unexpected PRs dropped at the last minute  
**Allows CI to run** - Automated checks can run as you work (when you add them)

### PR Template

Our PR template (`.github/PULL_REQUEST_TEMPLATE.md`) loads automatically. It includes:

- **Description** - What this PR does and why
- **Related Work** - Link to Superthread card (required)
- **Type of Change** - Check the box matching your commit type
- **Required Labels** - Reminder to add type + area labels
- **Testing** - Checklist before marking ready for review
- **Additional Notes** - Screenshots, breaking changes, migration notes

Fill it out as completely as you can when creating the draft. You can always edit it later as the work evolves.

> **Tip:** See `project/guides/github/pr-template/guide.md` for detailed guidance on filling out the template.

## Labeling

Labels help organize and filter PRs. We use a two-axis system that combines what kind of change (type) with where in the codebase (area).

### Label Requirements

**Every PR must have:**
1. One type label (`type: feat`, `type: fix`, etc.)
2. At least one area label (`area: backend`, `area: extension`, etc.)

Multiple area labels are fine if your change spans modules. For example, a refactor touching both backend and extension gets both `area: backend` and `area: extension`.

### Type Labels

| Label | Use For |
|-------|---------|
| `type: feat` | New features |
| `type: fix` | Bug fixes |
| `type: docs` | Documentation |
| `type: style` | Code formatting |
| `type: refactor` | Code restructuring |
| `type: test` | Test changes |
| `type: chore` | Build, tools, dependencies |

### Area Labels

| Label | Use For |
|-------|---------|
| `area: backend` | Rails API backend |
| `area: extension` | Browser extension |
| `area: frontend` | Frontend SPA |
| `area: cli` | CLI tool |
| `area: infrastructure` | Docker, deployment, CI/CD |
| `area: project` | Project documentation |

### Common Combinations

- `type: feat` + `area: backend` - New API endpoint
- `type: fix` + `area: extension` - Extension bug fix
- `type: docs` + `area: project` - Documentation update
- `type: chore` + `area: infrastructure` - Docker configuration change
- `type: refactor` + `area: backend` + `area: extension` - Cross-cutting refactor

> **Reference:** See `project/guides/github/labels/guide.md` for the complete label taxonomy.

## Code Review

Even when working solo, treat code review as an essential step. Future you needs to understand what past you was thinking.

### Before Requesting Review

- [ ] All tests pass locally
- [ ] No linter errors
- [ ] Code is self-documented or commented where needed
- [ ] PR description is complete and accurate
- [ ] Labels are applied (type + area)
- [ ] You've pushed all commits

### Self-Review Checklist

Use GitHub's review feature to review your own code before merging. Go through the diff file by file and ask:

**Code Quality:**
- Is the code doing what it should?
- Are there any obvious bugs or edge cases missed?
- Is it readable? Would someone else understand it?
- Are variable and function names clear?

**Testing:**
- Do the tests cover the important cases?
- Are there edge cases that need tests?
- Do all tests pass?

**Performance:**
- Are there any obvious performance issues?
- Database queries efficient?
- Unnecessary loops or operations?

**Security:**
- Any security implications?
- User input properly validated?
- Secrets properly handled?

**Documentation:**
- Is the code self-explanatory?
- Are complex parts commented?
- Does the PR description explain why?

**Architecture:**
- Does this fit with the overall system design?
- Are we creating tech debt?
- Would this make sense to someone new?

### Addressing Your Own Feedback

If you find issues during self-review, fix them! Add commits addressing the problems, push them, and review again.

Don't be afraid to catch your own mistakes. That's the point.

## Merging

We use squash merges for all PRs. This means all your individual commits get combined into a single commit when merged to master.

### Why Squash Merge?

**Clean history** - Master shows one commit per PR, not all the "fix typo" commits  
**Easy to understand** - Each commit represents a complete change  
**Simple to revert** - Undo an entire feature with one revert  
**Professional** - History is easy to review and understand  
**Good messages** - You can craft a great commit message at merge time

Your branch keeps all the individual commits for reference. Master gets a clean, linear history.

### Squash Commit Message Format

When you squash merge, GitHub asks for a commit message. Use this format:

```
<type>(<scope>): <description> (#PR-number)

* Key change 1
* Key change 2
* Key change 3

Superthread Card: [URL]
```

**Example:**
```
feat(backend): add link archival endpoint (#42)

* Implement POST /api/v1/links/:id/archive endpoint
* Add database migration for archived_at column
* Include validation and comprehensive tests
* Update API documentation

Superthread Card: https://clevertakes.superthread.com/card/128
```

### Merge Checklist

Before clicking that merge button:

- [ ] All CI checks pass (when you have them)
- [ ] PR is marked "Ready for review" (not draft)
- [ ] Self-review is complete
- [ ] Tests pass
- [ ] No linter errors
- [ ] Labels are applied
- [ ] Superthread card is linked

### After Merging

1. **Delete the branch** - GitHub offers a button after merge. Click it.
2. **Check Superthread** - The card should update automatically
3. **Pull master locally** - Get the merged changes: `git checkout master && git pull`

## Release Tagging

When you're ready to release a version to production (or the Chrome Web Store, or Docker Hub), create a Git tag. Tags mark specific points in history as releases.

### Semantic Versioning

We use semantic versioning: `vMAJOR.MINOR.PATCH`

**MAJOR** - Breaking changes (v2.0.0)  
**MINOR** - New features, backward compatible (v1.3.0)  
**PATCH** - Bug fixes (v1.2.1)

Examples:
- `v1.0.0` - Initial release
- `v1.1.0` - Added user authentication (new feature)
- `v1.1.1` - Fixed login bug (bug fix)
- `v2.0.0` - Changed API format (breaking change)

### When to Tag

- After merging feature PRs when ready for production
- When releasing to users
- When deploying to an environment that needs version tracking
- After significant milestones

You don't tag every PR—only when you're actually releasing something.

### Creating Tags

```bash
# Make sure you're on master with latest
git checkout master
git pull origin master

# Create an annotated tag with a message
git tag -a v1.2.0 -m "Release v1.2.0: Add link archival feature"

# Push the tag to GitHub
git push origin v1.2.0
```

### Tag Message Format

Include a summary of what's in this release:

```
Release v1.2.0: Brief description

New Features:
- Feature 1
- Feature 2

Bug Fixes:
- Fix 1
- Fix 2

Breaking Changes:
- Breaking change 1 (if any)
```

**Example:**
```bash
git tag -a v1.2.0 -m "Release v1.2.0: Add archival and export features

New Features:
- Link archival endpoint
- Bulk export to CSV
- Browser extension dark mode

Bug Fixes:
- Fixed link validation regex
- Resolved extension popup sizing"

git push origin v1.2.0
```

## Common Scenarios

Here are complete workflows for typical situations.

### Scenario: Building a New Feature

You're adding a link archival feature. Superthread card ST-142 is ready to go.

**Step by step:**

```bash
# 1. Make sure you're starting fresh
git checkout master
git pull origin master

# 2. Create branch with Superthread card ID
git checkout -b feat/ST-142-add-link-archival

# 3. Create empty commit for PR creation
git commit --allow-empty -m "feat(backend): initialize link archival feature"

# 4. Push and create draft PR
git push -u origin feat/ST-142-add-link-archival
gh pr create --draft

# 5. Add labels
gh pr edit --add-label "type: feat" --add-label "area: backend"

# 6. Start working - commit frequently!
# Morning: skeleton
git commit -m "feat(backend): add archival endpoint skeleton"
git push

# Mid-morning: validation
git commit -m "feat(backend): add archival validation logic"
git push

# Before lunch: tests
git commit -m "test(backend): add archival endpoint tests"
git push

# Afternoon: edge cases
git commit -m "feat(backend): handle already-archived links"
git push

# End of day: docs
git commit -m "docs(backend): document archival API endpoint"
git push

# 7. When complete, mark ready
gh pr ready

# 8. Self-review the diff on GitHub

# 9. Merge when satisfied
gh pr merge --squash

# 10. Clean up
git checkout master
git pull
git branch -d feat/ST-142-add-link-archival
```

Superthread card ST-142 automatically updates to "Done" when you merge.

### Scenario: Quick Bug Fix

The extension popup won't open on Firefox. Card ST-156.

```bash
# Create branch
git checkout master && git pull
git checkout -b fix/ST-156-firefox-popup

# Empty commit for PR
git commit --allow-empty -m "fix(extension): initialize Firefox popup fix"
git push -u origin fix/ST-156-firefox-popup

# Create draft PR with labels
gh pr create --draft
gh pr edit --add-label "type: fix" --add-label "area: extension"

# Fix the issue
# (edit manifest.json)
git commit -m "fix(extension): update CSP for Firefox compatibility"
git push

# Test and verify
git commit -m "test(extension): verify popup opens on Firefox"
git push

# Mark ready, review, merge
gh pr ready
gh pr merge --squash
```

Even for "quick" fixes, we follow the workflow. The draft PR takes 30 seconds and ensures your fix is documented and tracked.

### Scenario: Documentation Update

Updating the workflow guide itself. Card ST-130.

```bash
# Standard workflow applies to docs too
git checkout master && git pull
git checkout -b docs/ST-130-update-workflow-guide

git commit --allow-empty -m "docs(project): initialize workflow guide updates"
git push -u origin docs/ST-130-update-workflow-guide

gh pr create --draft
gh pr edit --add-label "type: docs" --add-label "area: project"

# Make changes - commit as you go
git commit -m "docs(project): add Superthread integration section"
git push

git commit -m "docs(project): update branching examples"
git push

git commit -m "docs(project): clarify commit frequency practices"
git push

gh pr ready
gh pr merge --squash
```

### Scenario: Changes Spanning Multiple Areas

Refactoring authentication logic that touches both backend and extension.

Create the branch and PR as usual, but add multiple area labels:

```bash
gh pr edit --add-label "type: refactor" \
           --add-label "area: backend" \
           --add-label "area: extension"
```

The labels accurately reflect that this change impacts multiple parts of the codebase.

## Troubleshooting

### Merge Conflicts

When your branch conflicts with master (someone else merged changes to the same files):

```bash
# Update your local master
git checkout master
git pull origin master

# Go back to your branch and merge master in
git checkout feat/ST-142-add-link-archival
git merge master

# Git will tell you which files conflict
# Edit those files, look for conflict markers:
# <<<<<<< HEAD
# your changes
# =======
# their changes
# >>>>>>> master

# After fixing conflicts:
git add [fixed-files]
git commit -m "fix: resolve merge conflicts with master"
git push
```

If you're not sure how to resolve a conflict, ask! Better to pause than to lose someone's work.

### Wrong Branch Name

You created a branch but forgot the card ID or used the wrong type:

```bash
# Rename the local branch
git branch -m old-name new-name

# Delete the old remote branch
git push origin --delete old-name

# Push the new branch name
git push -u origin new-name
```

### Forgot to Create Draft PR

You've been working for hours and forgot to create the PR. No problem:

```bash
# Push your branch
git push -u origin feat/ST-142-whatever

# Create the PR (no longer draft since work is done)
gh pr create

# Add labels
gh pr edit --add-label "type: feat" --add-label "area: backend"
```

It's not ideal (should have been draft from the start), but you didn't lose anything.

### Uncommitted Work at End of Day

It's 5pm and you have uncommitted changes. Don't leave them uncommitted!

```bash
# Commit whatever state you're in
git add .
git commit -m "feat(backend): work in progress on validation logic"
git push

# Add a note in the PR that this is incomplete
```

It's fine to commit work-in-progress. That's what draft PRs are for. The important thing is getting it off your laptop.

### Accidentally Committed to Master

You committed directly to master instead of a branch:

```bash
# DON'T PUSH!

# Create a new branch from master
git branch feat/ST-142-whatever

# Reset master to match remote
git checkout master
git reset --hard origin/master

# Switch to your new branch with your commits
git checkout feat/ST-142-whatever
```

Your commits are now on a proper branch and master is clean.

## Quick Reference

### Daily Workflow Checklist

Starting new work:
- [ ] Pull latest master
- [ ] Create branch: `{type}/ST-{number}-{description}`
- [ ] Empty commit: `git commit --allow-empty -m "..."`
- [ ] Push branch
- [ ] Create draft PR: `gh pr create --draft`
- [ ] Add labels (type + area)

During work:
- [ ] Commit 3-5+ times per day
- [ ] Push at end of each work session
- [ ] Never leave uncommitted work overnight

Finishing work:
- [ ] Mark PR ready: `gh pr ready`
- [ ] Self-review the diff
- [ ] Merge: `gh pr merge --squash`
- [ ] Delete branch

### Essential Commands

```bash
# Starting work
git checkout master && git pull
git checkout -b feat/ST-XXX-description
git commit --allow-empty -m "feat(scope): initialize feature"
git push -u origin feat/ST-XXX-description
gh pr create --draft
gh pr edit --add-label "type: feat" --add-label "area: backend"

# During work
git add .
git commit -m "feat(scope): descriptive message"
git push

# Finishing work
gh pr ready
gh pr merge --squash
git checkout master && git pull
git branch -d feat/ST-XXX-description

# Creating a release
git checkout master && git pull
git tag -a v1.2.0 -m "Release v1.2.0: Description"
git push origin v1.2.0
```

### Branch Naming Examples

| Scenario | Branch Name |
|----------|-------------|
| Add user authentication | `feat/ST-128-add-user-auth` |
| Fix extension popup | `fix/ST-156-firefox-popup` |
| Update documentation | `docs/ST-130-workflow-guide` |
| Refactor API client | `refactor/ST-167-api-client` |
| Update dependencies | `chore/ST-189-update-deps` |
| Add missing tests | `test/ST-145-link-validation` |

### Commit Message Examples

| Scenario | Commit Message |
|----------|----------------|
| Add new feature | `feat(backend): add link archival endpoint` |
| Fix a bug | `fix(extension): resolve popup sizing on Firefox` |
| Update docs | `docs(project): add Superthread integration guide` |
| Refactor code | `refactor(backend): extract link validation to service` |
| Update deps | `chore(infrastructure): update Ruby to 3.4.2` |
| Add tests | `test(backend): add archival endpoint tests` |

## For Future Team Members

When LinkRadar grows beyond solo development, new team members will use this guide to understand our workflow. Here's what they need to know.

### Onboarding Checklist

New team members should:
- [ ] Read this entire workflow guide
- [ ] Review the PR template guide (`project/guides/github/pr-template/guide.md`)
- [ ] Review the labels guide (`project/guides/github/labels/guide.md`)
- [ ] Install and authenticate with GitHub CLI: `gh auth login`
- [ ] Connect their Superthread account to GitHub (Settings > Integrations)
- [ ] Practice the workflow with a small documentation PR

### Critical Practices

These are non-negotiable—everyone follows them:

**Create draft PRs immediately** - When you start work, not when you finish  
**Commit multiple times per day** - 3-5+ commits minimum when actively working  
**Never leave uncommitted work** - Push at end of each day  
**Include card IDs in branches** - `{type}/ST-{number}-{description}` format  
**All work visible in draft PRs** - No surprise PRs at the end

These practices protect everyone's work and keep the team aligned.

### Getting Help

**Merge conflicts?** Ask before force-pushing or making destructive changes  
**Not sure about branch name?** Ask before creating the PR  
**Commit message unclear?** Ask before pushing  
**PR review feedback?** Discuss before implementing major changes

It's better to ask than to create problems for yourself or others.

### Team Practices

As the team grows, we'll develop additional practices:
- Code review rotation
- PR size guidelines
- Pair programming sessions
- Architecture decision records
- Team sync meetings

This guide will evolve with the team. When you see ways to improve it, open a PR.

## Conclusion

This workflow might feel like a lot of process at first. But each practice serves a purpose:

- **Frequent commits** protect your work
- **Draft PRs** make progress visible
- **Conventional commits** make history readable
- **Superthread integration** automates status tracking
- **Consistent naming** makes everything findable
- **Self-review** catches problems early
- **Squash merges** keep master clean

Follow these practices and you'll build a habit of working that serves you well—whether you're solo or on a team of fifty.

Now go create that draft PR and start committing!

