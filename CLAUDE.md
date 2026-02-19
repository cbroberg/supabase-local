# supabase-local

This repo is the **infrastructure side** of a local Supabase development setup that simulates a real-world hosted Supabase + cloud-deployed app architecture.

## Architecture

```
[Mac — simulates Fly.io]              [Ubuntu 192.168.1.92 — simulates supabase.com]
  NextJS app (separate repo)    →       Caddy (port 80)
  NEXT_PUBLIC_SUPABASE_URL=              ↓
    http://supabase.db          →     Supabase Kong (127.0.0.1:54321)
                                           ↓
                                       PostgreSQL (127.0.0.1:54322)
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

Caddy exposes Supabase to the local network so the Mac (or any device on the LAN) can reach it via `http://supabase.db` — simulating `https://yourproject.supabase.co`.

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

## /etc/hosts

### Ubuntu (`/etc/hosts`)

```
127.0.0.1 supabase.db
```

### Mac (`/etc/hosts`)

```
192.168.1.92 supabase.db
```

> Note: `.local` TLD does NOT work on macOS — it is hijacked by mDNS/Bonjour.
> Use `.db`, `.test`, or another custom TLD instead.

## NextJS App

Lives in a **separate repo** on the Mac. Connects to Supabase via:

```env
NEXT_PUBLIC_SUPABASE_URL=http://supabase.db
NEXT_PUBLIC_SUPABASE_ANON_KEY=<publishable key from `supabase status`>
```

## Migrations

Supabase migrations live in `supabase/migrations/`. Run with:

```bash
supabase db reset       # reset and re-apply all migrations
supabase migration new <name>  # create a new migration
```
