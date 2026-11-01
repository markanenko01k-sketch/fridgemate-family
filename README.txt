FRIDGEMATE FAMILY 4.0 — GLASS EDITION

WHAT'S NEW
- Apple Glass-inspired responsive interface for iPhone.
- Shared fridge and pantry inventory with search, category filters, edit/delete, quantity controls and expiry alerts.
- Shared shopping list with purchase check-off and optional transfer into fridge/pantry.
- Shared monthly budget stored in Supabase, plus per-member spend totals and purchase history.
- Recipe suggestions matched against current inventory (rule-based local matching, no external AI service required).
- Shared meal plan.
- Persistent invitation-code retrieval and rotation.
- Realtime updates across the two family devices.

IMPORTANT ABOUT AI
The recipe matcher in this build is a local ingredient-matching assistant, not a generative AI model. Photo recognition/barcode lookup and generated AI recipes require a separate secure AI/API service and are not represented as active features in this release.

UPGRADE FROM 3.0
1. Keep your current Supabase project. Do NOT delete the project, family, or family_items table.
2. In Supabase Dashboard -> SQL Editor -> New query, open migration_v4.sql, copy all of it and Run.
3. Wait for "Success". Existing family membership and product records are preserved.
4. In GitHub repository fridgemate-family, replace index.html, sw.js and manifest.webmanifest with the files from this package. Keep icon-192.png and icon-512.png as they are.
   On GitHub: open a file -> pencil/Edit -> replace all contents -> Commit changes. Repeat for each of the three files.
5. Open https://markanenko01k-sketch.github.io/fridgemate-family/ in Safari and refresh. If the old version remains, close the tab and reopen; the service worker cache is versioned to v4.
6. Your existing Supabase URL, public key, anonymous session and family should be reused on the same iPhone/browser. Do not sign out or clear Safari data.
7. Open Family -> invitation code. Share it privately with Marta. On her iPhone, open the same URL, use the same Supabase URL and publishable key, enter her name and the invitation code.

DATABASE MIGRATION
migration_v4.sql extends the current schema with shared settings, budget, meal planning, purchase attribution, and persistent invite-code functions. It does not drop existing tables or rows.

SECURITY
- Use only the Supabase publishable/anon key in the browser.
- Never use service_role or secret keys in the app.
- The family remains limited to two members by join_family.
- Anonymous sessions are tied to the browser/device. Until durable email/Apple sign-in and recovery are added, do not clear Safari website data or sign out.

CURRENT SCOPE
This is a richer PWA release, not an App Store native app. Photo-to-product AI recognition, barcode catalogue lookup, push notifications, and durable account recovery are future integrations and require additional backend/provider configuration.
