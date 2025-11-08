# Staging Deployment Trigger

## Overview

The staging deployment trigger is a GitHub Actions workflow that runs whenever code is merged into the `master` branch. For now, the workflow creates a GitHub issue that represents a staging deployment. This validates the automation pattern without requiring any infrastructure changes.

## Current Behavior

- Trigger: `push` events targeting the `master` branch
- Workflow file: `.github/workflows/deploy-staging-placeholder.yml`
- Output: a GitHub issue with the label `deployment: staging`
- Purpose: demonstrate that merge events generate deployment records and capture the metadata required for future automation

## Issue Contents

Each deployment issue includes:

- Short and full commit SHA with a link to the commit
- Truncated commit message
- Commit author
- Timestamp for when the workflow ran
- Source pull request (or `Direct push`)
- Branch that triggered the workflow
- Outline of the steps that a real deployment would perform
- Next steps for promoting the placeholder into a real deployment
- Link back to this guide

## Label Management

The workflow guarantees that the `deployment: staging` label exists. If the label is missing it will be created automatically with:

- Color: `#FFA500`
- Description: `Staging deployment tracking`

You can also manage the label manually via the GitHub UI or the GitHub CLI:

```bash
gh label create "deployment: staging" \
  --description "Staging deployment tracking" \
  --color FFA500
```

## Verifying the Trigger

1. Merge a pull request into `master` (squash merges work as expected).
2. Open the Actions tab and confirm that **Deploy to Staging (Placeholder)** ran.
3. Visit the Issues tab and locate the newest issue labeled `deployment: staging`.
4. Confirm the metadata matches the merged commit.

Optional: perform a direct push to `master` to verify that the workflow handles pushes without a pull request.

## Future Activation

When the staging environment is ready:

1. Replace the issue creation step with deployment automation (Docker builds, registry pushes, environment updates).
2. Update the issue to include deployment status (success/failure) and any additional metadata (artifact digests, migration status, health checks).
3. Consider posting deployment summaries back to the originating pull request.
4. Add automated rollback detection and remediation steps.

Use the placeholder workflow as the foundation—only the action executed needs to change.

## Maintenance

- Close deployment issues once validation is complete.
- Keep issues open for any deployments that require investigation.
- Use the label to filter the deployment history:

```bash
gh issue list --label "deployment: staging"
```

The issue stream acts as an audit log for staging readiness until the workflow is upgraded to perform real deployments.

