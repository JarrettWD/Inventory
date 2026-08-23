/* OPTIONAL. The app normally asks for these on first run and saves them on the
   device, so a deployment needs no secret file at all.

   Copy this to config.js only if you want a local checkout to skip that prompt.
   config.js is gitignored; this template is safe to commit. A connection
   entered in the app takes precedence over anything set here. */

window.APP_CONFIG = {
  supabaseUrl: 'https://YOUR-PROJECT-REF.supabase.co',
  supabaseKey: 'YOUR-PUBLISHABLE-KEY',
  table: 'inventory'
};
