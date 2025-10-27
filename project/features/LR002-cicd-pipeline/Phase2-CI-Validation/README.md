# Phase 2: CI Validation Workflows

**Status:** Ready to Execute  
**Prerequisites:** Phase 1 Foundation complete ✅

## Overview

Phase 2 implements automated validation workflows that run on every pull request. These workflows enforce code quality standards and prevent invalid code from being merged to master.

## Goals

Create three GitHub Actions workflows that:
1. Validate commit message format (Conventional Commits)
2. Enforce PR labeling requirements (type + area labels)
3. Lint YAML and Markdown files for syntax errors

Then configure branch protection to **require all three checks to pass** before allowing merges.

## Why This Phase Matters

**Automation over manual review:**
- Developers get instant feedback
- Standards are enforced consistently
- No need to remember to check manually
- Reduces review burden

**Quality gates:**
- Invalid commits can't reach master
- Unlabeled PRs can't be merged
- Syntax errors are caught early

**Foundation for future work:**
- Enables automated changelog generation
- Supports semantic versioning
- Prepares for deployment automation

## Phase 2 Plans

### Plan 1: Conventional Commits Checker
**Time:** ~3 hours  
**Deliverable:** `.github/workflows/conventional-commits.yml`

Validates that all commit messages follow the format:
```
type(scope): subject
```

**Status check name:** `conventional-commits`

### Plan 2: Required Labels Checker
**Time:** ~3.5 hours  
**Deliverable:** `.github/workflows/required-labels.yml`

Ensures every PR has:
- Exactly one type label (`type: feat`, etc.)
- At least one area label (`area: backend`, etc.)

**Status check name:** `required-labels`

### Plan 3: Lint Checker
**Time:** ~4.5 hours  
**Deliverables:** 
- `.github/workflows/lint.yml`
- `.yamllint.yml`
- `.markdownlint.json`
- `scripts/lint-*.sh`

Validates syntax and formatting for:
- YAML files (workflows, configs)
- Markdown files (documentation)

**Status check names:** `Lint YAML`, `Lint Markdown`

### Plan 4: Require Status Checks
**Time:** ~2.5 hours  
**Deliverable:** Updated branch protection ruleset

Configures branch protection to require all validation checks to pass:
- conventional-commits ✅
- required-labels ✅
- Lint YAML ✅
- Lint Markdown ✅

## Execution Order

**Must be done in sequence:**

1. ✅ **Plan 1** → Conventional Commits workflow
2. ✅ **Plan 2** → Required Labels workflow
3. ✅ **Plan 3** → Lint workflow
4. ✅ **Plan 4** → Add all three as required checks

**Why sequential?**
- Plan 4 requires the status check names from Plans 1-3
- You need to verify each workflow works before making it required
- Testing is easier when you add one check at a time

## Testing Strategy

### Per-Plan Testing

Each plan includes its own test cases:
- Plan 1: Test with valid/invalid commit messages
- Plan 2: Test with missing/present labels
- Plan 3: Test with valid/invalid YAML and Markdown

### Integration Testing

After Plan 4, test the full system:

1. **Create PR with all issues:**
   - Invalid commit message
   - No labels
   - Broken YAML file
   - **Expected:** All 3-4 checks fail, merge blocked

2. **Fix commit messages:**
   - Amend commits to valid format
   - **Expected:** conventional-commits passes, others still fail

3. **Add labels:**
   - Apply type and area labels
   - **Expected:** required-labels passes, lint still fails

4. **Fix YAML:**
   - Correct the syntax error
   - **Expected:** All checks pass, merge enabled ✅

## Success Criteria

After Phase 2 completion:

- ✅ All PRs automatically validated for commit format
- ✅ All PRs automatically validated for required labels
- ✅ All PRs automatically validated for file syntax
- ✅ PRs cannot be merged until all checks pass
- ✅ Developers receive clear feedback on what to fix
- ✅ Branch protection enforces all status checks
- ✅ Documentation explains the system
- ✅ Local linting scripts available for pre-push validation

## Time Estimate

**Total for Phase 2:** ~13.5 hours (roughly 2 days)

- Plan 1: ~3 hours
- Plan 2: ~3.5 hours
- Plan 3: ~4.5 hours
- Plan 4: ~2.5 hours

## What Gets Enforced

After Phase 2, every PR must:

| Requirement | Check | Enforced By |
|-------------|-------|-------------|
| Valid commit format | ✅ | conventional-commits workflow |
| Type label | ✅ | required-labels workflow |
| Area label | ✅ | required-labels workflow |
| Valid YAML syntax | ✅ | lint workflow (YAML job) |
| Valid Markdown format | ✅ | lint workflow (Markdown job) |
| PR approval | ✅ | Branch protection (Phase 1) |
| Linear history | ✅ | Branch protection (Phase 1) |

## After Phase 2

**You'll have:**
- Fully automated PR validation
- Quality gates that prevent bad merges
- Clear feedback for developers
- Foundation for more advanced automation

**Next:** Phase 3 - Deployment Trigger Placeholders
- Staging deployment trigger (merge to master)
- Production deployment trigger (tag push)

## References

- [GitHub Status Checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/about-status-checks)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Actions: Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

