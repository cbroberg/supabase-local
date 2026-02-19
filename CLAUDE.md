# supabase-local

This repo is the **infrastructure side** of a local Supabase development setup that simulates a real-world hosted Supabase + cloud-deployed app architecture.

## Architecture

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

## Ubuntu Machine

- **LAN IP:** `192.168.1.92`
- **OS:** Ubuntu (Linux)
- **Supabase CLI version:** 2.75.0

## Supabase Local

Supabase runs via Docker using the Supabase CLI.

### Start / Stop

```bash
supabase start
supabase stop
```

### Status & credentials

```bash
supabase status
```

Key URLs (localhost only, accessed via Caddy from outside):

| Service       | URL                              |
|---------------|----------------------------------|
| API (Kong)    | http://127.0.0.1:54321           |
| Studio        | http://127.0.0.1:54323           |
| Mailpit       | http://127.0.0.1:54324           |
| Database      | postgresql://postgres:postgres@127.0.0.1:54322/postgres |

### Auth Keys

Run `supabase status` to get the current publishable and secret keys.
Do not commit these values — even for local dev, GitHub secret scanning will block the push.

## Caddy Reverse Proxy

Caddy exposes Supabase to the local network with HTTPS via its internal CA:

| Domain | Proxies to |
|--------|-----------|
| `https://supabase.db` | Supabase Kong (54321) — simulates `https://yourproject.supabase.co` |
| `https://studio.supabase.db` | Supabase Studio (54323) — simulates the supabase.com dashboard |

### Caddyfile

Stored in repo root at `Caddyfile`. Deployed to `/etc/caddy/Caddyfile`.

To deploy changes:
```bash
sudo cp /home/cb/Apps/cbroberg/supabase-local/Caddyfile /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

### Caddy service

```bash
sudo systemctl status caddy
sudo systemctl restart caddy
```

### Caddy CA cert (HTTPS trust)

Caddy uses `tls internal` — it generates its own local CA and signs certs for `supabase.db`
and `studio.supabase.db`. Each device needs to trust this CA once.

**Export cert (Ubuntu):**
```bash
sudo cp /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt /tmp/caddy-local-ca.crt
sudo chmod 644 /tmp/caddy-local-ca.crt
```

**Trust on Ubuntu:**
```bash
sudo cp /tmp/caddy-local-ca.crt /usr/local/share/ca-certificates/caddy-local-ca.crt
sudo update-ca-certificates
```

**Copy to Mac and trust (run on Mac):**
```bash
scp cb@192.168.1.92:/tmp/caddy-local-ca.crt /tmp/caddy-local-ca.crt
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/caddy-local-ca.crt
```

**Node.js / NextJS on Mac:**
Node.js ignores the macOS system trust store. Pass the cert explicitly via the dev script:
```json
"dev": "NODE_EXTRA_CA_CERTS=$HOME/caddy-root.crt next dev"
```
Move the cert to your home dir first:
```bash
cp /tmp/caddy-local-ca.crt ~/caddy-root.crt
```

## /etc/hosts

### Ubuntu (`/etc/hosts`)

```
127.0.0.1 supabase.db
127.0.0.1 studio.supabase.db
```

### Mac (`/etc/hosts`)

```
192.168.1.92 supabase.db
192.168.1.92 studio.supabase.db
```

> Note: `.local` TLD does NOT work on macOS — it is hijacked by mDNS/Bonjour.
> Use `.db`, `.test`, or another custom TLD instead.

## MCP Server

The local Supabase instance exposes a built-in MCP server at `http://127.0.0.1:54321/mcp`,
accessible from the network via Caddy at `https://supabase.db/mcp`.

### `.mcp.json`

Both this repo and the NextJS app repo use the same config:

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

> Use `"type": "http"` — the `"sse"` type is deprecated. The `"enabled"` and `"description"`
> fields are not valid for HTTP/SSE servers and will cause errors.

## Auth Providers

Auth providers are configured in `supabase/config.toml` (not via a dashboard UI like on supabase.com).
Changes require a Supabase restart:
```bash
supabase stop && supabase start
```

### Email/password

Enabled by default. No email confirmation required in local dev:
```toml
[auth.email]
enable_signup = true
enable_confirmations = false
```

### GitHub OAuth

1. Go to `https://github.com/settings/developers` → OAuth Apps → New OAuth App
2. Set Authorization callback URL to `https://supabase.db/auth/v1/callback`
3. Copy Client ID and Secret into `supabase/.env`:
```
GITHUB_CLIENT_ID=your_client_id
GITHUB_SECRET=your_client_secret
```

### Google OAuth

1. Go to `https://console.cloud.google.com` → APIs & Services → Credentials → Create OAuth 2.0 Client ID
2. Set Authorized redirect URI to `https://supabase.db/auth/v1/callback`
3. Copy Client ID and Secret into `supabase/.env`:
```
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_SECRET=your_client_secret
```

> `supabase/.env` is gitignored. Never commit OAuth secrets — GitHub secret scanning will block the push.

## NextJS App

Lives in a **separate repo** on the Mac. Connects to Supabase via:

```env
NEXT_PUBLIC_SUPABASE_URL=https://supabase.db
NEXT_PUBLIC_SUPABASE_ANON_KEY=<publishable key from `supabase status`>
```

Dev script must include `NODE_EXTRA_CA_CERTS` so Node.js trusts the Caddy CA:
```json
"dev": "NODE_EXTRA_CA_CERTS=$HOME/caddy-root.crt next dev"
```

## Migrations

Supabase migrations live in `supabase/migrations/`. Run with:

```bash
supabase db reset       # reset and re-apply all migrations
supabase migration new <name>  # create a new migration
```
