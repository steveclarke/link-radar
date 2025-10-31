# Reverse Proxy & SSL Options for Link Radar

**Status:** Currently deployed with direct port exposure (`:3000`). This guide covers three modern options for adding SSL and domain routing.

## Current Architecture

```
Internet → :3000 → Link Radar Backend
```

**Works for:** Testing, development, internal use  
**Missing:** SSL/HTTPS, domain routing, multiple apps support

---

## Option 1: Cloudflare Tunnel 🌟 (Recommended for 2025)

**Best for:** Simplicity, zero SSL management, multiple apps, enhanced security

### What It Is

Cloudflare Tunnel creates an encrypted connection FROM your server TO Cloudflare's network. No open ports (not even 80/443), no SSL certificates to manage, no reverse proxy needed.

```
Your Apps → cloudflared container → Cloudflare Network → Internet (HTTPS)
```

### Pros

- ✅ **Zero SSL management** - Cloudflare handles everything automatically
- ✅ **No open ports** - Only SSH needs to be open (enhanced security)
- ✅ **Free tier** - Generous limits for personal/small projects
- ✅ **DDoS protection** included
- ✅ **Global CDN** included
- ✅ **Multiple apps** - Easy subdomain routing
- ✅ **No local reverse proxy** - One less thing to maintain
- ✅ **Works with any VPS** - Vultr, DigitalOcean, etc.
- ✅ **Instant setup** - ~30 minutes total

### Cons

- ⚠️ Requires Cloudflare account (free)
- ⚠️ Domain must use Cloudflare DNS
- ⚠️ Another service dependency (though very reliable)
- ⚠️ Traffic routes through Cloudflare (some consider this a privacy issue)

### Setup Steps

#### 1. Add Domain to Cloudflare

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com)
2. Add your domain
3. Update nameservers at your registrar (one-time)
4. Wait for DNS propagation (~5-60 minutes)

#### 2. Create Tunnel

In Cloudflare Dashboard:
1. Navigate to **Zero Trust** → **Access** → **Tunnels**
2. Click **Create a tunnel**
3. Name it (e.g., "vultr-main")
4. Copy the tunnel token

#### 3. Deploy cloudflared on Server

**Option A: Docker Compose (Recommended)**

Create `/home/deploy/docker/cloudflared/compose.yml`:

```yaml
name: cloudflared

services:
  tunnel:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${TUNNEL_TOKEN}
    environment:
      - TUNNEL_TOKEN=${TUNNEL_TOKEN}
    # No ports needed - it creates outbound tunnel
```

Deploy:
```bash
cd ~/docker/cloudflared
echo "TUNNEL_TOKEN=your_token_here" > .env
docker compose up -d
```

**Option B: Docker Run**

```bash
docker run -d \
  --name cloudflared \
  --restart unless-stopped \
  cloudflare/cloudflared:latest \
  tunnel --no-autoupdate run --token YOUR_TOKEN
```

#### 4. Configure Routes in Cloudflare Dashboard

In the Tunnel settings, add public hostnames:

| Public Hostname | Service | Notes |
|----------------|---------|-------|
| `api.linkradar.com` | `http://linkradar-backend:3000` | Link Radar API |
| `otherapp.com` | `http://other-container:8080` | Future apps |

**Important:** Use container names, not `localhost`. Cloudflared joins the Docker network.

#### 5. Update Link Radar (Optional)

No changes needed to `compose.yml`! But you can remove the ports section for extra security:

```yaml
services:
  backend:
    # Remove this if you want:
    # ports:
    #   - "${BACKEND_PORT:-3000}:3000"
    
    # Everything else stays the same
```

#### 6. Test

```bash
curl https://api.linkradar.com/up
```

SSL just works! No certificates to manage, ever.

### Ongoing Maintenance

**Updates:**
```bash
cd ~/docker/cloudflared
docker compose pull
docker compose up -d
```

**Logs:**
```bash
docker logs -f cloudflared
```

**Add new app:**
- Deploy new app on server
- Add route in Cloudflare dashboard
- Done!

### Cost

**Free tier includes:**
- Unlimited tunnels
- Unlimited bandwidth (reasonable use)
- 50 users for Access (if you add authentication)

---

## Option 2: Caddy 🎯 (Best Self-Hosted Option)

**Best for:** Self-hosted purists, simplicity, automatic HTTPS without external dependencies

### What It Is

Caddy is a modern web server with automatic HTTPS. Dead simple config, zero SSL hassle.

```
Internet :80/:443 → Caddy → Your Apps
```

### Pros

- ✅ **Automatic HTTPS** - Let's Encrypt integration, zero config
- ✅ **Incredibly simple** - No Docker labels, just a config file
- ✅ **Self-hosted** - No external dependencies
- ✅ **Great documentation** - Easy to learn
- ✅ **Multiple apps** - Simple to configure
- ✅ **HTTP/3 support** - Modern protocols out of the box
- ✅ **No vendor lock-in** - Standard web server

### Cons

- ⚠️ Need to manage one more container
- ⚠️ Ports 80/443 must be open on firewall
- ⚠️ Let's Encrypt rate limits (rarely an issue)
- ⚠️ Certificates stored locally (need backup strategy)

### Setup Steps

#### 1. Create Caddy Directory

```bash
mkdir -p ~/docker/caddy
cd ~/docker/caddy
```

#### 2. Create Caddyfile

`~/docker/caddy/Caddyfile`:

```caddyfile
# Link Radar API
api.linkradar.com {
    reverse_proxy linkradar-backend:3000
}

# Future apps - just add more blocks
# app.example.com {
#     reverse_proxy other-app:8080
# }
```

That's the entire configuration. SSL happens automatically.

#### 3. Create Caddy compose.yml

`~/docker/caddy/compose.yml`:

```yaml
name: caddy

services:
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"  # HTTP/3
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - caddy_net

volumes:
  caddy_data:
    name: caddy_data
  caddy_config:
    name: caddy_config

networks:
  caddy_net:
    name: caddy_net
    driver: bridge
```

#### 4. Start Caddy

```bash
docker compose up -d
```

Caddy automatically:
- Gets SSL certificate from Let's Encrypt
- Redirects HTTP → HTTPS
- Renews certificates before expiry

#### 5. Update Link Radar compose.yml

Add Caddy network:

```yaml
services:
  backend:
    # Remove ports - Caddy handles it
    # ports:
    #   - "${BACKEND_PORT:-3000}:3000"
    
    networks:
      - default      # For postgres/redis
      - caddy_net    # For Caddy
    # No labels needed!

networks:
  default:
    driver: bridge
  caddy_net:
    external: true
    name: caddy_net
```

#### 6. Redeploy Link Radar

```bash
cd ~/docker/link-radar/deploy
docker compose down
docker compose up -d
```

#### 7. Test

```bash
curl https://api.linkradar.com/up
```

### Adding New Apps

Edit `Caddyfile`:

```caddyfile
api.linkradar.com {
    reverse_proxy linkradar-backend:3000
}

newapp.example.com {
    reverse_proxy newapp-container:8080
}
```

Reload:
```bash
cd ~/docker/caddy
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

Done! SSL certificate automatically acquired.

### Ongoing Maintenance

**Updates:**
```bash
cd ~/docker/caddy
docker compose pull
docker compose up -d
```

**View logs:**
```bash
docker compose logs -f
```

**Check certificates:**
```bash
docker compose exec caddy caddy list-certificates
```

**Backup:**
```bash
# Backup caddy_data volume (contains certificates)
docker run --rm -v caddy_data:/data -v $(pwd):/backup alpine tar czf /backup/caddy-backup.tar.gz -C /data .
```

### Cost

Free! Open source, no external services.

---

## Option 3: Traefik 🚂 (Advanced, Flexible)

**Best for:** Complex setups, advanced routing needs, Docker label fans

### What It Is

Traefik is a dynamic reverse proxy that watches Docker and auto-configures based on container labels.

```
Internet :80/:443 → Traefik → Your Apps (via Docker labels)
```

### Pros

- ✅ **Automatic HTTPS** - Let's Encrypt integration
- ✅ **Docker-native** - Discovers containers automatically
- ✅ **Very flexible** - Advanced routing, middlewares, plugins
- ✅ **Great for complex setups** - Load balancing, circuit breakers, etc.
- ✅ **Self-hosted** - No external dependencies
- ✅ **Multiple apps** - Scales well

### Cons

- ⚠️ **Complex configuration** - Steeper learning curve
- ⚠️ **Labels on every app** - More verbose
- ⚠️ Ports 80/443 must be open
- ⚠️ **YAML + labels** - Two places to configure
- ⚠️ Overkill for simple setups

### Setup Steps

#### 1. Create Traefik Directory

```bash
mkdir -p ~/docker/traefik
cd ~/docker/traefik
```

#### 2. Create traefik.yml

`~/docker/traefik/traefik.yml`:

```yaml
api:
  dashboard: false  # Enable if you want web UI

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik_gateway

certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com
      storage: /acme.json
      httpChallenge:
        entryPoint: web
```

#### 3. Create acme.json

```bash
touch acme.json
chmod 600 acme.json
```

#### 4. Create Traefik compose.yml

`~/docker/traefik/compose.yml`:

```yaml
name: traefik

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro
      - ./acme.json:/acme.json
    networks:
      - gateway

networks:
  gateway:
    name: traefik_gateway
    driver: bridge
```

#### 5. Start Traefik

```bash
docker compose up -d
```

#### 6. Update Link Radar compose.yml

Add lots of labels:

```yaml
services:
  backend:
    # Remove ports
    networks:
      - default
      - traefik_gateway
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.lr-backend.rule=Host(`api.linkradar.com`)"
      - "traefik.http.routers.lr-backend.entrypoints=websecure"
      - "traefik.http.routers.lr-backend.tls.certresolver=letsencrypt"
      - "traefik.http.services.lr-backend.loadbalancer.server.port=3000"
      - "traefik.docker.network=traefik_gateway"

networks:
  default:
    driver: bridge
  traefik_gateway:
    external: true
    name: traefik_gateway
```

#### 7. Redeploy

```bash
cd ~/docker/link-radar/deploy
docker compose down
docker compose up -d
```

### Adding New Apps

Add labels to each app's compose file. More verbose than Caddy.

### Ongoing Maintenance

Similar to Caddy but with more complexity.

---

## Side-by-Side Comparison

| Feature | Cloudflare Tunnel | Caddy | Traefik |
|---------|------------------|-------|---------|
| **SSL Management** | ✅ Automatic (Cloudflare) | ✅ Automatic (Let's Encrypt) | ✅ Automatic (Let's Encrypt) |
| **Configuration** | ⭐ Web dashboard | ⭐⭐ One config file | ⭐ Config + labels |
| **Open Ports** | ✅ None (only SSH) | ⚠️ 80, 443 | ⚠️ 80, 443 |
| **External Dependency** | ⚠️ Cloudflare | ✅ None | ✅ None |
| **Setup Time** | ~30 min | ~20 min | ~45 min |
| **Learning Curve** | Low | Low | Medium-High |
| **Maintenance** | Minimal | Low | Medium |
| **DDoS Protection** | ✅ Included | ❌ DIY | ❌ DIY |
| **CDN** | ✅ Included | ❌ None | ❌ None |
| **Cost** | Free | Free | Free |
| **Privacy** | ⚠️ Through Cloudflare | ✅ Self-hosted | ✅ Self-hosted |
| **Multi-App** | ⭐⭐⭐ Excellent | ⭐⭐⭐ Excellent | ⭐⭐⭐ Excellent |
| **Certificate Backup** | ✅ No need | ⚠️ Required | ⚠️ Required |

---

## Recommendation by Use Case

### "I want zero SSL hassle forever" 
→ **Cloudflare Tunnel**

### "I want simple self-hosted" 
→ **Caddy**

### "I have complex routing needs" 
→ **Traefik**

### "I don't want another login" 
→ **Caddy** (no account needed)

### "I want maximum security" 
→ **Cloudflare Tunnel** (no open ports)

### "I value privacy/self-hosting" 
→ **Caddy** (100% self-hosted)

---

## My Personal Recommendation for Link Radar

**Go with Caddy** if you:
- Want simplicity
- Don't mind another container
- Prefer self-hosted
- Have used reverse proxies before

**Go with Cloudflare Tunnel** if you:
- Hate dealing with SSL certificates
- Want extra security (no open ports)
- Don't mind the Cloudflare login
- Want DDoS protection/CDN as bonus

**Skip Traefik unless** you need its advanced features or really love Docker labels.

---

## Current Status

✅ Link Radar works perfectly without any of these  
✅ Choose and implement when ready  
✅ No changes needed to current deployment until then  

**Testing URL (current):** `http://YOUR_SERVER_IP:3000/up`  
**Production URL (after setup):** `https://api.linkradar.com/up`
