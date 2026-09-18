# Cinematic Roll staging deployment

The `staging` branch is an allowlisted deployment branch. `deploy-manifest.txt` is the source of truth for files copied into `.deploy/`; media-processing scripts, raw source media, logs, reports, SQL exports, credentials, and local backups are intentionally excluded.

The GitHub Actions `staging` environment must define these secrets:

- `TMDB_API_KEY`
- `HOSTINGER_FTP_SERVER`
- `HOSTINGER_FTP_USERNAME`
- `HOSTINGER_FTP_PASSWORD`
- `HOSTINGER_STAGING_DIR` (the staging document root, including its trailing slash)

The workflow uses FTPS and never performs a clean-slate deletion. Protect the `staging` environment with required reviewers before adding credentials if manual approval is desired.

The browser-visible Supabase `sb_publishable_…` key is intentionally public and is restricted by Supabase Row Level Security. A Supabase service-role key must never be added to this repository or to browser code.

Editorial MP4 files remain local and are excluded from Git. The staged article and homepage gracefully fall back to their checked-in poster images. Move those videos to Bunny and update `articles.json` to public HLS URLs if motion is required on staging.
