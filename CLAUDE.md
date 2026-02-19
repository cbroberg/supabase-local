# supabase-local

Infrastructure repo for a local Supabase setup that simulates supabase.com.
See README.md for full setup instructions.

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

## Key URLs

| What | URL |
|------|-----|
| Supabase API | https://supabase.db |
| Supabase Studio | https://studio.supabase.db |
| MCP server | https://supabase.db/mcp |
| Auth callback | https://supabase.db/auth/v1/callback |

## Credentials

Run `supabase status` to get the current publishable and secret keys.
Do not commit these values — GitHub secret scanning will block the push.

## Gotchas

- **`.local` TLD** — does not work on macOS (hijacked by mDNS). Use `.db`, `.test` etc.
- **Node.js CA certs** — Node.js ignores the macOS system trust store. Affects both the NextJS dev script and Claude Code's MCP connections. Add `export NODE_EXTRA_CA_CERTS=$HOME/caddy-root.crt` to `~/.zshrc` so it applies globally, then relaunch Claude Code. Also set it explicitly in the NextJS dev script.
- **MCP config** — use `"type": "http"`, not `"sse"` (deprecated). `"enabled"` and `"description"` are invalid fields for HTTP servers and cause errors.
- **Google OAuth** — rejects fake TLDs like `.db`. Disabled for local dev. Use Cloudflare Tunnel or test on the real deployed app.
- **Caddy CA cert** — stored at `/var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt`, only readable by root. Use `sudo cp` to export it before `scp`.
- **Chrome on Ubuntu** — ignores the system cert store. Import the Caddy CA into Chrome's NSS database separately: `sudo apt install -y libnss3-tools && certutil -d sql:$HOME/.pki/nssdb -A -t "CT,," -n "Caddy Local CA" -i /tmp/caddy-local-ca.crt`. Fully quit and relaunch Chrome after.
- **GitHub secret scanning** — blocks pushes containing Supabase keys, OAuth secrets, or any credential-like strings. Keep secrets in `supabase/.env` (gitignored).
