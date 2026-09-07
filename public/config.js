/*
 * Masaken App — runtime configuration
 * ------------------------------------
 * This file is safe to commit and safe to serve publicly.
 *
 *  - SUPABASE_ANON_KEY is a *public* key by design. The database is protected
 *    by Row Level Security (see supabase/schema.sql): the public can only
 *    create orders, never read or edit them. Reading/editing requires a
 *    Masaken team login.
 *  - The EmailJS public key is likewise meant for the browser.
 *
 * Fill in the two Supabase values after creating your project
 * (Project Settings → API). Everything else is already set for Masaken.
 */
window.MASAKEN_CONFIG = {
  // ---- Supabase (backend) ----
  SUPABASE_URL: 'https://YOUR-PROJECT-REF.supabase.co',
  SUPABASE_ANON_KEY: 'YOUR-PUBLIC-ANON-KEY',

  // ---- WhatsApp (orders open a prefilled chat to this number) ----
  WHATSAPP_NUMBER: '201202992442', // international format, no + or spaces

  // ---- EmailJS (instant email on every new order) ----
  EMAILJS_SERVICE_ID: 'Masakeneg',
  EMAILJS_TEMPLATE_ID: 'template_8utzo2y',
  EMAILJS_PUBLIC_KEY: 'Udiq81A2l6_HX7SC5',
  NOTIFY_EMAIL: 'masakendesigns@outlook.com',
};
