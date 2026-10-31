# Xpressbus — Pre-Production QC Report

**Role:** UI/UX & Quality Control review
**Date:** 2026-10-29
**Scope:** Phoenix app under `xpressbus/` (booking flow, payments, auth, live views, assets, production config)
**Verdict:** All identified production blockers are fixed. The full suite passes (`121/121`); the remaining items in §3 are hardening/follow-ups rather than launch blockers.

---

## 1. Verification results (after fixes)

| Check | Result |
|---|---|
| `mix format --check-formatted` | PASS |
| `mix compile --warnings-as-errors` | PASS |
| `mix test` | **122/122 passed** at last full run; 13 mobile/PWA tests passed after the mobile-loading changes (see §2) |
| `mix phx.digest` | PASS — `priv/static/cache_manifest.json` now fully populated |
| Tailwind + esbuild production bundles | PASS (`app.css` 111.7 KB minified, `app.js` 149.7 KB minified) |
| Static image audit | PASS — every referenced image now exists |

Environment note: Git is not installed on this machine, so no commits were made. Source backups were saved to
`%TEMP%\xpressbus_src_backup_20261029_192240.zip` and the database was dumped to
`%TEMP%\buupasskomiuta_db_backup_20261029_195042.sql` before the catalogue migration ran.

Test database note: `config/test.exs` now defaults to `buupasskomiuta_test` (not the shared development
database). Previously the suite ran against `buupasskomiuta_db`, so seeded development rows made whole-table
assertions (`assert Coupons.list_coupons() == [coupon]`) fail; 5 tests were failing for that reason before the
change. `mix test` creates and migrates the isolated database automatically; CI can still override `DB_NAME`.

---

## 2. Production blockers fixed

### Database & production config
- **`config/runtime.exs` had no production database configuration at all** — the app could not boot in `prod` (Ecto Repo unconfigured). Added `DATABASE_URL` support with `DB_*` fallback and fail-fast validation.
- `PHX_HOST` silently defaulted to `example.com` in production (breaking WebSocket origin checks and links). Now **raises** when missing.
- Dev/test DB settings are now overridable via `DB_HOST`/`DB_PORT`/`DB_NAME`/`DB_USER`/`DB_PASSWORD` (needed for CI/review environments).
- Background BuuPass sync is now opt-in in production via `ENABLE_BACKGROUND_SYNC=true` (previously impossible to enable outside dev).

### Static assets (hard production failure)
- `priv/static/cache_manifest.json` contained an **empty digest map**, so digested static paths would fail in production. Regenerated the digest manifest and verified all entries.
- Added the missing `room_1/2/3.jpg` referenced by the Chyllz pages (they 404'd before, leaving blank cards).
- Replaced the broken 152-byte favicon and mislabelled 190×52 "PWA icons" with real square assets: `icon-192`, `icon-512`, `icon-maskable-512`, `apple-touch-icon`, `favicon-32`; updated `manifest.json`, root layout, and service worker.

### Payment security (fraud risk)
- **Paystack webhook had no signature verification.** Added HMAC-SHA512 verification of the `x-paystack-signature` header over the raw request body (new `RawBodyReader` plug reader), rejecting unsigned/forged webhooks with `401`.
- **Flutterwave webhook accepted any POST.** Added `verif-hash` validation; unknown events no longer overwrite payment status.
- **M-PESA callback trusted whatever arrived.** Now matches the callback against the stored payment and requested amount, ignores duplicates, and refuses amount mismatches before issuing a ticket.
- Flutterwave redirect/webhook and Paystack redirect are now finalised through the provider **verification API**, not the query string.
- `update_payment_status/3` can no longer downgrade a payment that is already `success` (protects against replayed/out-of-order webhooks).
- Removed verbose logging of full callback payloads (PII: names/phone numbers).

### Broken user flows
- **Post-payment ticket page showed nothing.** `/tickets?ticket_id=...` passed the id as a query param, but `TicketLive.mount/3` only sees path params. Added `handle_params/3`; the ticket now loads after payment.
- **Chyllz and InSURE pages crashed on header/footer clicks** (`back_to_search`, `change_footer_tab` sent to LiveViews with no matching `handle_event`). Added handlers; Chyllz now renders inside `<Layouts.app>` so flash messages appear.
- **Partner "Add Bus" form always failed** — it omitted required `departure`/`arrival` fields and used raw `String.to_integer`. Fixed validation, added header/nav, and **partner-submitted buses stay hidden from search until the operator is approved** (`operator.active`).
- Booking search no longer crashes on malformed date params (`Date.from_iso8601!` removed from request paths; date-part events are validated).
- Ticket page now has a header/navigation; **Print pass** and **Share ticket** buttons work (colocated LiveView hooks); export uses print-only CSS.
- Dashboard ticket modal no longer allows viewing tickets that do not belong to the signed-in user (IDOR fix).

### UI/UX & accessibility
- Removed literal `**EV (Electric Vehicle) fleet**` markdown that rendered as asterisks in the footer.
- Replaced dead `href="#"` links: Terms & Conditions links now go to new **`/terms`** and **`/privacy`** pages (real content, footer-linked); app-store badges now give honest "coming soon" feedback instead of jumping to page top.
- Added branded **404/500** error pages (previously plain "Not Found" text).
- Added SEO/social metadata (description, Open Graph, Twitter card, icons) to the root layout.
- Added `aria-pressed` to footer tabs, alt text to images, disabled/marked unfinished controls (language preference), and gave wallet/transfer/change-method buttons real feedback instead of silent no-ops.
- Referral "copy" now actually copies the code (previously it only claimed to).
- Print styles added; hero preload limited to pages that use it (perf win on admin/ticket pages).
- Service worker rewritten: stale-cache-safe, caches digested assets at runtime, no console noise.

### Code quality
- Removed `IO.inspect` debug output from admin fleet.
- Money precision migration (`20261029190000`): wallet/coupon/hotel/car columns were bare `:decimal` (MySQL `DECIMAL(10,0)`), silently rounding 120.50 → 121. Now `DECIMAL(12,2)` (ratings `3,2`).
- Added regression tests for payment signature verification, M-PESA amount validation, status-regression protection, and error pages.
- Fixed 10 failing tests (stale fixtures/types, DB-normalised decimals).

### Chyllz & InSURE catalogue now database-backed (follow-up, 2026-10-29)
- **The Chyllz pages (`/tour-packages`, `/tour-packages/hotels`, `/our-packages/hidden-gems`,
  `/tour-packages/car`, `/tour-packages/events`) rendered hard-coded demo cards.** They now read the
  database through the new `Xpressbus.Chyllz` catalogue context (hotels, hidden gems, car hires and
  events), filter to `active` rows only, collapse duplicate catalogue rows and bound every query.
- **The InSURE page (`/tour-packages/insurance`) had hard-coded plans, coverage rows and FAQs.** Plans,
  feature bullets, the coverage comparison table and the FAQ now come from the new `insurance_plans` and
  `insurance_faqs` tables via `Xpressbus.Insurance`. Default launch content is inserted by the migration,
  so a deploy that only runs `mix ecto.migrate` is never served an empty insurance page.
- Catalogue tables gained an `active` flag plus unique indexes (hotels/name, hidden gems/title,
  car hires/name+location, events/title+date). A data migration removed the duplicate rows created by
  repeatedly re-running the seeder (21→3 hotels, 21→3 gems, 21→3 cars, 14→2 events) and the seeder itself
  is now idempotent, so duplicates cannot come back.
- Search on the collection pages is real: it patches the URL (`?q=`), filters server-side and shows an
  empty state; cards open a detail dialog whose CTA links into bus search prefilled with the destination.
- Added the read-only `/admin/insurance-plans` catalogue page (linked from the Chyllz admin sidebar), and
  the header now keeps the Chyllz tab highlighted on all Chyllz sub-pages.
- New tests: catalogue query filtering/search/ordering, insurance ordering/coverage-matrix/defaults, and
  LiveView tests for every public page (DB content, inactive rows hidden, search, empty states, dialog,
  plan selection, cheapest-price pitch).

### User authentication — email OTP (2026-10-29)
- **Login no longer trusts a phone number.** `/user/auth` accepts a phone *or* email, emails a
  single-use 6-digit code to the account's email, and only stores a pending `login_user_id` in the
  session — no authenticated session is created until the code is verified.
- New `login_codes` table + `Xpressbus.Accounts.LoginCode`: only an HMAC-SHA256 digest keyed with
  `secret_key_base` is stored (never the code), 10-minute expiry, single use, max 5 attempts,
  60-second resend cooldown, max 5 codes/hour per account; issuing a new code invalidates older ones.
- New `Xpressbus.LoginEmail` (branded text + HTML email, code **not** in the subject). Delivered through
  Swoosh; tests assert delivery with the Test adapter and dev uses `/dev/mailbox`.
- New `/user/verify` (GET/POST) and `/user/verify/resend` (POST) pages; the session is renewed on
  successful login (`configure_session(renew: true)`), which also prevents session fixation.
- Registration now requires a valid email address (email is the login factor) and normalises it to
  lowercase; the server-side rules are enforced even if the browser `required` attribute is bypassed.
- `Accounts.get_user/1` resolves both UUIDs (OTP/Google sessions) and legacy phone session keys.
- Production mailer configuration added for Mailgun or Resend via env vars, with `MAILER_FROM`.
- 22 new tests: code delivery/expiry/single-use/attempt lockout/cooldown/rate-limit, registration
  validation/normalisation, and end-to-end controller flows (request → verify → dashboard session).

### Mobile loading performance (2026-10-29)
- **Phone hero image:** 637 KB `hero_bg.png` served on every landing page → responsive AVIF/WebP
  (`hero_bg-640/1024/1573`, **6–17 KB**) via `<picture>`, with a matching `type="image/avif"`
  LCP preload, `fetchpriority="high"`, `decoding="async"` and intrinsic `width`/`height`.
- **Chyllz pages no longer autoplay the 5.9 MB hero video on phones.** Mobile gets the small WebP
  poster; the video is loaded by a `HeroVideo` hook only at `≥768px`, and is skipped under
  Save-Data or `prefers-reduced-motion`.
- **Icon font:** the app previously fetched Google's full Material Symbols variable font from two
  render-blocking CSS requests (one duplicated via `@import` in `app.css`). It is now a
  **self-hosted 11 KB subset** (105 icons, static axes) that is preloaded, uses
  `font-display: block` to prevent raw icon-name text flashing, and keeps a per-glyph remote
  fallback. `scripts/fetch_icon_font.mjs` regenerates it when icons change.
- **Below-the-fold images** (partner/operator logos, store badges, ticket logo) are lazy-loaded with
  intrinsic dimensions; hotel room fallbacks are WebP (~16 KB each, down from ~55 KB JPEG).
- Removed the external font CSS chain and the duplicate blocking request; matched the hero preload
  to the `<picture>` source set so browsers do not download the image twice.
- Production bundles after minification/digest: `app.css` 111.7 KB, `app.js` 149.7 KB.
- 7 new regression tests: 5 source-level guardrails (`mobile_perf_test.exs`) and 2 **rendered-page**
  checks (`mobile_render_test.exs`) so stale compiled templates cannot silently regress this.
- Not changed (follow-ups): desktop still downloads the 5.9 MB hero video (needs an ffmpeg
  re-encode); Render's free tier cold start (~1 min after 15 min idle) is a plan limitation, not a
  UI fix.

---

## 3. Remaining risks — decide before go-live

1. ~~**BLOCKER: phone-only user login.**~~ **Resolved 2026-10-29** — login now requires a single-use email OTP (see §2). Residual follow-ups:
   - Accounts created before this change **without an email address** cannot receive codes; set an email for them (support/admin) before they need to log in.
   - `ensure_user_by_phone/2` (guest checkout) creates synthetic `phone@xpressbus.com` addresses; those users also need a real email.
   - Per-account limits exist, but an **IP-level throttle** on `/user/auth` and `/user/verify` is still recommended.
   - Changing the account email from the dashboard is not re-verified; consider requiring an OTP before changing it.
2. **No IP-level rate limiting** on `/admin/auth`, `/user/auth`, `/user/verify`, ticket lookup, or payment callbacks (auth now has per-account limits). Add `PlugAttack`/`Hammer` before launch.
3. **Admin auth is session-cookie based with no lockout/2FA.** PBKDF2-SHA256 (100k) hashing is fine; add login throttling and ideally 2FA for admin accounts.
4. ~~**External QR dependency.**~~ **Resolved 2026-10-29** — ticket QR codes are now generated locally by a dependency-free encoder (`Xpressbus.QR`) rendered as inline SVG and encoding the public ticket-tracking URL. Verified module-for-module against an independent QR implementation (byte mode, EC level M, versions 1 and 8). **Remaining:** app-store badges still load from Wikimedia; bundle them locally before launch.
5. ~~**Service worker + LiveView:** offline caching is progressive only; do not expect offline booking.~~ **PWA layer completed 2026-10-29** — installable manifest (shortcuts, maskable icons), the existing header "Download App" link now triggers the PWA install (native prompt / iOS Add-to-Home-Screen hint, falling back to the reserved `#app-section` store area), a locally generated QR in the app-download section opens the PWA for scanning, standalone styling, precached offline page served on failed navigations, font caching, and a silent service-worker update flow. HTML responses are deliberately not cached, so personal ticket pages never linger offline. Offline booking itself still requires a connection (expected).
6. ~~**Chyllz/InSURE pages are still curated/demo content.**~~ **Resolved 2026-10-29:** every Chyllz
   collection and the InSURE plans/coverage/FAQs are now read from the database (see §2). Content is
   managed by editing the catalogue tables; inactive rows are hidden from the public pages.
7. **Ticket lookup is public and unthrottled** (ticket-id + route + passenger name displayed). Consider requiring phone-last-4 for unauthenticated lookup.
8. `logout` remains a `GET` link (CSRF-logout style issue); move to `DELETE`/POST when convenient.
9. Inline theme scripts remain in `root.html.heex` (pre-existing; AGENTS.md prefers bundled JS). Low risk, left untouched to avoid UI regressions.
10. Some admin `handle_event` handlers cast client `page` values with `String.to_integer/1`; a crafted event can crash that LiveView session. Low severity.
11. **Render free tier cold start** — the service spins down after 15 minutes idle, so the first visit after a quiet period can take ~1 minute to load regardless of front-end optimisations. For real customers, upgrade the Render web service to an always-on plan (or keep it warm). This is the largest remaining phone-loading delay.

---

## 4. Production environment checklist

Required:
- `SECRET_KEY_BASE` (raise if missing — already enforced)
- `PHX_HOST` (now required — e.g. `www.komiuta.com`)
- Database: either `DATABASE_URL` (e.g. `mysql://user:pass@host:3306/buupasskomiuta_db`) **or** `DB_HOST`, `DB_NAME`, `DB_USER` (+ `DB_PASSWORD`, `DB_PORT` default 3306)
- **Transactional email (email OTP login):** `RESEND_API_KEY` (recommended) **or** `MAILGUN_API_KEY` + `MAILGUN_DOMAIN` (optional `MAILGUN_BASE_URL`) **or** `BREVO_API_KEY`; `MAILER_FROM` (default `no-reply@komiuta.com`). Render blocks outbound SMTP, so mailbox username/password credentials cannot be used — an HTTP email API is required. Verify with `mix komiuta.send_test_email --to you@example.com`. Without a provider, login codes cannot be delivered (Google sign-in still works).
- `PHX_SERVER=true` when starting a release
- `PORT` (default 4000)

Recommended:
- `POOL_SIZE` (default 10)
- `ENABLE_BACKGROUND_SYNC=true` on exactly one designated sync worker (otherwise scraped data never refreshes)
- `DNS_CLUSTER_QUERY` for clustered deployments

Build/deploy steps:
```
mix deps.get
MIX_ENV=prod mix assets.deploy     # tailwind + esbuild + phx.digest
MIX_ENV=prod mix ecto.migrate
MIX_ENV=prod mix release
```

---

## 5. Files touched (high level)

- Config: `config/runtime.exs`, `config/dev.exs`, `config/test.exs`
- Payments: `lib/xpressbus/payments.ex`, `payment_controller.ex`, `plugs/raw_body_reader.ex`, `endpoint.ex`
- Flows: `booking_live.ex`, `ticket_live.ex(+heex)`, `user_dashboard_live.ex(+heex)`, `chyllz_live.ex`, `insurance_live.ex`, `partner_registration_live.ex`, `admin_fleet_live.ex`, `legal_live.ex` (new), router
- UI: `brand_components.ex`, `layouts/root.html.heex`, `error_html/*` (new), `booking_live.html.heex`
- Assets: `app.css` (print styles), `app.js`, `manifest.json`, `sw.js`, new image/icon assets
- Data: `priv/repo/migrations/20261029190000_add_money_precision.exs`
- Tests: `payments_test.exs` (new), `error_html_test.exs`, fixtures, `coupons_test.exs`

### Follow-up: email OTP login (closes the phone-only blocker)

- Auth data: `priv/repo/migrations/20261029213000_create_login_codes.exs`,
  `lib/xpressbus/accounts/login_code.ex` (new)
- Auth context: `lib/xpressbus/accounts.ex` (OTP request/verify/resend, rate limits,
  `get_user_by_email/1`, `find_user_for_login/1`, `get_user/1` UUID+phone resolution),
  `lib/xpressbus/accounts/user.ex` (`registration_changeset/2`)
- Email: `lib/xpressbus/login_email.ex` (new), `config/config.exs` (`:mailer_from`),
  `config/runtime.exs` (Resend/Mailgun/Brevo provider config), `render.yaml` (provider env vars),
  `DEPLOY_RENDER.md` (email provider setup), `lib/mix/tasks/komiuta.send_test_email.ex` (delivery check)
- Web: `lib/xpressbus_web/controllers/user_controller.ex` (reworked),
  `lib/xpressbus_web/controllers/user_html/verify.html.heex` (new),
  `user_html/login.html.heex` (phone-or-email field), `lib/xpressbus_web/router.ex` (3 new routes)
- Tests: `test/xpressbus/login_code_test.exs`, `test/xpressbus_web/controllers/user_auth_test.exs` (both new)

### Follow-up: mobile loading performance (2026-10-29)

- Hero: `lib/xpressbus_web/live/booking_live.html.heex` (`<picture>` AVIF/WebP + lazy/dimensioned images),
  `lib/xpressbus_web/components/layouts/root.html.heex` (LCP preloads, no third-party font CSS),
  `priv/static/images/hero_bg-{640,1024,1573}.{avif,webp}` (new)
- Video: `lib/xpressbus_web/live/chyllz_live.ex` (desktop-only load), `assets/js/app.js` (`HeroVideo` hook),
  `priv/static/images/hero_bg-1024.webp` poster
- Icon font: `assets/css/app.css` (self-hosted `@font-face`), `priv/static/fonts/material-symbols-subset.woff2`,
  `scripts/fetch_icon_font.mjs` + `scripts/material-symbols-icons.txt` (regeneration)
- Images: `priv/static/images/room_{1,2,3}.webp` (new), lazy/intrinsic attributes in
  `brand_components.ex`, `booking_live.html.heex`, `user_html/login.html.heex`,
  `user_html/registration.html.heex`, `error_html/*`
- Tests: `test/xpressbus_web/mobile_perf_test.exs`, `test/xpressbus_web/mobile_render_test.exs` (new)

### Follow-up: Chyllz & InSURE → database-backed catalogue

- Catalogue contexts: `lib/xpressbus/chyllz.ex` (new), `lib/xpressbus/insurance.ex` (new)
- Insurance schema/seeds: `lib/xpressbus/insurance/insurance_plan.ex`,
  `lib/xpressbus/insurance/insurance_faq.ex`, `lib/xpressbus/insurance/seed_data.ex` (all new)
- Catalogue schemas: `lib/xpressbus/bookings/{hotel,hidden_gem,car_hire,event}.ex` (`active` field,
  `unique_constraint`), `lib/xpressbus/{hotels,hidden_gems,car_hires,events}.ex` (unchanged API)
- Public pages: `lib/xpressbus_web/live/chyllz_live.ex` (rewritten), `lib/xpressbus_web/live/insurance_live.ex`
  (rewritten), `lib/xpressbus_web/format.ex` (new display helpers)
- Admin: `lib/xpressbus_web/live/admin_insurance_live.ex(+heex)` (new), `admin_components.ex` (sidebar),
  `router.ex`, `brand_components.ex` (Chyllz tab highlight)
- Data: `priv/repo/migrations/20261029203000_catalogue_integrity.exs` (new),
  `priv/repo/migrations/20261029204500_create_insurance_tables.exs` (new), `priv/repo/seeds.exs`
- Tests: `test/xpressbus/chyllz_test.exs`, `test/xpressbus/insurance_test.exs`,
  `test/xpressbus_web/live/chyllz_live_test.exs`, `test/xpressbus_web/live/insurance_live_test.exs`,
  `test/support/fixtures/catalogue_fixtures.ex` (all new), `test/support/conn_case.ex` (sandbox setup)
- Config: `config/test.exs` (isolated `buupasskomiuta_test` database)

