# Komiuta — SEO & AI Search Task List

Living document. Last updated: **2026-10-31**.
Scope: organic search (Google/Bing), AI answer engines (ChatGPT, Perplexity, Claude, Copilot) and the technical foundation behind both.

Legend: `[x]` shipped and verified live · `[ ]` open · `[!]` blocked / needs account access.

---

## P0 — Shipped and verified live

### Technical foundation
- [x] Unique page titles, meta descriptions, self-canonical URLs, robots meta and OG/Twitter tags (root layout + per-page assigns).
- [x] Duplicate `· Bus Booking` title suffix removed; titles now end `| Komiuta`.
- [x] `sitemap.xml` — dynamic XML sitemap, currently **77 URLs** (55 routes + 7 cities + blog/WP pages + static pages).
- [x] `robots.txt` — sitemap directive, checkout/utility paths disallowed, GPTBot / OAI-SearchBot / ChatGPT-User / ClaudeBot / Claude-SearchBot / PerplexityBot / Google-Extended allowed.
- [x] `/llms.txt` — company facts, key pages, popular routes and contact details for AI answer engines.
- [x] `noindex,follow` on the ticket lookup utility page and equivalent thin/utility pages.
- [x] Google (`GOOGLE_SITE_VERIFICATION`) and Bing (`BING_SITE_VERIFICATION`) meta-tag hooks are wired in the root layout; values still need to be added in Render.

### Structured data (JSON-LD)
- [x] `Organization` + `WebSite` on the homepage (logo, contactPoint, SearchAction).
- [x] `BusTrip` + `Offer` on route landing pages (price, currency, availability).
- [x] `FAQPage` on route pages, FAQs page and blog articles.
- [x] `BreadcrumbList` on route, city, FAQ, blog and About pages.
- [x] `ItemList` on city pages (routes from that city).
- [x] `BlogPosting` on blog articles (headline, dates, author/publisher, mainEntityOfPage).
- [x] `AboutPage` on `/about`.
- [x] `Blog` schema on `/blog`.

### Content / landing pages
- [x] **55 route landing pages** at `/buses/:from-to-:to` — route-specific title/meta, answer-first intro, live fare/operator data, FAQs, internal links.
- [x] **7 city landing pages** at `/cities/:slug` — Nairobi, Mombasa, Kisumu, Eldoret, Nakuru, Kericho, Kitale.
- [x] **FAQs page** at `/faqs` — 10 booking/payment/ticket questions with `FAQPage` schema.
- [x] **Travel blog** at `/blog` + 3 launch guides:
  - Nairobi to Kisumu bus guide
  - Paying for a bus ticket with M-PESA
  - Mombasa to Nairobi bus guide
- [x] **About Komiuta** at `/about` — story, coverage, trust/security, support, route links.
- [x] Homepage “Kenya’s most-booked bus routes” internal-link block.
- [x] Footer internal-link mesh: **7 popular routes / 7 cities / 7 help & company links** (symmetric columns).

### Indexing / distribution
- [x] IndexNow key file live at `https://www.komiuta.com/9f2c7a4e1b8d6f30c5a9e2b7d4f1a6c3.txt`.
- [x] `Xpressbus.IndexNow` + `mix komiuta.indexnow` task (dry-run supported).
- [x] **77 sitemap URLs submitted to IndexNow** — accepted (HTTP 200).
- [x] Automated regression coverage for sitemap, robots, llms, canonical, schema, blog, About and IndexNow key (`test/xpressbus_web/seo_test.exs`).

**Verification snapshot:** `mix precommit` — **218/218 tests**.

---

## P1 — Next (high impact)

- [ ] **Operator landing pages** — top 20 operators (`/operators/:slug`) with routes, fleet, ratings, policies and `Organization`/`ItemList` schema.
- [ ] **Expand route coverage** beyond the current 55 (top 150) with genuinely unique fare/terminal/schedule content per route.
- [ ] **Operator logos/ratings consistency** across route pages and operator pages.
- [ ] **More blog guides** — at least 2 per week, each linked to the relevant route/city page and with `BlogPosting` + FAQs.
- [ ] **Cross-link mesh** — add route → city → operator links and related-route blocks on every route page.
- [ ] **Schema validation pass** — Google Rich Results Test + Schema Markup Validator for a sample of route, city, FAQ, blog and About pages.
- [ ] **IndexNow automation on content releases** — run `mix komiuta.indexnow` after each content deploy (or wire it into the release step).
- [ ] **Organic conversion tracking** — UTM params on content links and booking events so route pages can be measured against revenue.
- [ ] **Core Web Vitals** — TTFB is currently ~0.8–1.4s on Render free; improve caching, reduce JS/CSS, consider paid instance for TTFB/LCP.
- [ ] **Review/AggregateRating schema** — only once real, displayable traveller reviews exist.
- [ ] **Trust details** — About/Contact business details (address, registration, support hours) and policy links for E-E-A-T.
- [ ] **Image SEO** — add descriptive `og:image` / article images and alt text for blog articles (currently uses the hero image).

## P2 — Growth

- [ ] Backlinks and local citations: bus stations, tourism boards, travel media, operator partner pages.
- [ ] Uganda/Tanzania route and city expansion (Kampala, Arusha, etc.) with localized content.
- [ ] Comparison and seasonal content (VIP vs normal seats, night buses, holiday fares).
- [ ] Segment the sitemap (`sitemap-routes.xml`, `sitemap-cities.xml`, `sitemap-blog.xml`) as the page count grows.
- [ ] Programmatic route pages for return directions and nearby-town variants where real inventory exists.

## Blocked / needs decisions or access

- [!] **Production bus inventory refresh** — inventory currently only covers today’s travel date; future-date route/city pages render empty schedules. This is the biggest blocker to ranking and converting for planned trips.
- [!] **Google Search Console** — verify `https://www.komiuta.com`, set `GOOGLE_SITE_VERIFICATION` in Render, submit `sitemap.xml`.
- [!] **Bing Webmaster Tools** — verify via import or `BING_SITE_VERIFICATION`, submit the same sitemap.
- [!] **Content cadence/ownership** — decide who writes and approves the next batch of guides and whether operator/city pages are auto-generated from the DB or curated.

## Weekly monitoring

- Google Search Console impressions, clicks, CTR and average position for route/city queries.
- Indexed page count vs sitemap URL count (currently 77).
- IndexNow submission status after each content release.
- Booking conversion rate for organic route-page visitors.
- Core Web Vitals / TTFB on mobile.
