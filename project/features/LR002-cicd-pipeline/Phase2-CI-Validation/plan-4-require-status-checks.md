# Plan 4: Require Status Checks in Branch Protection

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Superthread Card:** TBD  
**Status:** Ready to Execute (after Plans 1-3)

## Goal

Update the "Master Branch Protection" ruleset to require the three CI validation workflows (conventional-commits, required-labels, lint) to pass before PRs can be merged. This enforces automated quality gates and prevents merging code that doesn't meet standards.

## Why This Matters

Required status checks:
- **Block bad code** - Can't merge until all validations pass
- **Automate quality gates** - No manual verification needed
- **Maintain standards** - Enforces commit format, labels, file syntax
- **Prevent mistakes** - Catches issues before they reach master
- **Support workflow** - Makes the process automatic, not manual

This is the final piece that ties together all Phase 2 validation workflows.

## Prerequisites

Before this plan, you must complete:
- ✅ Phase 1 Plan 4: Branch Protection configured
- ✅ Phase 2 Plan 1: Conventional Commits workflow created
- ✅ Phase 2 Plan 2: Required Labels workflow created
- ✅ Phase 2 Plan 3: Lint workflow created

All three workflows must be tested and working correctly.

## Status Checks to Require

### 1. conventional-commits
**Workflow:** `.github/workflows/conventional-commits.yml`  
**Validates:** All commit messages follow `type(scope): subject` format  
**Failure means:** Invalid commit messages that need fixing

### 2. required-labels
**Workflow:** `.github/workflows/required-labels.yml`  
**Validates:** PR has type label + area label  
**Failure means:** Missing labels that need to be applied

### 3. Lint YAML
**Workflow:** `.github/workflows/lint.yml` (yaml-lint job)  
**Validates:** All YAML files have valid syntax  
**Failure means:** Syntax errors in YAML files

### 3. Lint Markdown
**Workflow:** `.github/workflows/lint.yml` (markdown-lint job)  
**Validates:** All Markdown files follow formatting rules  
**Failure means:** Formatting issues in Markdown files

**Note:** The lint workflow has 2 jobs, so we need to require both job names as status checks.

## What You'll Do

### Manual Update (via GitHub UI)
**Location:** GitHub repository settings

### Scripted Update (via API)
**Location:** Update `project/guides/github/branch-protection/setup.sh`

### JSON Update
**Location:** Update `project/guides/github/branch-protection/ruleset.json`

## Implementation Steps

### Step 1: Identify Exact Status Check Names

**Time Estimate:** 15 minutes

**Run all workflows and verify status check names:**

1. Create a test PR
2. Wait for all workflows to run
3. Check PR status checks section
4. Note the exact names that appear

**Expected names:**
- `conventional-commits`
- `required-labels`
- `Lint YAML` (job name from lint workflow)
- `Lint Markdown` (job name from lint workflow)

**Important:** Status check names must match EXACTLY (case-sensitive).

### Step 2: Update Ruleset Manually (Learning)

**Time Estimate:** 15 minutes

1. **Navigate to Settings → Branches**
2. **Click the "..." menu** next to "Master Branch Protection" ruleset
3. **Click "Edit"**
4. **Scroll to "Require status checks to pass"**
5. **Check the box** to enable it
6. **Check "Require branches to be up to date before merging"**
7. **Add status checks:**
   - Type or search for each check name
   - Add: `conventional-commits`
   - Add: `required-labels`
   - Add: `Lint YAML`
   - Add: `Lint Markdown`
8. **Save the ruleset**

**Take screenshots** of the process and the final configuration.

### Step 3: Test the Requirements

**Time Estimate:** 30 minutes

**Test 1: All checks passing**
- Create PR with valid commits, labels, and files
- Verify merge button is enabled ✅

**Test 2: Failing conventional commits**
- Create PR with invalid commit message
- Verify merge button is blocked ❌
- Verify helpful error message appears

**Test 3: Missing labels**
- Create PR without labels
- Verify merge button is blocked ❌
- Add labels
- Verify merge button enables ✅

**Test 4: Linting errors**
- Create PR with invalid YAML
- Verify merge button is blocked ❌
- Fix the YAML
- Verify check passes and merge enables ✅

**Document all results.**

### Step 4: Update the JSON Export

**Time Estimate:** 15 minutes

1. **Export the updated ruleset**
   - Settings → Branches
   - Click "..." menu → Export
   - Save as JSON

2. **Clean up and replace `ruleset.json`:**
   - Remove `id`, `source`, `source_type` fields
   - Keep everything else
   - Save to `project/guides/github/branch-protection/ruleset.json`

The JSON should now include:

```json
{
  "type": "required_status_checks",
  "parameters": {
    "strict_required_status_checks_policy": true,
    "required_status_checks": [
      {"context": "conventional-commits"},
      {"context": "required-labels"},
      {"context": "Lint YAML"},
      {"context": "Lint Markdown"}
    ]
  }
}
```

### Step 5: Update the Setup Script

**Time Estimate:** 20 minutes

Update `project/guides/github/branch-protection/setup.sh`:

**Add the status checks rule to the rules array:**

```bash
  -f rules='[
    {
      "type": "deletion"
    },
    {
      "type": "required_linear_history"
    },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": true,
        "required_review_thread_resolution": false
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {"context": "conventional-commits"},
          {"context": "required-labels"},
          {"context": "Lint YAML"},
          {"context": "Lint Markdown"}
        ]
      }
    },
    {
      "type": "non_fast_forward"
    }
  ]'
```

**Update the echo messages** to reflect status checks are now configured.

### Step 6: Update Documentation

**Time Estimate:** 30 minutes

**Update `project/guides/github/branch-protection/guide.md`:**

Update the settings summary table:

```markdown
| Rule | Enabled | Why |
|------|---------|-----|
| Require PR | ✅ | Enforces review workflow |
| Required approvals | ✅ (1) | Quality gate |
| Last push approval | ✅ | Re-review after changes |
| **Required status checks** | ✅ | CI validation must pass |
| Linear history | ✅ | Clean Git history |
| Bypass: Admins (PR only) | ✅ | Emergency escape hatch |
| Block force pushes | ✅ | Prevent history rewrites |
| Restrict deletions | ✅ | Prevent accidental deletion |
```

Add a section:

```markdown
## Status Checks Configuration

After Phase 2 workflows are created, add them as required checks:

### Required Checks

- **conventional-commits** - Validates commit message format
- **required-labels** - Verifies PR has type + area labels
- **Lint YAML** - Validates YAML file syntax
- **Lint Markdown** - Validates Markdown file formatting

### How It Works

When a PR is opened:
1. All three workflows run automatically
2. Each creates a status check
3. PR cannot be merged until all checks pass
4. Developers see clear errors if checks fail

### Updating Status Checks

To add/remove required checks:
1. Edit the ruleset in GitHub UI
2. Or update `ruleset.json` and re-import
3. Or run updated `setup.sh` script
```

## Deliverables

- [ ] Branch ruleset updated to require status checks
- [ ] Updated `ruleset.json` with status checks
- [ ] Updated `setup.sh` with status checks
- [ ] Updated documentation
- [ ] All test cases pass
- [ ] Screenshots of configuration

## Success Criteria

- ✅ PRs cannot be merged with invalid commits
- ✅ PRs cannot be merged without required labels
- ✅ PRs cannot be merged with linting errors
- ✅ PRs with all checks passing can be merged
- ✅ Error messages are clear and actionable
- ✅ Status checks appear correctly in PR UI
- ✅ Documentation explains the system

## Time Estimate

**Total:** ~2.5 hours

## Next Steps

After completing this plan:
1. Phase 2 is complete!
2. All validation workflows are enforced
3. Ready for Phase 3 (Deployment Trigger Placeholders)

## Notes

- Status check names are case-sensitive - verify exact names
- "Require branches to be up to date" ensures PRs are tested with latest master
- Admin bypass still available for emergencies
- Can temporarily disable status checks by editing ruleset
- Workflows must be on master branch for status checks to work

## References

- [GitHub Status Checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/about-status-checks)
- [Required Status Checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging)

