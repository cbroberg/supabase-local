# supabase-local

Local Supabase setup simulating a hosted supabase.com environment for local cross-machine development.

```
[Mac — simulates Fly.io]              [Ubuntu 192.168.1.92 — simulates supabase.com]
  NextJS app (separate repo)    →       Caddy (port 443, HTTPS via internal CA)
  NEXT_PUBLIC_SUPABASE_URL=              ↓
    https://supabase.db         →     Supabase Kong (127.0.0.1:54321)
                                           ↓
                                       PostgreSQL (127.0.0.1:54322)

  Browser (Mac)                 →     https://studio.supabase.db
                                           ↓
                                       Supabase Studio (127.0.0.1:54323)
```

## Commands

```bash
npm start          # Start Supabase
npm stop           # Stop Supabase
npm run restart    # Restart Supabase
npm run status     # Show status and credentials
```

---

## Setup

### 1. Supabase

Install the Supabase CLI and start:

```bash
supabase start
supabase status    # shows URLs and auth keys
```

### 2. Caddy

Install Caddy and deploy the config:

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy

sudo cp Caddyfile /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

### 3. /etc/hosts

**Ubuntu:**
```
127.0.0.1 supabase.db
127.0.0.1 studio.supabase.db
```

**Mac:**
```
192.168.1.92 supabase.db
192.168.1.92 studio.supabase.db
```

> `.local` TLD does NOT work on macOS — hijacked by mDNS/Bonjour. Use `.db`, `.test` etc.

### 4. Trust the Caddy CA cert

Caddy uses `tls internal` — its own local CA. Each device must trust it once.

**Export from Ubuntu:**
```bash
sudo cp /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt /tmp/caddy-local-ca.crt
sudo chmod 644 /tmp/caddy-local-ca.crt
```

**Trust on Ubuntu (system):**
```bash
sudo cp /tmp/caddy-local-ca.crt /usr/local/share/ca-certificates/caddy-local-ca.crt
sudo update-ca-certificates
```

**Trust on Ubuntu (Chrome):**
Chrome ignores the system cert store and uses its own NSS database:
```bash
sudo apt install -y libnss3-tools
certutil -d sql:$HOME/.pki/nssdb -A -t "CT,," -n "Caddy Local CA" -i /tmp/caddy-local-ca.crt
```
Fully quit and relaunch Chrome after.

**Trust on Mac:**
```bash
scp cb@192.168.1.92:/tmp/caddy-local-ca.crt /tmp/caddy-local-ca.crt
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/caddy-local-ca.crt
cp /tmp/caddy-local-ca.crt ~/caddy-root.crt
```

### 5. MCP server

Add to `.mcp.json` in any project that should connect to local Supabase:

```json
{
  "mcpServers": {
    "supabase": {
      "type": "http",
      "url": "https://supabase.db/mcp"
    }
  }
}
```

> Use `"type": "http"` — `"sse"` is deprecated. `"enabled"` and `"description"` are not valid fields for HTTP servers.

---

## Auth providers

Providers are configured in `supabase/config.toml`. Changes require a restart:

```bash
npm run restart
```

### Email/password

Enabled by default. No confirmation required in local dev (`enable_confirmations = false`).

### GitHub OAuth

1. Go to `https://github.com/settings/developers` → **OAuth Apps** → **New OAuth App**
2. Fill in:
   - Homepage URL: `https://supabase.db`
   - Authorization callback URL: `https://supabase.db/auth/v1/callback`
3. Copy **Client ID** and generate a **Client Secret** (copy immediately — shown once)
4. Add to `supabase/.env`:
```
GITHUB_CLIENT_ID=your_client_id
GITHUB_SECRET=your_client_secret
```

### Google OAuth

**Disabled for local dev** — Google rejects redirect URIs with fake TLDs like `.db`.
Test Google OAuth on the real deployed app, or use Cloudflare Tunnel (see below).

For production, set the callback URL to your real domain and enable in `config.toml`:
```toml
[auth.external.google]
enabled = true
```

1. Go to `https://console.cloud.google.com` → **APIs & Services** → **OAuth consent screen**
   - User type: **External** → **Create**, fill in app name and email → **Save and Continue**
2. Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
   - Application type: **Web application**
   - Authorized redirect URI: `https://yourdomain.com/auth/v1/callback`
3. Add to `supabase/.env`:
```
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_SECRET=your_client_secret
```

> `supabase/.env` is gitignored. Never commit OAuth secrets.

### Google OAuth locally via Cloudflare Tunnel

Cloudflare Tunnel gives Ubuntu a real public URL that Google accepts:

```bash
# Install cloudflared on Ubuntu
sudo apt update && sudo apt install -y cloudflared

# Start a tunnel (no account needed for a temporary URL)
cloudflared tunnel --url http://localhost:54321
```

Cloudflare prints a URL like `https://random-words.trycloudflare.com`. Register
`https://random-words.trycloudflare.com/auth/v1/callback` with Google and use the
tunnel URL as `NEXT_PUBLIC_SUPABASE_URL`. Note: the URL changes each run unless you
set up a named tunnel with a Cloudflare account.

---

## NextJS app

In the separate NextJS repo on Mac:

```env
NEXT_PUBLIC_SUPABASE_URL=https://supabase.db
NEXT_PUBLIC_SUPABASE_ANON_KEY=<publishable key from `supabase status`>
```

Node.js ignores the macOS system trust store — pass the Caddy CA cert explicitly:
```json
"dev": "NODE_EXTRA_CA_CERTS=$HOME/caddy-root.crt next dev"
```

---

## Migrations

```bash
supabase db reset              # reset and re-apply all migrations
supabase migration new <name>  # create a new migration
```
