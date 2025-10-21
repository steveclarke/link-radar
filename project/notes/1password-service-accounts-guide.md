# 1Password Service Accounts for Production/Staging/CI

**What:** 1Password Service Accounts provide token-based authentication for the `op` CLI in production, staging, and CI/CD environments. Unlike the desktop app integration (see [1Password CLI Guide](1password-cli-guide.md)), service accounts are designed for automated, non-interactive environments.

**Why:** Secure secret management in production environments without tying credentials to individual user accounts. Service accounts use token-based authentication, support least-privilege access, and provide audit trails.

## Service Accounts vs Desktop Integration

| Feature | Service Accounts (Prod/CI) | Desktop Integration (Local Dev) |
|---------|---------------------------|----------------------------------|
| **Authentication** | Token (`OP_SERVICE_ACCOUNT_TOKEN`) | Biometric + desktop app |
| **Environment** | Production, staging, CI/CD | Developer workstations only |
| **Interactive** | No (automated) | Yes (biometric prompts) |
| **Setup** | Environment variable | Desktop app + CLI |
| **Cost** | Included with 1Password subscription | Included with 1Password subscription |
| **User tied** | No (shared/automated) | Yes (your 1Password account) |

## Common Use Cases

Based on the [1Password Service Accounts documentation](https://developer.1password.com/docs/service-accounts/), service accounts are ideal for:

### CI/CD Pipelines
Load secrets into continuous integration environments automatically. Access credentials stored in 1Password vaults during testing and deployment without tying them to personal accounts.

### Production/Staging Servers
Provision web services with secrets from 1Password. For example, if your Rails app needs a database password or API key, the service account can fetch it during startup.

### Infrastructure Secrets
Secure infrastructure secrets that shouldn't be tied to personal user accounts. Service accounts implement least-privilege principles.

### Test Environments
Create test environments with access to specific vaults while keeping secrets compartmentalized from production.

## Setup Overview

**1. Create a Service Account** (in 1Password web interface):
   - Go to your 1Password account settings
   - Create a new service account
   - Grant it access to specific vaults (e.g., "LinkRadar Production")
   - Set permissions (read-only recommended for most cases)
   - Save the service account token (shows once only)

**2. Configure Environment**:
```bash
# Set the service account token as an environment variable
export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"
```

**3. Use the `op` CLI**:
```bash
# No signin needed—the token is automatically used
op item get "master.key" --vault "LinkRadar Production" --fields credential
```

## Usage in Rails

### Fetching master.key on Server Startup

You could modify your deployment process to fetch `master.key` from 1Password:

```bash
# In your deployment script or Dockerfile
op item get "Rails master.key" \
  --vault "LinkRadar Production" \
  --fields credential > config/master.key

chmod 600 config/master.key
```

### Using in Docker

```dockerfile
# Dockerfile example
FROM ruby:3.2

# Install 1Password CLI
RUN curl -sSfL https://downloads.1password.com/linux/debian/$(dpkg --print-architecture)/stable/1password-cli-$(dpkg --print-architecture)-latest.deb \
  -o /tmp/op.deb && \
  dpkg -i /tmp/op.deb && \
  rm /tmp/op.deb

# ... rest of your Dockerfile

# Fetch secrets at runtime using service account token
# (OP_SERVICE_ACCOUNT_TOKEN should be set via environment)
```

### Using in CI/CD (GitHub Actions example)

```yaml
name: Deploy
on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install 1Password CLI
        run: |
          curl -sSfL https://downloads.1password.com/linux/debian/amd64/stable/1password-cli-amd64-latest.deb \
            -o op.deb
          sudo dpkg -i op.deb
          rm op.deb
      
      - name: Load secrets from 1Password
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          op item get "Rails master.key" --vault "LinkRadar CI" --fields credential > config/master.key
          chmod 600 config/master.key
      
      - name: Run tests
        run: bundle exec rails test
```

## Security Best Practices

1. **Least Privilege**: Grant service accounts access only to the vaults they need
2. **Read-Only When Possible**: Most production use cases only need read access
3. **Rotate Tokens**: Regularly rotate service account tokens
4. **Separate Accounts**: Use different service accounts for staging, production, and CI
5. **Audit Logs**: Review service account usage reports in 1Password
6. **Secure Token Storage**: Store `OP_SERVICE_ACCOUNT_TOKEN` in your platform's secret manager:
   - GitHub Actions: Repository Secrets
   - Heroku: Config Vars
   - Railway: Environment Variables
   - AWS: Systems Manager Parameter Store or Secrets Manager

## Cost Considerations

- Service accounts are **included with your 1Password subscription**
- You can create up to **100 service accounts** per account
- No additional costs beyond your existing 1Password subscription
- Check [1Password pricing](https://1password.com/pricing/) for subscription details

## Alternative Approaches

If 1Password Service Accounts don't fit your needs:

### Cloud Provider Secret Managers
- **AWS Secrets Manager**: Native integration with AWS services
- **Google Cloud Secret Manager**: Integrated with GCP
- **Azure Key Vault**: For Azure deployments

### Platform Environment Variables
- **Heroku**: Config vars (encrypted at rest)
- **Railway**: Environment variables
- **Fly.io**: Secrets management

### Rails Credentials + Encrypted master.key
- Store encrypted `credentials.yml.enc` in git
- Provide `master.key` via platform environment variable (`RAILS_MASTER_KEY`)
- Simplest approach for many deployments

## Implementation Decision

**When to use Service Accounts:**
- Have an existing 1Password subscription
- Need centralized secret management across multiple platforms
- Want audit trails for secret access
- Need to rotate secrets across multiple services

**When to use alternatives:**
- Platform-native solutions are preferred (AWS, GCP, Azure)
- Simple deployments where `RAILS_MASTER_KEY` environment variable suffices
- No existing 1Password subscription

## Rate Limits

Service accounts have rate limits. See the [1Password Service Accounts rate limits documentation](https://developer.1password.com/docs/service-accounts/rate-limits/) for details.

## Next Steps

1. **Evaluate**: Decide if service accounts fit your infrastructure and budget
2. **Test in Staging**: Set up a service account for staging first
3. **Document Tokens**: Document where service account tokens are stored
4. **Set Up Monitoring**: Monitor service account usage in 1Password
5. **Plan Rotation**: Create a token rotation schedule

## Documentation

- **Official:** [1Password Service Accounts](https://developer.1password.com/docs/service-accounts/)
- **Get Started:** [Service Accounts Get Started Guide](https://developer.1password.com/docs/service-accounts/get-started/)
- **CLI Usage:** [Use with 1Password CLI](https://developer.1password.com/docs/service-accounts/use-with-cli/)
- **Related:** [1Password CLI Guide](1password-cli-guide.md) (for local development)
- **Related:** [Configuration Management Guide](configuration-management-guide.md)

