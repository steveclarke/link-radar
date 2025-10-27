# Plan 1: PR Template

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Superthread Card:** [LR002-P1: Create PR Template](https://clevertakes.superthread.com/card/128)  
**Status:** Ready to Execute

## Goal

Create a standardized pull request template that GitHub automatically loads when creating new PRs. This template ensures consistency, reminds developers about required practices, and links PRs back to project management.

## Why This Matters

PR templates serve as:
- **Checklist reminders** - Labels, testing, commit conventions
- **Information standardization** - Every PR includes the same sections
- **Quality gates** - Helps ensure nothing is forgotten before review
- **Documentation** - Links to Superthread cards and related work

For LinkRadar, this prepares you to test the complete CI/CD workflow while developing backend/extension features.

## What You'll Create

### 1. PR Template File
**Location:** `.github/PULL_REQUEST_TEMPLATE.md`

### 2. Guide Documentation
**Location:** `project/guides/github/pr-template/guide.md`

## Implementation Steps

### Step 1: Research and Understand

**Time Estimate:** 15 minutes

**Research Checklist:**
- [ ] Read GitHub PR template documentation
- [ ] Review PR templates from popular open-source projects
- [ ] Review Conventional Commits specification
- [ ] Identify essential vs nice-to-have template sections
- [ ] Consider solo development needs
- [ ] Think about future team scaling requirements

### Step 2: Create the PR Template

**Time Estimate:** 30 minutes

**Template Creation Checklist:**
- [ ] Create `.github/` directory if not exists
- [ ] Create `PULL_REQUEST_TEMPLATE.md` file
- [ ] Add Description section
- [ ] Add Related Work section (Superthread card, issues)
- [ ] Add Type of Change checklist
- [ ] Add Required Labels checklist
- [ ] Add Testing Checklist section
- [ ] Add Review Checklist section
- [ ] Add Additional Notes section
- [ ] Review and refine template content

Create `.github/PULL_REQUEST_TEMPLATE.md` with these sections:

```markdown
## Description
Brief description of what this PR does

## Related Work
- Superthread Card: [Link]
- Related Issues: #

## Type of Change
- [ ] feat: New feature
- [ ] fix: Bug fix
- [ ] docs: Documentation update
- [ ] style: Code style/formatting
- [ ] refactor: Code restructuring
- [ ] test: Test additions/changes
- [ ] chore: Build, tools, dependencies

## Required Labels (Before Merge)
- [ ] Type label added (type: feat/fix/docs/etc)
- [ ] Area label added (area: backend/extension/etc)

## Testing Checklist
- [ ] Tested locally
- [ ] All tests pass
- [ ] No linter errors

## Review Checklist
- [ ] Follows Conventional Commits format
- [ ] Code is documented where needed
- [ ] Ready for review

## Additional Notes
Any additional context, screenshots, or notes for reviewers
```

**Adjust based on:**
- Solo development needs (simpler is fine)
- Future team scaling (keep it flexible)
- LinkRadar workflow (reference Superthread cards)

### Step 3: Test the Template

**Time Estimate:** 15 minutes

**Testing Checklist:**
- [ ] Create a test branch
- [ ] Make a small change
- [ ] Push branch to GitHub
- [ ] Open a PR on GitHub
- [ ] Verify template loads automatically
- [ ] Fill out the template sections
- [ ] Note what works well
- [ ] Note what doesn't work or feels unclear

**Test Evaluation:**
- [ ] Template loads in new PR automatically
- [ ] All sections make sense
- [ ] Checkboxes are easy to complete
- [ ] Links to cards/issues work correctly
- [ ] Nothing feels redundant or unclear
- [ ] Close or merge test PR

### Step 4: Refine Based on Testing

**Time Estimate:** 15 minutes

**Refinement Checklist:**
- [ ] Remove unnecessary sections
- [ ] Clarify confusing parts
- [ ] Add missing useful prompts
- [ ] Ensure template is concise but complete
- [ ] Verify all checkboxes are actionable
- [ ] Update template file with improvements

### Step 5: Document in Guide

**Time Estimate:** 45 minutes

**Guide Creation Checklist:**
- [ ] Create directory `project/guides/github/pr-template/`
- [ ] Create file `guide.md` in the directory
- [ ] Write Overview section
- [ ] Document Our PR Template section
- [ ] Write Using the Template section
- [ ] Write Customizing for Future Projects section
- [ ] Add Examples section with good PR examples
- [ ] Add Tips section
- [ ] Proofread and refine guide

Create `project/guides/github/pr-template/guide.md` documenting:

**Guide Structure:**
```markdown
# Pull Request Template Guide

## Overview
What PR templates are and why we use them

## Our PR Template
Location and what each section does

## Using the Template
1. Template loads automatically
2. Fill in relevant sections
3. Check all required boxes
4. Link to Superthread card

## Customizing for Future Projects
How to adapt this template for:
- Larger teams
- Different workflows
- Additional requirements

## Examples
Good PR examples showing template usage

## Tips
- Keep descriptions concise
- Always link to Superthread cards
- Don't skip the testing checklist
```

## Deliverables

- [x] `.github/PULL_REQUEST_TEMPLATE.md` - Working PR template
- [ ] Test PR created and closed
- [x] `project/guides/github/pr-template/guide.md` - Complete documentation
- [ ] Superthread card #128 moved to "Done"

## Success Criteria

- ✅ New PRs automatically load the template
- ✅ Template includes all essential sections
- ✅ Template works well for solo development
- ✅ Template can scale to team use later
- ✅ Guide documents how to use and customize
- ✅ Tested with actual PR

## Time Estimate

**Total:** ~2 hours

## Next Steps

After completing this plan:
1. Move Superthread card #128 to "Done"
2. Proceed to Plan 2 (GitHub Labels)
3. Use the PR template for all future PRs in LinkRadar

## Notes

- Keep it simple for solo dev, but structured enough for future teams
- The template is in version control, easy to evolve
- This is your chance to establish good habits early

