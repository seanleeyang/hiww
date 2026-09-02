# Mobile app (Flutter)

`mobile/` holds a Flutter client for iOS, Android and web. It consumes the
existing API as-is; the backend was not modified.

## Why

The pilot's only user-facing surface was `public/app.html`, a single static page
served by the API and reachable only on the operator's machine. A Flutter app
gives shoppers and travelers a real installable client on all three platforms
while reusing the same backend contract.

## How it maps to the API

| App area | Endpoints |
|---|---|
| Register / login | `POST /api/auth/register`, `POST /api/auth/login` (token in `data.token`) |
| Session bootstrap | `GET /api/me` → id, email, full_name, user_type, role, kyc_status, risk_status, `pilot.{manual_money, payment_instructions}` |
| Auth transport | `Authorization: Bearer <token>` on every non-public route; 401 ⇒ app clears the token and returns to login |
| Response shape | every success is `{ success, data, code }`; the client unwraps to `data`. Errors are `{ error, code }` + HTTP status |
| Profile | `GET /api/me` also returns `avatar_url, home_city, rating_avg, rating_count, delivered_count`; `PATCH /api/me` edits name/city/avatar_url |
| Discovery | `GET /api/discover/feed?type=all\|trips\|wants&category=` → interleaved trip + want cards with owner summary, `match_count`, `earn_estimate`; `GET /api/discover/route-match?source_country=` → `{count, sample}` |
| Trips / wants | `POST /api/trips` and `/api/requests` accept optional `title`, cities, `note`/`image_url`, `need_by`; `GET …/:id` embeds the owner summary |
| Orders | `GET /api/orders/:id` embeds `counterparty`, stage timestamps (`confirmed_at`/`shipped_at`/`delivered_at`), `request_image_url`, `request_category`, `can_review`, `my_review`; `GET /api/orders` lists the caller's orders |
| Reviews | `POST /api/orders/:id/review {rating,comment}` (delivered orders, once per reviewer); `GET /api/users/:id/reviews` |
| Messages | `GET/POST /api/orders/:id/messages`, `POST …/messages/read`, `GET /api/inbox` (per-order last message + unread count) |

CORS on the backend is `origin: true` (`src/app.ts`), so the web build calls the
API directly with no proxy.

## Design system

`mobile/lib/theme/` + `mobile/lib/ui/` — a consumer-grade look modelled on the
reference mockup:

- **Palette** — coral primary `#E1523A`, warm off-white surfaces, soft drop
  shadows (not Material elevation tint). Full light + dark schemes in
  `app_theme.dart`; brand-specific extras (`success`, `star`, `hairline`, …) live
  in `HiwwColors` (`app_colors.dart`).
- **Type** — Plus Jakarta Sans (OFL), the single variable font vendored to
  `assets/fonts/`.
- **Shape** — r20 cards, pill chips/badges, 52 px coral buttons, r14 inputs.
- **Widgets** (`lib/ui/`) — `SoftCard`, `InitialsAvatar`, `StatusPill`,
  `StarRating{Display,Input}`, `HeroImage` (URL + bundled fallback), `EmptyState`,
  `BrandMark`, `SectionHeader`. Formatting helpers in `lib/core/format.dart`.
- **App icon / splash** — generated: `dart run tool/gen_icon.dart` then
  `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.
- **Placeholder assets** — `assets/images/*` (Lorem Picsum) and the URL-paste
  image model are pilot stand-ins, **not for production** (see below).

## Phase roadmap

- **M1 (done)** — scaffold, API/token layer, auth, role-aware shell.
- **D1 (done)** — design system + reskin: themed auth, app shell with the
  **Browse / My Trips / My Wants / Inbox** nav, Account screen with a working KYC
  submit (`POST /api/compliance/kyc/submit`), branded web loader + app icon +
  native splash. Browse/Trips/Wants/Inbox are styled placeholders.
- **D2 (done)** — backend extensions (additive, no rewrites): migrations
  `007_profiles_and_discovery`, `008_reviews`, `009_messages`; new `discovery` /
  `reviews` / `messages` route modules; `/api/me` + `PATCH /api/me`; richer
  trips/requests; order stage timestamps + `delivered_count`. Full suite now
  **19 suites / 56 tests**.
- **D3 (done)** — Browse feed (interleaved trip/want cards, category filter,
  pull-to-refresh, FAB), Post Want sheet with route-match nudge, want detail +
  offers + accept, Make Offer, My Wants, My Trips (Trips/Offers tabs), New Trip,
  Trip detail with reviews. Minimal Order screen (pay / ship / receive) until D4.
  34 Flutter tests.
- **D4 (done)** — Order Tracker (dated `OrderStepper`, `TrustPanel` + how-it-works
  sheet, chat/report buttons, per-stage action), Confirm & Review screen
  (`/release` + `/review` in one step; review-only mode after delivery), Report a
  problem → dispute. Accepted wants/offers link to their order. 37 Flutter tests.
- **D5 (done)** — Inbox tab (avatar, last message, unread `Badge`) and per-order
  chat (bubble thread, composer, auto mark-read) polling `/api/orders/:id/messages`
  every 5 s and `/api/inbox` every 15 s; nav badge shows total unread.
  39 Flutter tests.
- **D6 (done)** — skeleton loaders (Browse), no-flash refresh, mouse-drag scroll
  on web, 720 px content cap on wide screens, Hero image transitions, a11y
  tooltips/semantics, Edit-profile sheet (`PATCH /api/me`).
- **Later** — real photo upload, push notifications, offline cache, i18n.

## Before a production release

None of this is in scope yet; it all needs a decision or a third-party account.

1. **API hosting + HTTPS.** The app needs one stable HTTPS URL per environment.
   The backend has no TLS of its own today (localhost + a manual tunnel per
   `docs/USER-APP.md`). Pick a host (Fly.io / Render / Cloud Run / VPS + Caddy)
   and a domain; set `HIWW_API_BASE_URL` per build flavour.
2. **Payments.** Still the manual-money pilot (`MANUAL_MONEY_PILOT=true`). Real
   card payments need a provider account (Opn/Omise, Stripe, 2C2P…), their
   publishable + secret keys and webhook signing secret, plus backend escrow /
   double-entry ledger work. Only the publishable key would ever go in the app.
3. **Identity / KYC.** `IDENTITY_PROVIDER=mock`. A real provider (NDID, Onfido,
   Sumsub) needs an account, API keys and a document-capture SDK in the app
   (camera permissions, new screens).
4. **Push notifications.** Firebase project (`google-services.json` /
   `GoogleService-Info.plist`), an APNs key from an Apple Developer account, and
   a backend send path.
5. **Store distribution.** Apple Developer Program ($99/yr) + signing assets;
   Google Play Console ($25 once) + an upload keystore kept in a secret manager,
   never in git. Bundle id is `com.hiww.hiww_mobile` — change it now if a
   different reverse-domain is wanted; it is painful to change after first
   publish.
6. **Secrets hygiene.** Anything secret stays server-side. The Flutter bundle
   ships to users — only publishable/client identifiers belong in it.
7. **Crash / analytics.** Sentry or Firebase Crashlytics before store launch
   (needs a DSN / project). Optional for an internal pilot.
8. **Imagery.** `assets/images/*` are Lorem Picsum placeholders and users
   currently paste photo URLs. Production needs licensed/branded art and real
   uploads to object storage (Cloudflare R2 / Supabase / S3) behind a
   signed-upload endpoint, plus a takedown path for user-supplied URLs.
9. **Content moderation.** Free-text reviews/chat and user image URLs need a
   report/remove flow before any public launch.
