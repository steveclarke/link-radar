# Plan 1: Conventional Commits Checker

**Feature:** LR002 - CI/CD Pipeline & Deployment Automation  
**Superthread Card:** TBD  
**Status:** Ready to Execute

## Goal

Create a GitHub Actions workflow that validates all commit messages in a PR follow the Conventional Commits specification. This workflow will comment on PRs with helpful feedback when commit messages are invalid and create a status check that blocks merging.

## Why This Matters

Conventional Commits:
- **Enable automation** - Standardized format allows automated changelog generation
- **Improve clarity** - Each commit clearly states type of change (feat, fix, docs, etc.)
- **Support semantic versioning** - Breaking changes can be detected automatically
- **Maintain history** - Clean, parseable commit history
- **Team consistency** - Everyone follows same format

Enforcing this early builds good habits and enables future automation.

## Conventional Commits Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Required:**
- `type`: feat, fix, docs, style, refactor, test, chore
- `subject`: Brief description (imperative mood, lowercase, no period)

**Optional:**
- `scope`: Which part of codebase (backend, extension, frontend, cli, infrastructure, project)
- `body`: Detailed explanation
- `footer`: References to issues/cards

**Examples:**

✅ Good:
```
feat(backend): add link archival endpoint
fix(extension): resolve popup sizing on Firefox
docs(project): update workflow guide
chore(infrastructure): update Ruby to 3.4.2
```

❌ Bad:
```
Add feature              # Missing type
feat: Add Feature        # Subject should be lowercase
feat(backend) add stuff  # Missing colon
added new stuff          # Missing type, wrong tense
```

## What You'll Create

### 1. GitHub Actions Workflow
**Location:** `.github/workflows/conventional-commits.yml`

**Triggers:**
- `pull_request` (opened, synchronize, reopened)
- `pull_request_target` (for forks with limited permissions)

**Actions:**
- Fetch all commits in the PR
- Validate each commit message
- Comment on PR with results (if invalid)
- Set status check (pass/fail)

### 2. Documentation
**Location:** Update `project/guides/github/workflow/guide.md`

**Add:**
- Conventional Commits section with examples
- Link to full specification
- Common mistakes and how to fix them

## Implementation Steps

### Step 1: Research Existing Actions

**Time Estimate:** 30 minutes

**Research:**
- [ ] Search GitHub Marketplace for "conventional commits"
- [ ] Review popular actions:
  - `amannn/action-semantic-pull-request`
  - `wagoid/commitlint-github-action`
  - `webiny/action-conventional-commits`
- [ ] Evaluate pros/cons of each
- [ ] Decide: Use existing action or write custom script?

**Recommendation:** Use `webiny/action-conventional-commits` - simple, focused, good error messages.

### Step 2: Create the Workflow

**Time Estimate:** 45 minutes

Create `.github/workflows/conventional-commits.yml`:

```yaml
name: Conventional Commits

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  conventional-commits:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      statuses: write
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Check commit messages
        uses: webiny/action-conventional-commits@v1.3.0
        with:
          allowed-commit-types: "feat,fix,docs,style,refactor,test,chore"
```

**Test:**
- Create a test PR with valid commits
- Create a test PR with invalid commits
- Verify status check appears
- Verify comments are helpful

### Step 3: Enhance with Custom Comments

**Time Estimate:** 30 minutes

**If the action doesn't provide good feedback:**

Add a step that creates helpful comments:

```yaml
      - name: Comment on PR (if validation fails)
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## ❌ Conventional Commits Check Failed
              
              One or more commit messages don't follow the Conventional Commits format.
              
              **Required format:**
              \`\`\`
              <type>(<scope>): <subject>
              \`\`\`
              
              **Valid types:** feat, fix, docs, style, refactor, test, chore
              
              **Examples:**
              - \`feat(backend): add user authentication\`
              - \`fix(extension): resolve popup issue\`
              - \`docs(project): update README\`
              
              **How to fix:**
              1. Review your commit messages
              2. Use \`git commit --amend\` to fix the most recent commit
              3. Use \`git rebase -i\` to fix older commits
              4. Force push to update the PR
              
              See our [workflow guide](../../project/guides/github/workflow/guide.md) for details.`
            })
```

### Step 4: Update Documentation

**Time Estimate:** 45 minutes

**Update `project/guides/github/workflow/guide.md`:**

Add a new section:

```markdown
## Commit Message Format

We follow [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Format

<type>(<scope>): <subject>

### Types

- **feat** - New features
- **fix** - Bug fixes
- **docs** - Documentation changes
- **style** - Code formatting (no logic changes)
- **refactor** - Code restructuring (no behavior changes)
- **test** - Test additions/modifications
- **chore** - Build tools, dependencies, configurations

### Scopes

Match your monorepo structure:
- `backend` - Rails API
- `extension` - Browser extension
- `frontend` - Frontend SPA
- `cli` - CLI tool
- `infrastructure` - Docker, deployment, CI/CD
- `project` - Project documentation

### Examples

**Good:**
- `feat(backend): add link archival endpoint`
- `fix(extension): resolve popup sizing on Firefox`
- `docs(project): update workflow guide`
- `chore(infrastructure): update Ruby to 3.4.2`

**Bad:**
- `Add feature` - Missing type
- `feat: Add Feature` - Subject should be lowercase
- `feat(backend) add stuff` - Missing colon
- `added new stuff` - Missing type, wrong tense

### Fixing Invalid Commits

**Fix most recent commit:**
```bash
git commit --amend -m "feat(backend): add new feature"
git push --force
```

**Fix older commits:**
```bash
git rebase -i HEAD~3  # Last 3 commits
# Change 'pick' to 'reword' for commits to fix
# Save and edit commit messages
git push --force
```

### Validation

All PRs are automatically checked for conventional commits format. The PR cannot be merged until all commit messages are valid.
```

### Step 5: Test Thoroughly

**Time Estimate:** 30 minutes

**Test Cases:**

1. **Valid commits** - PR should pass
   ```bash
   git checkout -b test/valid-commits
   git commit --allow-empty -m "feat(backend): test valid commit"
   git push origin test/valid-commits
   # Create PR, verify status check passes
   ```

2. **Invalid commit - missing type**
   ```bash
   git checkout -b test/invalid-no-type
   git commit --allow-empty -m "add new feature"
   git push origin test/invalid-no-type
   # Create PR, verify status check fails with helpful message
   ```

3. **Invalid commit - wrong case**
   ```bash
   git checkout -b test/invalid-case
   git commit --allow-empty -m "feat(backend): Add New Feature"
   git push origin test/invalid-case
   # Create PR, verify status check fails
   ```

4. **Fix and retest**
   ```bash
   git commit --amend -m "feat(backend): add new feature"
   git push --force
   # Verify status check now passes
   ```

**Document:**
- [ ] All test results
- [ ] Screenshots of passing/failing checks
- [ ] Screenshots of helpful comments

## Deliverables

- [ ] `.github/workflows/conventional-commits.yml` - Working validation workflow
- [ ] Documentation in workflow guide with examples
- [ ] Test PRs demonstrating passing and failing cases
- [ ] Screenshots showing the workflow in action

## Success Criteria

- ✅ Workflow triggers on every PR
- ✅ Valid commits pass the check
- ✅ Invalid commits fail the check with clear error messages
- ✅ Status check appears in PR and blocks merge when failing
- ✅ Developers can understand how to fix invalid commits
- ✅ Documentation is clear and includes examples

## Time Estimate

**Total:** ~3 hours

## Next Steps

After completing this plan:
1. Test with real PRs
2. Proceed to Plan 2 (Required Labels Checker)
3. Add this check to branch protection in Plan 4

## References

- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [webiny/action-conventional-commits](https://github.com/webiny/action-conventional-commits)
- [GitHub Actions: Creating Status Checks](https://docs.github.com/en/rest/commits/statuses)

