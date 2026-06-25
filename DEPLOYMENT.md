# KajHobe — Deployment Reference

> Configuration map for the production web deployment.
> **No secret values are stored here.** Actual passwords, API keys, and OAuth
> secrets belong in a password manager (see "Secrets inventory" at the bottom).

Last updated: 2026-06-25

## Domain

| Item | Value |
|------|-------|
| Primary domain | `https://www.kajhobe.bd` (live) |
| Bare apex | `kajhobe.bd` — **not resolving yet**; apex→www redirect still TODO |
| Why not bare apex on Vercel | Public Suffix List `.bd` quirk; Vercel rejects the bare apex, so `www` is canonical |

## Registrar — BTCL (bdia panel)

| Item | Value |
|------|-------|
| Registrar | BTCL (Bangladesh) |
| Account / client name | `rabby010101` |
| Panel capability | Nameserver delegation only (no A/CNAME editor) → DNS moved to Cloudflare |
| Nameservers set at BTCL | `everton.ns.cloudflare.com`, `hattie.ns.cloudflare.com` |

## DNS — Cloudflare

| Item | Value |
|------|-------|
| DNS provider | Cloudflare (zone `kajhobe.bd`, Free plan) |
| `www` record | CNAME `www` → `f1e22570d6b07a64.vercel-dns-017.com` |
| `www` proxy status | **DNS only (grey cloud)** — required so Vercel issues TLS |
| NS delegation TTL | 24h — explains slow propagation to BD ISP resolvers |
| Apex redirect (TODO) | A `@` → `192.0.2.1` (proxied) + Redirect Rule `kajhobe.bd` → `https://www.kajhobe.bd` |

**Propagation tip:** if a device shows `DNS_PROBE_FINISHED_NXDOMAIN`, its resolver
cached the old delegation. Fix per-device with Cloudflare `1.1.1.1`/WARP app or
Chrome Secure DNS (DoH → Cloudflare), set router DNS to `1.1.1.1`/`8.8.8.8` to fix
all devices at once, or wait up to ~24h for it to clear automatically.

## Hosting — Vercel

| Item | Value |
|------|-------|
| Account | `rabby0101` (Hobby plan) |
| Project | `kaj-hobe` |
| Default URL | `kaj-hobe.vercel.app` |
| **Root Directory** | `Web` (repo root holds Android/iOS too) |
| Framework | Vite (auto-detected); build `npm run build` → `dist/` |
| SPA routing | `Web/vercel.json` rewrites all routes → `/index.html` |

## Source — GitHub

| Item | Value |
|------|-------|
| Repo | https://github.com/rabby0101/KajHobe.git |
| Production branch | `main` (this is what Vercel deploys to `www.kajhobe.bd`) |
| Recent web work branch | `reviews-routing-dashboard` |

> ⚠️ Make sure the branch Vercel deploys contains the latest `Web/` work **and**
> `Web/vercel.json`, or the live site shows an outdated version.

## Backend — Supabase

| Item | Value |
|------|-------|
| Project | `Khulna_Service_latest` |
| Project ref/id | `xatlqnbrvgukuqewsxux` (us-east-2) |
| URL | `https://xatlqnbrvgukuqewsxux.supabase.co` |
| Anon key | hardcoded in `Web/src/integrations/supabase/client.ts` (public, safe) |
| Edge functions | `bkash-collect`, `bkash-webhook`, `bkash-payout`, `send-sms-otp` |

## Production TODO (not yet done)

- [ ] Supabase → Auth → URL Configuration: **Site URL** = `https://www.kajhobe.bd`; add to **Redirect URLs** (else login/email confirm breaks)
- [ ] OAuth redirect URIs in Google Cloud / Facebook Developers / Apple Developer consoles
- [ ] Deploy edge functions + set their secrets in Supabase
- [ ] Apply pending provider-verification DB migration
- [ ] Cloudflare apex→www redirect rule (so bare `kajhobe.bd` works)
- [ ] `Web/index.html` branding still says "Khulna Services Hub" — update title/OG/favicon

## Secrets inventory — keep these in a PASSWORD MANAGER (never in the repo)

**Account logins:** BTCL/bdia · Cloudflare · Vercel · GitHub · Supabase dashboard

**Supabase project secrets (Edge Function env):**
`SUPABASE_SERVICE_ROLE_KEY` · `BKASH_BASE_URL` · `BKASH_APP_KEY` · `BKASH_APP_SECRET`
· `BKASH_USERNAME` · `BKASH_PASSWORD` · `SMS_GATEWAY_URL` · `SMS_API_KEY`
· `SMS_SENDER_ID` · `APP_DEEPLINK`

**OAuth client IDs + secrets:** Google Cloud · Facebook Developers · Apple Developer
