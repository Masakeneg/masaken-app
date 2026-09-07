# Masaken App — مساكن

## Live URLs

All three serve the same code and auto-deploy on every push to `master`.

| URL | Host | Reachable in Egypt |
|-----|------|:---:|
| **https://masakeneg.github.io/masaken-app/** | GitHub Pages | ✅ |
| **https://masaken-app.cmd2sn9mct.workers.dev/** | Cloudflare | ✅ |
| https://masaken-app.netlify.app/ | Netlify | ❌ (`netlify.app` is ISP-filtered; works elsewhere) |

Give customers the **GitHub Pages** URL. Repo: `github.com/Masakeneg/masaken-app`.
Backend: Supabase project `aorxrwwpexsfodnjbzub` (Masakeneg org).

A custom domain (e.g. `app.masakeneg.com`) would replace all of these with one
branded URL and also un-block the Netlify copy — see `docs/launch-checklist.html`
phase 7.

---

Client-facing finishing-order app for Masaken. Clients browse finishing items by
category, build a request, and submit it. On submit the app:

1. opens a prefilled **WhatsApp** message to Masaken,
2. saves the order to a **Supabase** database,
3. sends an **email** notification (EmailJS).

**First visit** shows a welcome screen: *create account · sign in · continue as
guest*. The app opens after the visitor picks one (guest included). The choice is
remembered, so it doesn't reappear on later visits; signing out returns to it.

**Customers** can make an account (phone + password, no email needed) to watch
their order move through the pipeline in real time — from the welcome screen or
the **حسابي** tab later. Ordering as a guest still works; signing up links past
guest orders by phone number.

Masaken staff open a hidden **admin panel** (tap the "Masaken" logo 5×, then sign
in with a staff email) to see **all** orders and move them through the pipeline
`pending → contacted → confirmed → supervised → done`. Only accounts in the
`admins` table can open it. To add a team member: create their login in
Supabase → Authentication → Users, then run the `insert into public.admins …`
snippet at the top of `supabase/02_customer_accounts.sql`.

Everything here runs on **free tiers**: Supabase (database + auth) and a static
host (Netlify / Cloudflare Pages / GitHub Pages).

---

## Project layout

```
masaken-app/
├── public/                 ← this whole folder is what gets deployed
│   ├── index.html           the app (single file, Arabic / RTL)
│   ├── config.js            your Supabase + WhatsApp + EmailJS settings
│   ├── manifest.webmanifest PWA manifest (installable to home screen)
│   ├── sw.js                service worker (offline shell)
│   ├── icon.svg             app icon
│   └── _headers             security headers (Cloudflare Pages / Netlify)
├── supabase/
│   ├── schema.sql              run first in the Supabase SQL editor
│   └── 02_customer_accounts.sql  run second — accounts + order tracking
├── docs/
│   ├── masaken_pricelist.xlsx
│   └── ORIGINAL_HANDOFF.md
├── netlify.toml
└── README.md
```

There are **no secrets** in this repo. The Supabase anon key in `config.js` is a
public key by design — the database is locked down by Row Level Security so the
public can only *create* orders, never read customer data or change statuses.

---

## Setup — one time (~15 min)

### 1. Create the Supabase project

1. Sign up at <https://supabase.com> → **New project** (free plan).
2. Pick a region close to Egypt (e.g. `eu-central-1` / Frankfurt).
3. Wait for it to finish provisioning.

### 2. Create the database

1. In the project: **SQL Editor → New query**.
2. Run [`supabase/schema.sql`](supabase/schema.sql) — creates the `orders` table,
   `create_order()`, base security, realtime.
3. Run [`supabase/02_customer_accounts.sql`](supabase/02_customer_accounts.sql) —
   adds the `admins` allowlist, `orders.user_id`, customer-scoped security, and
   `link_my_orders()`.

### 3. Auth settings + staff logins

1. **Authentication → Sign In / Providers → Email**:
   - **Allow new users to sign up** → **ON** (customers register themselves)
   - **Confirm email** → **OFF** (phone accounts have no real inbox)
2. **Authentication → Users → Add user → Create new user**: email + password for
   each staff member, tick *Auto Confirm User*.
3. For **each** staff user, run in the SQL editor:
   ```sql
   insert into public.admins (id, email)
   select id, email from auth.users where email = 'them@example.com';
   ```
   (Without this a staff login sees no orders — only customers in `admins` can
   open the panel.)

### 4. Wire the app to the project

1. In Supabase: **Project Settings → API**. Copy:
   - **Project URL** (e.g. `https://abcdxyz.supabase.co`)
   - **anon / public** key
2. Open [`public/config.js`](public/config.js) and paste them into
   `SUPABASE_URL` and `SUPABASE_ANON_KEY`. Save.

That's it for the backend.

### 5. (Optional) EmailJS

EmailJS is already configured for Masaken in `config.js`. If the email address or
template changes, update the `EMAILJS_*` and `NOTIFY_EMAIL` values. Free tier is
200 emails/month. If a value is blank the app still works — it just skips the
email.

---

## Run it locally

The app must be served over HTTP (opening `index.html` from disk won't load
`config.js`). Any static server works, e.g.:

```bash
npx serve public
```

Then open the printed `http://localhost:3000` (or similar).

> The service worker and "Add to Home Screen" only activate over **HTTPS** (or
> `localhost`), so they may look inactive in some local setups — that's expected.

---

## Deploy (pick one — all free)

### Option A — Netlify (recommended)

1. Push this folder to a GitHub repo.
2. <https://app.netlify.com> → **Add new site → Import an existing project** →
   pick the repo.
3. Netlify reads `netlify.toml` automatically: publish directory `public`, no
   build command. Deploy.
4. **Site configuration → Domain management** → add `app.masakeneg.com` and
   follow the DNS instructions (add the CNAME at your domain registrar).

### Option B — Cloudflare Pages

1. Push to GitHub. <https://dash.cloudflare.com> → **Workers & Pages → Create →
   Pages → Connect to Git**.
2. Build command: *(none)*. Build output directory: `public`.
3. Add the custom domain under the project's **Custom domains** tab.

### Option C — GitHub Pages

1. Move the contents of `public/` to the repo root (GitHub Pages can't publish a
   subfolder without a build step) **or** use a `docs/` folder.
2. Repo **Settings → Pages** → source = your branch. Note: `_headers` and
   `netlify.toml` are ignored by GitHub Pages.

### After deploying

- Open the site, place a test order, confirm it appears in Supabase
  (**Table Editor → orders**).
- Tap the logo 5×, sign in with a staff account, confirm the order shows in the
  admin panel and that changing its status sticks after a refresh.

---

## How the pieces fit

| Concern | Where it lives |
|---|---|
| UI, screens, cart logic | `public/index.html` |
| Backend settings | `public/config.js` |
| Order storage | Supabase table `public.orders` |
| Public order submission | Supabase RPC `create_order()` (bypasses table RLS safely) |
| Staff read / status updates | direct table access, gated by Supabase Auth + RLS |
| Live admin refresh | Supabase Realtime on the `orders` table |
| Email alerts | EmailJS, called from the browser after a successful save |
| WhatsApp handoff | `https://wa.me/<number>?text=...` deep link |

### Security model

- The **anon key** can only call `create_order()` and nothing else on `orders`.
- `SELECT` / `UPDATE` on `orders` require a signed-in user (`authenticated`
  role). There is **no `DELETE` policy** — orders can't be deleted through the
  API.
- Staff accounts are created by hand in the Supabase dashboard; public sign-up is
  disabled.
- If you ever expose more tables, keep RLS enabled on every one of them.

---

## Common changes

**Add / edit finishing items or prices** — edit the `categories` and `items`
objects near the top of the `<script>` in `public/index.html`. (Prices are text,
e.g. `'180 ج.م / م²'`.) Reference: `docs/masaken_pricelist.xlsx`.

**Change the WhatsApp number** — `WHATSAPP_NUMBER` in `config.js` (international
format, digits only).

**Change the admin unlock** — it's 5 taps on the logo (`brandTap()` in
`index.html`). The real gate is the Supabase login, not the tap count.

**Force-refresh the app for all users after a deploy** — bump `CACHE_VERSION` in
`public/sw.js`.

---

## Possible next steps (not done here)

- **Native app**: wrap `public/` with [Capacitor](https://capacitorjs.com) for
  the App Store / Google Play. The web app is already a valid PWA shell.
- **Move email server-side**: replace the browser EmailJS call with a Supabase
  Edge Function triggered by a database webhook on insert — more reliable, and
  removes EmailJS from the client entirely.
- **Client order tracking**: currently clients get a one-time confirmation with
  no lookup. A "track my order" screen would need either a magic-link or a
  per-order token.
- **Proper PNG icons**: `icon.svg` covers modern installs; run
  `npx pwa-asset-generator public/icon.svg public` to also emit PNG sizes and
  splash screens.

---

## Migrating off the old prototype

The previous version stored orders in `window.storage`, which only works inside a
published Claude.ai artifact. Those orders **cannot** be exported and are not
carried over — the Supabase table starts empty.
