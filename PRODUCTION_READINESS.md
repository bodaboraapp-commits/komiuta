# Komiuta / Xpressbus — Production Readiness Task List

**Date:** 2026-10-31
**Status:** Code work is complete for launch and the current code **is now live on production**.
`www.komiuta.com` serves the release from commit `22850b7` (branch `phoenix-app`), verified with the
smoke test. Remaining go-live items are operational (email provider, payment integration secrets,
admin credentials, Render plan).

**Legend:** P0 = go-live blocker · P1 = do before/at launch if possible · P2 = post-launch backlog

---

## 0. Already done (do not redo)

- [x] Email OTP user login (phone-only takeover blocker closed) — `login_codes`, verify/resend pages,
      rate limits, registration requires email.
- [x] Payment webhook hardening (Paystack signature, Flutterwave hash, M-PESA amount/status checks,
      status-regression protection).
- [x] Local dependency-free ticket QR codes (no third-party QR API).
- [x] Installable PWA: manifest, service worker/offline shell, reuse of "Download App" for install,
      QR to the PWA in the app-download section.
- [x] Mobile loading performance: responsive AVIF/WebP hero (637 KB → 6–17 KB), desktop-only hero
      video (5.9 MB no longer downloaded on phones), 11 KB self-hosted icon font, lazy-loaded images,
      minified production bundles.
- [x] Money precision + catalogue/insurance integrity migrations, database-backed Chyllz/InSURE.
- [x] Production config: Render blueprint, `DATABASE_URL`/`DB_*`, `PHX_HOST` required,
      `force_ssl` + HSTS, error pages, SEO/OG tags, legal pages.
- [x] Test DB isolation (`buupasskomiuta_test`).
- [x] Last full suite: **122/122 passed** (before the mobile-loading patch); **13 targeted
      mobile/PWA tests** passed after it, including rendered-page checks.

> Run `mix precommit` once more before deploying (the last full run was not possible in the sandbox).

---

## 1. P0 — Go-live blockers

### P0-1. Publish and deploy the current code  ⏱ S  ✅ DONE
The live site is an older build. Source changes only reach Render through the GitHub branch
`phoenix-app` (`bodaboraapp-commits/komiuta`). Git is not installed on this machine; the portable
MinGit at `%TEMP%\komiuta-git\cmd\git.exe` plus the machine's GitHub SSH key were used instead of the
token script.

- [x] Run `mix precommit` (fix anything it reports). — **213/213 tests passed**.
- [x] Push the working tree to `phoenix-app` (commit `22850b7`) using portable Git over SSH
      (`GIT_SSH=C:\Windows\System32\OpenSSH\ssh.exe`).
- [x] Wait for Render auto-deploy — it triggered automatically on the push.
- [x] Verify the deploy live (the Render API key in `%TEMP%\render-api-key.txt` returns no services, so
      Render's API/`render-api.ps1 status` could not be used; verification was done against the live
      site instead).
- [x] `.\scratch\smoke-test.ps1 -BaseUrl https://www.komiuta.com` → **all checks passed**.
- [x] Verify the new build is visible: homepage hero is a `<picture>` with `hero_bg-640.avif`; login page
      says "Phone or Email"; `/tour-packages/insurance` renders the DB-backed plan grid + coverage table;
      `/tickets/:id/download` (new public route) responds; `/admin/insurance-plans` redirects to login.
- [ ] Rotate/delete `%TEMP%\render-api-key.txt` (currently unusable) and any legacy push tokens.

**Done when:** live commit matches local, smoke test passes, and `/user/login` shows the OTP flow.

### P0-2. Configure the production email provider (login OTP depends on it)  ⏱ S
Login emails cannot be delivered without this. Render blocks outbound SMTP, so use an HTTP API.

- [ ] Create a **Resend** account with the Komiuta mailbox (free: 3,000/month) — or Mailgun/Brevo.
- [ ] Add domain `komiuta.com` in Resend and add the DNS records it shows in **Cloudflare**
      (SPF/DKIM). Leave the existing MX records unchanged.
- [ ] Wait for Resend to show the domain as **Verified**.
- [ ] Create a sending-only API key.
- [ ] Add Render env vars: `RESEND_API_KEY` = key, `MAILER_FROM` = `no-reply@komiuta.com`
      (already in `render.yaml`). Redeploy if needed.
- [ ] Verify: `mix komiuta.send_test_email --to <your address>` with the same env vars set locally.
- [ ] End-to-end: request a login code on the live site and confirm it arrives.

**Done when:** production login emails arrive and `/user/verify` logs a user into `/dashboard`.

### P0-3. Production integration secrets and callbacks  ⏱ S
- [ ] Admin → `/admin/integration`: enter production **M-PESA / Flutterwave / Paystack** credentials
      and set callbacks to `https://www.komiuta.com/...` (not `api.komiuta.com`).
- [ ] Google OAuth: production client + redirect URI
      `https://www.komiuta.com/auth/google/callback`.
- [ ] Do one real low-value end-to-end payment per provider (or provider sandbox against production
      URLs) and confirm the ticket is issued exactly once and webhooks are accepted.
- [ ] If a provider cannot be enabled in time, hide/disable that option instead of launching it broken.

**Done when:** a live booking + payment produces a valid ticket and the ticket QR page loads.

### P0-4. Admin account hardening  ⏱ XS
- [ ] Set strong `ADMIN_EMAIL` / `ADMIN_PASSWORD` in Render (bootstrap runs on first boot).
- [ ] Confirm `/admin/login` works and the old/default password no longer does.
- [ ] Change any previously shared passwords (including the `no-reply@komiuta.com` mailbox password).

### P0-5. Database backup and migration check  ⏱ XS
- [ ] Take an Aiven MySQL backup/snapshot **before** the first deploy (pre-launch restore point).
- [ ] Confirm Render start command runs `mix ecto.migrate` and the `login_codes` table exists.
- [ ] Run the DB sync/import only for reference data (never users/tickets/payments over production).

**Done when:** migrations applied cleanly, backup stored, `/` returns 200 and login/booking work.

### P0-6. Handle legacy accounts without a real email  ⏱ M (product/support)
Existing phone-only users (and synthetic `phone@xpressbus.com` guest accounts) cannot receive OTP
codes and will be locked out. `/admin/users` currently only *flags* missing emails (read-only).

- [ ] Decide the support path: allow support to set an email per user (recommended: add an admin
      "set/verify email" action), or run a one-off SQL backfill from verified customer records.
- [ ] Audit the existing user table: count accounts with blank/`@xpressbus.com` emails.
- [ ] Communicate the new login flow to customers (email code instead of phone-only).
- [ ] Optionally add a "contact support" message on the login page for accounts without an email.

### P0-7. Render plan / cold start decision  ⏱ XS (billing)
Render Free spins down after 15 minutes idle → **~1 minute first load**, the largest remaining phone
delay. This cannot be fixed in code.

- [ ] Upgrade the web service to an always-on paid plan (`0.5c-512mb`, ~$7/mo), **or**
- [ ] Accept cold starts and set a 10-minute keepalive monitor (`/robots.txt` — light, no DB).
- [ ] If upgrading: enable `ENABLE_BACKGROUND_SYNC=true` on exactly one always-on instance
      (otherwise schedules never refresh).

---

## 2. P1 — Pre-launch hardening (recommended)

- [ ] **IP-level rate limiting** on `/user/auth`, `/user/verify`, `/admin/auth`, ticket lookup and
      payment callbacks (`Hammer`/`PlugAttack`). Per-account OTP limits already exist.
- [ ] **Ticket lookup privacy:** require phone-last-4 (or a ticket PIN) for unauthenticated lookups
      instead of showing passenger name/route to anyone with a ticket ID.
- [ ] **Admin 2FA / lockout** after repeated failed logins (PBKDF2 hashing is already in place).
- [ ] **Re-verify email changes:** changing the account email from the dashboard is not OTP-checked.
- [ ] Move `logout` from `GET` to `POST`/`DELETE` (CSRF-logout hygiene).
- [ ] Bundle the Wikimedia app-store badges locally (they are lazy-loaded now, but still third-party).
- [ ] Re-encode the desktop hero video (`hero_video.mp4`, 5.9 MB) — phones no longer download it,
      but desktop still does.
- [ ] Remove stale digested `priv/static/assets/css/app-*.css` files from old builds (deployment
      bloat only; not referenced).
- [ ] Monitoring/alerting: uptime check on `/`, Render log review, alert on email delivery errors
      and webhook failures.
- [ ] Backup/restore drill: confirm the Aiven restore path works before launch.
- [ ] Real-device QA: iPhone Safari + Android Chrome on 3G/4G — first load, icons (no raw icon text),
      layout, PWA install, offline page, OTP login, seat selection, payment return.
- [ ] Run `mix precommit` and deploy the result (must-have).

---

## 3. P2 — Post-launch backlog

- [ ] Harden admin `handle_event` handlers that cast client `page` values with `String.to_integer/1`.
- [ ] Move remaining inline theme scripts from `root.html.heex` into the JS bundle.
- [ ] Accessibility sweep (focus states, labels, contrast, keyboard nav).
- [ ] Replace app-store "coming soon" area with real links once the apps exist.
- [ ] Consider a CDN/image pipeline for operator logos (currently loaded from BuuPass blob storage).
- [ ] Consider a scheduled cleanup job for expired `login_codes` rows (housekeeping already prunes
      per-request; a periodic job is optional).

---

## 4. Production environment variables (Render)

| Variable | Required | Value / notes |
|---|---|---|
| `SECRET_KEY_BASE` | yes | `render.yaml` generates it |
| `PHX_HOST` | yes | `www.komiuta.com` |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | yes* | Aiven MySQL (*or `DATABASE_URL`) |
| `DB_SSL`, `DB_CA_CERT_BASE64` | yes* | Aiven TLS |
| `RESEND_API_KEY` (or Mailgun/Brevo) | yes | Email OTP delivery |
| `MAILER_FROM` | yes | `no-reply@komiuta.com` |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `ADMIN_NAME` | yes | First-boot bootstrap |
| `PHX_SERVER`, `PORT` | Render | handled by Render/`mix phx.server` |
| `POOL_SIZE` | recommended | `5` on free, raise with plan |
| `ENABLE_BACKGROUND_SYNC` | optional | `true` on exactly one always-on instance |
| `MAILGUN_API_KEY` + `MAILGUN_DOMAIN` / `BREVO_API_KEY` | optional | alternative email providers |

Never commit API keys, tokens, or mailbox passwords to the repo.

---

## 5. Go-live smoke test (after deploy, on a phone + desktop)

- [ ] Homepage: hero image loads fast, no 5.9 MB video request on the phone, no raw icon text.
- [ ] Search → results → passenger details → review & pay (test/live low-value).
- [ ] Payment callback/ticket issuance; ticket page QR scans to the ticket URL.
- [ ] User: request OTP by phone → email arrives → verify → dashboard; resend + expiry messages.
- [ ] Google sign-in works (or is hidden).
- [ ] PWA: install prompt/"Download App", offline page when network is cut.
- [ ] Admin: login, catalogue edits, `/admin/integration`, `/admin/users`.
- [ ] 404/500 pages render.
- [ ] `.\scratch\smoke-test.ps1 -BaseUrl https://www.komiuta.com` → all PASS.

---

## 6. Rollback plan

- **App:** Render → previous deploy → "Redeploy" (or `.\scratch\render-api.ps1` with the prior
  commit). The `login_codes` migration is additive and safe to leave applied.
- **Database:** restore the pre-launch Aiven snapshot if data corruption occurs.
- **Domain:** if Cloudflare → Render cutover misbehaves, restore the previous DNS record/tunnel;
  keep the current website DNS entry until the new deploy passes the smoke test.
- **Tickets already issued:** keep payment webhook secrets unchanged during rollback to avoid
  duplicate/failed ticket issuance.

---

## 7. Quick reference

- Deploy docs: `DEPLOY_RENDER.md` · QC details: `QC_REPORT.md`
- Helpers: `scratch/push_to_github.ps1`, `scratch/render-api.ps1`, `scratch/smoke-test.ps1`,
  `scratch/cloudflare-cutover.ps1`
- Email delivery check: `mix komiuta.send_test_email --to you@example.com`
- Icon font regeneration (after adding an icon): `node scripts/fetch_icon_font.mjs`
- Mobile perf regression tests: `test/xpressbus_web/mobile_perf_test.exs`,
  `test/xpressbus_web/mobile_render_test.exs`
