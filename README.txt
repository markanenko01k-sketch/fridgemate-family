FRIDGEMATE FAMILY 3.0

Files:
- index.html: app client
- schema.sql: Supabase database and secure invite RPCs
- manifest.webmanifest, sw.js, icons: installable PWA assets

SETUP (iPhone only):
1. Open https://supabase.com/dashboard in Safari and create a project.
2. Open SQL Editor -> New query. Copy all of schema.sql into it and Run.
3. In Authentication -> Providers (or Sign In / Providers), enable Anonymous Sign-Ins.
4. Copy Project URL and anon/public publishable key from Project Settings -> API.
5. Upload index.html, manifest.webmanifest, sw.js, icon-192.png and icon-512.png to an HTTPS static host, all in the same root folder.
6. Open the HTTPS site on your iPhone. Enter Supabase URL and anon/public key.
7. On your phone create the family and send the invitation code to Marta.
8. On Marta's phone open the same site, enter the same Supabase URL/key, her name and the invite code.

IMPORTANT:
- This client is not live until you create/configure your own Supabase project and deploy the files to HTTPS. No cloud project or credentials have been created for you.
- Never put the Supabase service_role secret into the app. Use anon/public key only.
- Two-person limit is enforced in the join_family database function.
- Anonymous sessions are device/browser-specific. Do not clear Safari website data or sign out before adding a durable sign-in method (email/Apple) and recovery flow.
- Shared fridge, pantry and shopping rows sync through Supabase Realtime. Budget limit is currently local to each device; per-person expense attribution is basic. Scanner and product catalogue are not included in this build.
- This is a first family-sync prototype; test with non-sensitive sample data before relying on it.
