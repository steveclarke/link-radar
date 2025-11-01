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

1. Loads config from `.config/{environment}.env`
2. Fetches credentials from 1Password item
3. SSHs to server and sets up deployment directory
4. Generates environment files on server
5. Pulls latest Docker images
6. Starts/restarts services
7. Verifies deployment

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
