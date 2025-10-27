# Pull Request Template Guide

## Overview

LinkRadar uses a GitHub PR template to maintain consistency and quality in pull requests. The template automatically loads when you create a new PR on GitHub.

**Location:** `.github/PULL_REQUEST_TEMPLATE.md`

## Why We Use It

- **Consistency** - Every PR has the same structure
- **Reminders** - Don't forget labels, testing, or Superthread links
- **Documentation** - Future you (or team members) will appreciate the context
- **Quality** - Simple checklist helps catch issues before merge

## Using the Template

### 1. Description

Write a brief, clear description of what the PR does and why:

**Good:**
```
Add user authentication to the backend API. This enables the browser 
extension to securely save links with user attribution.
```

**Bad:**
```
Updates
```

### 2. Related Work

**Always link to your Superthread card.** This is required per our project workflow.

```markdown
- **Superthread Card:** [LR002-P1: Create PR Template](https://clevertakes.superthread.com/card/128)
- **Related Issues:** #42
```

If there are no related issues, just leave it blank or remove the line.

### 3. Type of Change

Check the box that matches your commit type. This should align with your commit messages:

- `feat:` - New functionality
- `fix:` - Bug fix
- `docs:` - Documentation only
- `style:` - Formatting, whitespace (no code changes)
- `refactor:` - Code cleanup (no behavior changes)
- `test:` - Adding or updating tests
- `chore:` - Build tools, dependencies, configs

### 4. Required Labels

Before merging, add these labels to the PR:

**Type label:** Matches your commit type
- `type: feat`, `type: fix`, `type: docs`, etc.

**Area label:** What part of LinkRadar
- `area: backend`, `area: extension`, `area: infrastructure`, etc.

Labels are defined in Plan 2 of the CI/CD feature.

### 5. Testing

Run through this checklist before requesting review (even if you're reviewing your own PR):

- [ ] Tested locally - Actually run the code
- [ ] All tests pass - Run the test suite
- [ ] No linter errors - Check for warnings/errors

### 6. Additional Notes

Use this section for:

- **Screenshots** - Visual changes to UI
- **Breaking changes** - What might break for users
- **Migration notes** - Database changes, config updates needed
- **Performance impact** - Any performance considerations
- **Follow-up work** - Related tasks for future PRs

If you have nothing to add, you can delete this section.

## Tips

### Keep Descriptions Concise

Aim for 1-3 sentences. The commits and code tell the full story.

### Link Everything

Always include the Superthread card link. This maintains traceability from task to implementation.

### Don't Skip Testing

Even for small changes, run the tests. It's easy to miss things.

### Review Your Own PR

Use GitHub's review feature to review your own code. Look at the diff as if someone else wrote it. You'll catch things you missed.

### Update as You Go

If you discover issues during review, fix them and update the PR description if needed.

## Example PR

Here's what a complete PR looks like:

```markdown
## Description

Add Docker Compose configuration for local development. Includes PostgreSQL 
service and Rails API service with hot-reloading enabled.

## Related Work

- **Superthread Card:** [LR001-P3: Docker Setup](https://app.superthread.com/card-125)

## Type of Change

- [x] `chore:` Build process, tooling, dependencies

## Required Labels

- [x] **Type label:** `type: chore`
- [x] **Area label:** `area: infrastructure`

## Testing

- [x] Tested locally
- [x] All tests pass
- [x] No linter errors

## Additional Notes

This uses the official PostgreSQL 16 image and includes a volume for data 
persistence. The backend service automatically runs migrations on startup.
```

## Customizing for Future Needs

This template is designed to be simple for solo development but scales to team use:

**For Larger Teams:**
- Add reviewer assignment section
- Add deployment checklist
- Add security review section
- Add performance testing requirements

**For Specific Workflows:**
- Add database migration checklist
- Add API documentation update reminder
- Add changelog update requirement

The template is version-controlled, so evolve it as the project grows.

