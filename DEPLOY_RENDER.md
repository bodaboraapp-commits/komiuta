# Deploying Komiuta on Render (free tier) + Aiven free MySQL

This is the production deployment path for the Phoenix app, replacing the
Cloudflare Tunnel demo. Render hosts the app; Aiven hosts MySQL (Render does not
offer managed MySQL, and its free Postgres is Postgres-only + expires in 30 days).

> Render's Free web service is explicitly **not for production**: it spins down
> after 15 minutes of inactivity (~1 minute cold start), has 512 MB RAM / 0.1 CPU,
> and an ephemeral filesystem. This setup is fine for staging/demos; for real
> customers upgrade the web service to the paid `0.5c-512mb` plan (~$7/mo).

---

## 1. Create the free MySQL database (Aiven)

1. Sign up at <https://aiven.io> (no credit card required).
2. **Create service** → **MySQL** → plan **Free** → pick a region close to Render
   (e.g. `aws-eu-west-1` / Frankfurt).
3. Once running, note from **Overview → Connection information**:
   - Host, Port, User (`avnadmin`), Password, Database (`defaultdb`)
4. Download the CA certificate (**Overview → Connection information → CA certificate**
   → `ca.pem`).
5. **Allow Render to connect:** *Service → Networking → IP allowlist* →
   add `0.0.0.0/0` (connection is TLS-encrypted; restrict later once you have
   Render's egress ranges) — or add Render's published outbound IP ranges for
   your region.

> Free plan limits: 1 CPU / 1 GB RAM / 1 GB disk, 76 max connections, no SLA.
> Aiven may power off inactive free services; you can power them back on.

## 2. Deploy the app on Render

1. Render Dashboard → **New → Blueprint**.
2. Connect the GitHub repo `bodaboraapp-commits/komiuta` and select branch
   **`phoenix-app`**. Render reads [`render.yaml`](../render.yaml) automatically.
3. Fill in the `sync: false` environment variables:

| Variable | Value |
|---|---|
| `DB_HOST` | Aiven host |
| `DB_PORT` | Aiven port |
| `DB_NAME` | `defaultdb` (or your DB name) |
| `DB_USER` | `avnadmin` |
| `DB_PASSWORD` | Aiven password |
| `DB_CA_CERT_BASE64` | base64 of `ca.pem` — see below |
| `ADMIN_EMAIL` | admin login email (created once on first boot) |
| `ADMIN_PASSWORD` | strong password — change any old/default password |

`SECRET_KEY_BASE` is generated automatically by Render.

Generate the base64 CA value on Windows:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\ca.pem"))
```

4. Click **Apply**. The build runs:
   `mix deps.get && mix assets.setup && mix assets.deploy && mix compile`
   and the start command runs:
   `mix ecto.migrate && mix run priv/repo/render_bootstrap.exs && mix phx.server`
5. Wait for the deploy, then open `https://komiuta-xxxx.onrender.com` — the
   Phoenix homepage and `/admin/login` should work.

## 3. Import the reference data

Run from the machine that has `mysql` (this PC) — the Aiven DB is on the
public internet with TLS:

```powershell
cd C:\xampp\htdocs\www\xpressbus\xpressbus
Expand-Archive "$env:TEMP\komiuta-db-sync\data_sync.sql.zip" -DestinationPath "$env:TEMP\komiuta-import" -Force
& 'C:\xampp\mysql\bin\mysql.exe' -h <DB_HOST> -P <DB_PORT> -u avnadmin -p `
  --ssl-mode=VERIFY_CA --ssl-ca=<path-to-ca.pem> defaultdb `
  -e "source C:/Users/user/AppData/Local/Temp/komiuta-import/data_sync.sql"
```

The bundle contains only `INSERT ... ON DUPLICATE KEY UPDATE` / `UPDATE`
statements (no deletes) and excludes users, tickets, payments, admins and
integration secrets.

## 4. Custom domain + Cloudflare DNS

1. In Render: **Service → Settings → Custom Domains** → add
   `www.komiuta.com` and `komiuta.com`. Render shows the target hostname
   (`komiuta-xxxx.onrender.com`).
2. In Cloudflare DNS, replace the existing **tunnel CNAMEs** for `@` and `www`
   with:

   | Type | Name | Target | Proxy |
   |---|---|---|---|
   | CNAME | `@` | `komiuta-xxxx.onrender.com` | Proxied (orange) |
   | CNAME | `www` | `komiuta-xxxx.onrender.com` | Proxied (orange) |

   (Cloudflare flattens CNAME at the apex automatically.)
3. Cloudflare **SSL/TLS → Overview → Full (strict)**.
4. Verify `https://www.komiuta.com` serves the Phoenix app, including LiveView
   interactions.
5. Once verified, stop/remove the old Cloudflare Tunnel (`komiuta`) and the
   local app on this PC.

## 5. After cutover

- Admin → **Integration** settings: re-enter M-Pesa / Flutterwave / Paystack /
  Google OAuth keys for the production database, and set callback URLs to
  `https://www.komiuta.com/...` (the old defaults point at `api.komiuta.com`,
  which does not exist).
- Google OAuth redirect URI: `https://www.komiuta.com/auth/google/callback`.
- Bus schedules: run `mix buupass.pull` locally and re-import, or enable
  `ENABLE_BACKGROUND_SYNC=true` (not recommended on a free/spinning-down
  instance; better a cron job / paid always-on service).
- Upgrading later: change the Render compute plan to `0.5c-512mb` (paid,
  always-on) and/or move MySQL to a paid plan.

## Troubleshooting

| Symptom | Check |
|---|---|
| Build fails | Render logs; Elixir version (`ELIXIR_VERSION=1.18.4`), `mix.lock` compatibility, esbuild/tailwind downloads |
| App boots but DB errors | Aiven host/port/user/password, TLS env vars, Aiven IP allowlist |
| 502 on first visit | Free instance cold start (~1 min) — retry |
| LiveView not interactive | `check_origin` (set to `:conn`), Cloudflare WebSockets (proxied is fine) |
| Migrations | `mix ecto.migrate` runs at every start; check Render logs |
| Health check fails | `/` must return 200; check DB connectivity first |
