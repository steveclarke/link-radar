# Automated Deployment

Deploy Link Radar to any environment in one command using `bin/deploy`.

## Quick Start

```bash
cd deploy
bin/deploy prod
```

Credentials auto-sourced from 1Password. That's it!

## First Time Setup

```bash
cd deploy
cp .config/environment.env.template .config/prod.env
# Edit if your server/1Password item differs from defaults
```

## Requirements

- 1Password CLI installed and authenticated
- Backend image built and pushed (`cd backend && bin/docker-build && bin/docker-push`)
- SSH access to target server
- `.config/{environment}.env` file exists

## Usage

```bash
bin/deploy prod         # Deploy to production
bin/deploy staging      # Deploy to staging
bin/deploy test         # Deploy to test
bin/deploy --help       # Show all options
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

**"Config not found"**: Create `.config/{env}.env` from template

**"1Password CLI not found"**: Install from https://developer.1password.com/docs/cli/get-started/ or use manual env vars

**"SSH connection failed"**: Verify SSH access with `ssh deploy@your-server`

**"First deploy - save password"**: Script generates DB_PASSWORD on first deploy - add it to your 1Password item

For detailed troubleshooting, see [README.md](./README.md).
