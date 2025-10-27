# Plan 2: Required Labels Checker

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Superthread Card:** TBD  
**Status:** Ready to Execute

## Goal

Create a GitHub Actions workflow that enforces PR labeling requirements. Every PR must have both a type label (`type: feat`, `type: fix`, etc.) and at least one area label (`area: backend`, `area: extension`, etc.) before it can be merged.

## Why This Matters

Required labels:
- **Enable filtering** - Quickly find PRs by type or area
- **Support automation** - Labels can trigger different workflows
- **Improve organization** - PRs are categorized consistently
- **Generate changelogs** - Group changes by type/area automatically
- **Team scaling** - Makes PR review easier as team grows

This builds on the label taxonomy created in Phase 1 Plan 2.

## Label Requirements

**Every PR must have:**

1. **One type label:**
   - `type: feat` - New features
   - `type: fix` - Bug fixes
   - `type: docs` - Documentation
   - `type: style` - Code formatting
   - `type: refactor` - Code restructuring
   - `type: test` - Test changes
   - `type: chore` - Build, tools, dependencies

2. **At least one area label:**
   - `area: backend` - Rails API backend
   - `area: extension` - Browser extension
   - `area: frontend` - Frontend SPA
   - `area: cli` - CLI tool
   - `area: infrastructure` - Docker, deployment, CI/CD
   - `area: project` - Project documentation

**Multiple area labels are allowed** if the PR spans multiple parts of the codebase.

## What You'll Create

### 1. GitHub Actions Workflow
**Location:** `.github/workflows/required-labels.yml`

**Triggers:**
- `pull_request` (opened, labeled, unlabeled, synchronize)

**Actions:**
- Check if PR has exactly one type label
- Check if PR has at least one area label
- Comment on PR if labels are missing
- Set status check (pass/fail)

### 2. Documentation
**Location:** Update `project/guides/github/workflow/guide.md`

**Add:**
- Section on PR labeling requirements
- How to apply labels during PR creation
- How to apply labels after PR creation

## Implementation Steps

### Step 1: Research Existing Actions

**Time Estimate:** 15 minutes

**Options:**
- `mheap/github-action-required-labels` - Simple label requirement checker
- Custom script using `actions/github-script` - More flexible
- GitHub GraphQL API - Most control

**Recommendation:** Use `mheap/github-action-required-labels` for simplicity.

### Step 2: Create the Workflow

**Time Estimate:** 60 minutes

Create `.github/workflows/required-labels.yml`:

```yaml
name: Required Labels

on:
  pull_request:
    types: [opened, labeled, unlabeled, synchronize, reopened]

jobs:
  check-labels:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      statuses: write
    
    steps:
      - name: Check for type label
        uses: mheap/github-action-required-labels@v5
        with:
          mode: exactly
          count: 1
          labels: |
            type: feat
            type: fix
            type: docs
            type: style
            type: refactor
            type: test
            type: chore
          add_comment: true
          message: |
            ## ❌ Missing Type Label
            
            This PR requires exactly one type label:
            - `type: feat` - New features
            - `type: fix` - Bug fixes
            - `type: docs` - Documentation
            - `type: style` - Code formatting
            - `type: refactor` - Code restructuring
            - `type: test` - Test changes
            - `type: chore` - Build, tools, dependencies
      
      - name: Check for area label
        uses: mheap/github-action-required-labels@v5
        with:
          mode: minimum
          count: 1
          labels: |
            area: backend
            area: extension
            area: frontend
            area: cli
            area: infrastructure
            area: project
          add_comment: true
          message: |
            ## ❌ Missing Area Label
            
            This PR requires at least one area label:
            - `area: backend` - Rails API backend
            - `area: extension` - Browser extension
            - `area: frontend` - Frontend SPA
            - `area: cli` - CLI tool
            - `area: infrastructure` - Docker, deployment, CI/CD
            - `area: project` - Project documentation
            
            Multiple area labels are allowed if the PR affects multiple areas.
```

**Note:** This action might need adjustment. Test thoroughly and be prepared to write a custom script if needed.

### Step 3: Alternative: Custom Script

**Time Estimate:** 90 minutes

**If the action above doesn't work well, create a custom script:**

```yaml
name: Required Labels

on:
  pull_request:
    types: [opened, labeled, unlabeled, synchronize, reopened]

jobs:
  check-labels:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      statuses: write
    
    steps:
      - name: Check required labels
        uses: actions/github-script@v7
        with:
          script: |
            const labels = context.payload.pull_request.labels.map(l => l.name);
            
            // Check for type label
            const typeLabels = labels.filter(l => l.startsWith('type: '));
            const hasTypeLabel = typeLabels.length === 1;
            
            // Check for area label
            const areaLabels = labels.filter(l => l.startsWith('area: '));
            const hasAreaLabel = areaLabels.length >= 1;
            
            // Determine overall status
            const allChecksPass = hasTypeLabel && hasAreaLabel;
            
            // Create status check
            await github.rest.repos.createCommitStatus({
              owner: context.repo.owner,
              repo: context.repo.repo,
              sha: context.payload.pull_request.head.sha,
              state: allChecksPass ? 'success' : 'failure',
              context: 'required-labels',
              description: allChecksPass 
                ? 'All required labels present' 
                : 'Missing required labels'
            });
            
            // Comment if labels missing
            if (!allChecksPass) {
              let message = '## ❌ Missing Required Labels\n\n';
              
              if (!hasTypeLabel) {
                message += '**Missing type label** (need exactly 1):\n';
                message += '- `type: feat` - New features\n';
                message += '- `type: fix` - Bug fixes\n';
                message += '- `type: docs` - Documentation\n';
                message += '- `type: style` - Code formatting\n';
                message += '- `type: refactor` - Code restructuring\n';
                message += '- `type: test` - Test changes\n';
                message += '- `type: chore` - Build, tools, dependencies\n\n';
              }
              
              if (!hasAreaLabel) {
                message += '**Missing area label** (need at least 1):\n';
                message += '- `area: backend` - Rails API backend\n';
                message += '- `area: extension` - Browser extension\n';
                message += '- `area: frontend` - Frontend SPA\n';
                message += '- `area: cli` - CLI tool\n';
                message += '- `area: infrastructure` - Docker, deployment, CI/CD\n';
                message += '- `area: project` - Project documentation\n\n';
                message += 'Multiple area labels are allowed if needed.\n';
              }
              
              // Check if we already commented
              const comments = await github.rest.issues.listComments({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number
              });
              
              const existingComment = comments.data.find(c => 
                c.user.login === 'github-actions[bot]' && 
                c.body.includes('Missing Required Labels')
              );
              
              if (existingComment) {
                // Update existing comment
                await github.rest.issues.updateComment({
                  owner: context.repo.owner,
                  repo: context.repo.repo,
                  comment_id: existingComment.id,
                  body: message
                });
              } else {
                // Create new comment
                await github.rest.issues.createComment({
                  owner: context.repo.owner,
                  repo: context.repo.repo,
                  issue_number: context.issue.number,
                  body: message
                });
              }
              
              // Fail the check
              core.setFailed('Missing required labels');
            }
```

### Step 4: Update Documentation

**Time Estimate:** 30 minutes

**Update `project/guides/github/workflow/guide.md`:**

Add a section:

```markdown
## PR Labeling Requirements

All PRs must have proper labels before merging.

### Required Labels

**Type label (exactly one):**
- `type: feat` - New features
- `type: fix` - Bug fixes  
- `type: docs` - Documentation
- `type: style` - Code formatting
- `type: refactor` - Code restructuring
- `type: test` - Test changes
- `type: chore` - Build, tools, dependencies

**Area label (at least one):**
- `area: backend` - Rails API backend
- `area: extension` - Browser extension
- `area: frontend` - Frontend SPA
- `area: cli` - CLI tool
- `area: infrastructure` - Docker, deployment, CI/CD
- `area: project` - Project documentation

Multiple area labels are allowed if your PR affects multiple parts of the codebase.

### Applying Labels

**During PR creation with gh CLI:**
```bash
gh pr create \
  --title "feat(backend): add user authentication" \
  --add-label "type: feat" \
  --add-label "area: backend"
```

**After PR creation:**
```bash
gh pr edit PR_NUMBER --add-label "type: feat"
gh pr edit PR_NUMBER --add-label "area: backend"
```

**Via GitHub UI:**
1. Open your PR
2. Click the gear icon next to "Labels" in the right sidebar
3. Select the appropriate type and area labels

### Validation

A GitHub Actions workflow automatically checks that all required labels are present. The PR cannot be merged until all labels are applied.
```

**Update PR template reminder:**

Update `.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## Required Labels

Before merging, ensure these labels are applied:

- [ ] **Type label:** `type: feat`, `type: fix`, `type: docs`, etc.
- [ ] **Area label:** `area: backend`, `area: extension`, etc.
```

### Step 5: Test Thoroughly

**Time Estimate:** 45 minutes

**Test Cases:**

1. **No labels** - Should fail both checks
2. **Only type label** - Should fail area check
3. **Only area label** - Should fail type check
4. **Two type labels** - Should fail type check (exactly 1 required)
5. **One type, one area** - Should pass ✅
6. **One type, two areas** - Should pass ✅
7. **Add label after creation** - Status should update automatically
8. **Remove required label** - Status should change to failing

**Document:**
- [ ] All test results
- [ ] Screenshots of passing/failing checks
- [ ] Screenshots of helpful comments

## Deliverables

- [ ] `.github/workflows/required-labels.yml` - Working validation workflow
- [ ] Documentation in workflow guide
- [ ] Updated PR template with label checklist
- [ ] Test PRs demonstrating all scenarios

## Success Criteria

- ✅ Workflow triggers when PR is opened or labels change
- ✅ PRs without required labels fail the check
- ✅ PRs with all required labels pass the check
- ✅ Status check blocks merge when failing
- ✅ Helpful comments explain what's missing
- ✅ Comments update (not duplicate) when labels change
- ✅ Documentation is clear

## Time Estimate

**Total:** ~3.5 hours

## Next Steps

After completing this plan:
1. Test with real PRs
2. Proceed to Plan 3 (Linter)
3. Add this check to branch protection in Plan 4

## References

- [mheap/github-action-required-labels](https://github.com/mheap/github-action-required-labels)
- [GitHub Actions: Using Scripts](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions)
- [GitHub REST API: Labels](https://docs.github.com/en/rest/issues/labels)

