# Automated Deployment

Deploy Link Radar to any environment in one command using `bin/deploy`.

## Quick Start

**First time on this computer?** Initialize the environment:

```bash
cd deploy
bin/deploy prod --init --deployed
```

Then deploy:

```bash
bin/deploy prod
```

Credentials auto-sourced from 1Password. That's it!

## First Time Setup

### Interactive Setup (Recommended)

```bash
cd deploy
bin/deploy prod --init --deployed    # For existing deployments
# OR
bin/deploy prod --init               # For fresh installations
```

The script will prompt you for:
- Server hostname or IP
- 1Password item ID

### Non-Interactive Setup

```bash
cd deploy
bin/deploy prod --init \
  --host=your.server.com \
  --op=your-1password-item-id \
  --deployed
```

### Manual Setup (Alternative)

```bash
cd deploy
cp .config/environment.env.template .config/prod.env
# Edit: set DEPLOY_HOST, ONEPASSWORD_ITEM_ID, and DEPLOYED
```

## Requirements

- 1Password CLI installed and authenticated (optional but recommended)
- Backend image built and pushed (`cd backend && bin/docker-build && bin/docker-push`)
- SSH access to target server configured (passwordless SSH keys)
- Rails master key available at `backend/config/master.key`

## Usage

```bash
# Initialize environment (first time on a new computer)
bin/deploy prod --init --deployed

# Deploy to environment
bin/deploy prod         # Deploy to production
bin/deploy staging      # Deploy to staging
bin/deploy test         # Deploy to test

# Check configuration without deploying
bin/deploy prod --check

# Show all options
bin/deploy --help
```

## How It Works

**First Deploy** (DEPLOYED=false in config):
1. Loads config from `.config/{environment}.env`
2. Fetches credentials from 1Password
3. Sets up deployment directory on server
4. Generates environment files
5. Pulls Docker images
6. Starts services
7. Verifies deployment
8. Marks as deployed (sets DEPLOYED=true)

**Subsequent Deploys** (DEPLOYED=true):
1. Loads config
2. Pulls latest code on server (git pull)
3. Pulls latest Docker images
4. Restarts services
5. Verifies deployment
6. Preserves all configuration (no env file regeneration)

**Force Reinstall**: Set `DEPLOYED=false` in `.config/{env}.env`

## Creating New Environments

### Using Init Command (Recommended)

```bash
# Interactive
bin/deploy myenv --init

# Non-interactive
bin/deploy myenv --init \
  --host=myenv.server.com \
  --op=1password-item-id \
  --user=ubuntu \
  --port=8080
```

### Manual Method

```bash
cp .config/environment.env.template .config/myenv.env
# Edit: set DEPLOY_HOST and ONEPASSWORD_ITEM_ID
bin/deploy myenv
```

## Manual Credentials (Without 1Password)

```bash
DEPLOY_HOST=server.example.com \
  RAILS_MASTER_KEY=$(cat ../backend/config/master.key) \
  DB_PASSWORD=your_password \
  bin/deploy prod
```

## Updating Production

```bash
# 1. Build and push new image
cd backend && bin/docker-build && bin/docker-push

# 2. Deploy
cd ../deploy && bin/deploy prod
```

## Troubleshooting

**"Config not found"**: Run `bin/deploy {env} --init` to create configuration

**"1Password CLI not found"**: Install from https://developer.1password.com/docs/cli/get-started/ or provide credentials via environment variables

**"SSH connection failed"**: Verify SSH access with `ssh deploy@your-server` (or your configured user)

**"RAILS_MASTER_KEY not set"**: Ensure `backend/config/master.key` exists locally

**"First deploy - save password"**: Script generates DB_PASSWORD on first deploy - add it to your 1Password item for future use

**Setting up from new computer for existing deployment**: Use `bin/deploy {env} --init --deployed` to create config without triggering a full reinstall

For detailed troubleshooting, see [README.md](./README.md).
