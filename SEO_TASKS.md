# Komiuta - SEO & AI Search Task List

Living document. Last updated: 2026-10-31.
Scope: organic search (Google/Bing), AI answer engines (ChatGPT, Perplexity, Claude, Copilot) and the technical foundation behind both.

Legend: `[x]` shipped and verified live - `[ ]` open - `[!]` blocked / needs account access.

## P0 - Shipped and verified live

### Technical foundation
- [x] Unique page titles, meta descriptions, self-canonical URLs, robots meta and OG/Twitter tags.
- [x] Duplicate "Bus Booking" title suffix removed; titles end with "| Komiuta".
- [x] Dynamic sitemap.xml - 86 URLs (routes, cities, operators, blog, FAQ, About, static).
- [x] robots.txt - sitemap directive, utility paths disallowed, AI crawlers allowed.
- [x] /llms.txt with company facts, key pages and popular routes.
- [x] noindex,follow on the ticket lookup utility page.
- [x] Google and Bing verification meta-tag hooks wired to env vars.

### Structured data (JSON-LD)
- [x] Organization + WebSite on the homepage.
- [x] BusTrip + Offer on route landing pages.
- [x] FAQPage on route pages, FAQs, blog articles and city pages.
- [x] BreadcrumbList on route, city, operator, FAQ, blog and About pages.
- [x] ItemList on city pages and operator pages.
- [x] BlogPosting on blog articles; AboutPage and Blog schema.
- [x] Organization + Breadcrumb schema on Chyllz, Terms and Privacy pages.

### Content / landing pages
- [x] 55 route landing pages at /buses/:from-to-:to.
- [x] 7 city landing pages: Nairobi, Mombasa, Kisumu, Eldoret, Nakuru, Kericho, Kitale.
- [x] Operator pages: /operators and /operators/:slug (real routes, fares, ratings).
- [x] FAQs page at /faqs.
- [x] Travel blog at /blog with 3 launch guides.
- [x] About Komiuta at /about.
- [x] Homepage popular-routes block and footer cross-link mesh (7 routes / 7 cities / 7 help links).
- [x] Route -> city -> operator cross-linking on route, city and operator pages.

### Indexing / distribution
- [x] IndexNow key file live at /9f2c7a4e1b8d6f30c5a9e2b7d4f1a6c3.txt.
- [x] mix komiuta.indexnow task with dry-run.
- [x] 86 sitemap URLs submitted to IndexNow (HTTP 200).
- [x] GitHub Action (.github/workflows/indexnow.yml) submits automatically after every deploy; confirmed successful on b356d67.
- [x] Automated schema validation task: mix komiuta.validate_schema.
- [x] Live schema validation PASS on 86/86 pages (JSON-LD, canonical, title, description).
- [x] Regression tests for sitemap, robots, llms, canonical, schema, blog, About, operator mesh and IndexNow key.

### Analytics / performance
- [x] UTM/gclid/fbclid capture persisted per session.
- [x] Funnel events: page_view, ticket_view, search, select_bus, confirm_seats, begin_checkout, begin_payment.
- [x] Events pushed to dataLayer/gtag and to a custom komiuta:analytics DOM event.
- [x] Cache-Control public headers on sitemap.xml, robots.txt and llms.txt.
- [x] Deferred below-fold footer rendering.

**Verification snapshot:** mix precommit - 220/220 tests; schema validation - PASS 86/86 pages.

## P1 - Remaining (high impact)

- [ ] Expand route coverage beyond the current 55 (top 150) with genuinely unique fare/terminal/schedule content per route.
- [ ] More blog guides - at least 2 per week, each linked to the relevant route/city page and with BlogPosting + FAQs.
- [ ] Operator logos/ratings consistency across route pages and operator pages.
- [ ] Trust details - About/Contact business details (address, registration, support hours) and policy links for E-E-A-T.
- [ ] Image SEO - descriptive article images / og:image per guide and alt text (currently uses the hero image).
- [ ] Review/AggregateRating schema - only once real, displayable traveller reviews exist.
- [ ] Organic reporting - GA4 property/dashboard for route-page sessions, bookings and UTM source reporting.

## P2 - Growth

- [ ] Backlinks and local citations: bus stations, tourism boards, travel media, operator partner pages.
- [ ] Uganda/Tanzania route and city expansion (Kampala, Arusha, etc.) with localized content.
- [ ] Comparison and seasonal content (VIP vs normal seats, night buses, holiday fares).
- [ ] Segment the sitemap (sitemap-routes.xml, sitemap-cities.xml, sitemap-blog.xml) as the page count grows.
- [ ] Programmatic route pages for return directions and nearby-town variants where real inventory exists.

## Blocked / needs account or decisions

### Needs account/env (next 7 days)
- [ ] Set GA_MEASUREMENT_ID in Render -> GA4 events start flowing (analytics module already deployed).
- [ ] Google Search Console: verify, set GOOGLE_SITE_VERIFICATION, submit https://www.komiuta.com/sitemap.xml.
- [ ] Bing Webmaster: verify (or import from GSC), set BING_SITE_VERIFICATION, submit the sitemap.
- [ ] Refresh production bus inventory to a rolling 30-day window (currently today-only).

### Decisions
- [!] Production bus inventory refresh - future-date route/city pages render empty schedules; biggest ranking/conversion blocker.
- [!] Content cadence/ownership - who writes and approves the next batch of guides; operator/city pages auto-generated vs curated.

## Weekly monitoring

- Google Search Console impressions, clicks, CTR and average position for route/city queries.
- Indexed page count vs sitemap URL count (currently 86).
- IndexNow submission status after each content release (GitHub Action + manual task).
- Booking conversion rate for organic route-page visitors (GA4 + UTM).
- Core Web Vitals / TTFB on mobile (home ~0.82s, route ~1.7s on Render free).