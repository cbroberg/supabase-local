# supabase-local

Local Supabase setup simulating a hosted supabase.com environment for local cross-machine development.

## Commands

```bash
npm start          # Start Supabase
npm stop           # Stop Supabase
npm run restart    # Restart Supabase
npm run status     # Show status and credentials
```

## Google OAuth — local dev limitation

Google OAuth requires a redirect URI with a real public TLD (`.com`, `.io` etc.). Our local
`https://supabase.db` domain uses a fake TLD so Google rejects it. Email and GitHub OAuth
work fine locally. Test Google OAuth on the real deployed app.

If you need Google OAuth locally, use **Cloudflare Tunnel** to give Ubuntu a real public URL:

```bash
# On Ubuntu — install and run a tunnel (no account needed for a temporary URL)
curl -L https://github.com/cloudflare/cloudflare-go/releases/latest -o cloudflared
# Or via apt:
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt update && sudo apt install cloudflared

# Start a tunnel to Supabase Kong
cloudflared tunnel --url http://localhost:54321
```

Cloudflare prints a URL like `https://random-words.trycloudflare.com`. Use that as your
`SUPABASE_URL` and register `https://random-words.trycloudflare.com/auth/v1/callback`
with Google. Note: the URL changes each run unless you set up a named tunnel with a
Cloudflare account.
