# Link Radar Production Deployment Checklist

**Server:** Vultr Ubuntu 24.04  
**Date:** ___________  
**Deployed By:** ___________

## Pre-Deployment Checklist

- [ ] Production server ready (Vultr Ubuntu 24.04)
- [ ] Docker and Docker Compose installed
- [ ] `deploy` user created with sudo access
- [ ] SSH access configured
- [ ] Firewall configured (ports 80, 443, 22)
- [ ] Backend image built and pushed to GHCR (`ghcr.io/steveclarke/lr-backend:latest`)
- [ ] `RAILS_MASTER_KEY` copied from `backend/config/master.key`
- [ ] GitHub Personal Access Token ready (with `read:packages` permission)

## Step 1: Sparse Checkout on Production Server

SSH into your production server as the `deploy` user:

```bash
ssh deploy@YOUR_SERVER_IP
```

Create directory structure and clone only the deploy directory:

```bash
mkdir -p ~/docker
cd ~/docker
git clone --filter=blob:none --sparse https://github.com/steveclarke/link-radar.git
cd link-radar
git sparse-checkout set deploy
```

Verify you only have the deploy directory:

```bash
ls -la
# Should show: .git/ and deploy/ only
```

- [ ] Sparse checkout complete
- [ ] Only deploy directory present (no source code)

## Step 2: Navigate and Setup

```bash
cd deploy
bin/setup
```

This creates your environment files from templates:
- `.env` (Docker Compose variables)
- `env/backend.env` (Backend runtime config)
- `env/postgres.env` (Database config)

- [ ] Setup script ran successfully
- [ ] Environment files created

## Step 3: Authenticate with GitHub Container Registry

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u steveclarke --password-stdin
```

Expected output: `Login Succeeded`

- [ ] GHCR authentication successful

## Step 4: Configure Environment Variables

### 4.1 Edit `.env`

```bash
vim .env  # or nano .env
```

Update:
```bash
BACKEND_IMAGE=ghcr.io/steveclarke/lr-backend:latest
BACKEND_PORT=3000
```

- [ ] `.env` configured

### 4.2 Edit `env/backend.env`

```bash
vim env/backend.env
```

Update these critical values:
```bash
RAILS_ENV=production
RAILS_LOG_LEVEL=info
RAILS_SERVE_STATIC_FILES=true

# CRITICAL: Copy from backend/config/master.key
RAILS_MASTER_KEY=your_actual_rails_master_key_here

# Database connection (password must match postgres.env)
DATABASE_URL=postgresql://linkradar:YOUR_SECURE_DB_PASSWORD@postgres:5432/linkradar_production

# Redis connection
REDIS_URL=redis://redis:6379/0

RAILS_MAX_THREADS=5
```

**Note:** The database password in `DATABASE_URL` must match the password you'll set in `env/postgres.env`.

- [ ] `RAILS_MASTER_KEY` added
- [ ] `DATABASE_URL` password set
- [ ] All other settings reviewed

### 4.3 Edit `env/postgres.env`

```bash
vim env/postgres.env
```

Update:
```bash
POSTGRES_USER=linkradar
POSTGRES_PASSWORD=YOUR_SECURE_DB_PASSWORD  # Same as in backend.env
POSTGRES_DB=linkradar_production
```

**Security:** Use a strong, unique password. Consider generating one:
```bash
openssl rand -base64 32
```

- [ ] Database password set (matches backend.env)
- [ ] All postgres settings configured

## Step 5: Pull Docker Images

Pull the backend image from GHCR:

```bash
docker compose pull
```

This will pull:
- `ghcr.io/steveclarke/lr-backend:latest`
- `postgres:18`
- `redis:7-alpine`

- [ ] All images pulled successfully

## Step 6: Start Services

```bash
bin/up
```

This starts all services in detached mode. The backend container will automatically:
1. Run database migrations (via `bin/docker-entrypoint`)
2. Prepare the database
3. Start the Rails server

- [ ] Services started

## Step 7: Verify Deployment

### 7.1 Check Container Status

```bash
docker compose ps
```

All services should show as "running" and "healthy":
- `linkradar-backend` - healthy
- `linkradar-postgres` - healthy  
- `linkradar-redis` - healthy

- [ ] All containers running
- [ ] All health checks passing

### 7.2 View Logs

```bash
bin/logs backend
```

Look for:
- ✅ Database migrations completed
- ✅ Rails server started on port 3000
- ✅ No error messages

Press `Ctrl+C` to exit logs.

- [ ] Backend logs look good
- [ ] No errors in logs

### 7.3 Test Rails Console

```bash
bin/console
```

In the console:
```ruby
Rails.env
# Should output: "production"

ActiveRecord::Base.connection.active?
# Should output: true

exit
```

- [ ] Rails console accessible
- [ ] Database connection working

### 7.4 Test Health Endpoint

```bash
curl http://localhost:3000/up
```

Expected response: `200 OK` or similar success response.

- [ ] Health endpoint responding

### 7.5 Check Database

```bash
bin/runner bin/rails db:migrate:status
```

Should show all migrations as "up".

- [ ] All migrations applied

## Step 8: Verify Data Persistence

Check that volumes were created:

```bash
docker volume ls | grep linkradar
```

Should show:
- `linkradar_postgres_data`
- `linkradar_redis_data`

- [ ] Persistent volumes created

## Step 9: Test Restart Resilience

Test that services restart correctly:

```bash
bin/down
bin/up
bin/logs
```

Verify:
- Services come back up
- Database data persists
- No errors

- [ ] Services restart successfully
- [ ] Data persists after restart

## Post-Deployment Tasks

### Update Documentation

Document any deviations from this checklist or README:
- Configuration changes made
- Issues encountered and solutions
- Server-specific notes

- [ ] Documentation updated

### Setup Monitoring (Optional)

For production monitoring, consider:
- Server monitoring (CPU, memory, disk)
- Container health checks
- Log aggregation
- Uptime monitoring

- [ ] Monitoring configured (if applicable)

### Backup Strategy

Setup automated database backups:

```bash
# Add to crontab
0 2 * * * cd ~/docker/link-radar/deploy && docker compose exec -T postgres pg_dump -U linkradar linkradar_production | gzip > ~/backups/linkradar-$(date +\%Y\%m\%d).sql.gz
```

- [ ] Backup strategy implemented

## Troubleshooting

If you encounter issues, check:

1. **Backend won't start**: Check `bin/logs backend` for errors, verify `RAILS_MASTER_KEY` is correct
2. **Database connection errors**: Verify passwords match in `env/backend.env` and `env/postgres.env`
3. **Cannot pull image**: Check GHCR authentication, verify image exists
4. **Health checks failing**: Give services time to start (30-60 seconds), check logs

See `README.md` for detailed troubleshooting steps.

## Deployment Complete! 🎉

Your Link Radar backend is now deployed and running in production.

**Quick reference:**
- View logs: `bin/logs [service]`
- Rails console: `bin/console`
- Run migrations: `bin/runner bin/rails db:migrate`
- Restart services: `bin/down && bin/up`
- Check status: `docker compose ps`

## Next Steps

- [ ] Configure domain and SSL (Traefik or nginx)
- [ ] Setup automated deployments
- [ ] Configure monitoring and alerts
- [ ] Document operational procedures
- [ ] Plan scaling strategy

## Notes

Use this space to document anything specific to your deployment:

```
<!-- Add your notes here -->




```

