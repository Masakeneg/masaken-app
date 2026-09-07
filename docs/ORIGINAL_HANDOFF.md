# Masaken App — Handoff to Claude Code

## What this is
A working prototype (`index.html`) for the Masaken finishing-order app:
- Client browses finishing items by category, submits a request
- Order auto-opens WhatsApp to Masaken with prefilled details
- EmailJS sends an email notification on new orders
- Hidden admin panel (tap "Masaken" logo 5x, PIN: 2026) to manage order status
- Data currently persists via `window.storage`, which only works inside
  a published Claude.ai artifact — NOT as a standalone file.

## What's needed to make this a real, independently-hosted app
1. Replace `window.storage` calls (`loadOrders`/`saveOrders` functions) with
   a real backend — Firebase, Supabase, or a small Node/Express + DB API.
2. Host the frontend on a real domain (Netlify/Vercel/Hostinger), ideally
   `app.masakeneg.com`.
3. (Optional) Wrap as a native app with Capacitor for App Store/Google Play.
4. EmailJS is already wired — credentials are in the CONFIG object at the
   top of the `<script>` tag in index.html.

## Brand reference
- Colors: charcoal #1C1C1A, cream #F6F1E7, brass gold #A97B35 / #C9A05C
- Fonts: Cairo (Arabic), IBM Plex Mono (numbers/labels)
- Pricing data: see masaken_pricelist.xlsx
