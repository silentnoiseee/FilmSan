# FilmFeed

A TikTok-style vertical feed for short film clips. Swipe up through clips,
each captioned with the film's title, year, and the timestamp it was taken from.

## How it works

- `index.html` — the whole app (UI, feed logic, gestures). Open it in a browser.
- `videos.js` — auto-generated manifest of every clip. **Not tracked in git** (it's
  regenerated from your folders and lists local file paths).
- `rebuild_feed.bat` / `rebuild_feed.ps1` — scan the film folders and rebuild `videos.js`.

## Adding films

1. Create a folder of clips. Name each clip like:
   `Title (Year) ... - HH.MM.SS-HH.MM.SS.mp4`
   (e.g. `Fargo (1996) 1080p - 00.56.10-00.56.51.mp4`)
2. Double-click `rebuild_feed.bat`.
3. Refresh the app.

The title, year, and timestamp are parsed from the filename and shown as the caption.

## Notes

- Video files (`*.mp4`, `*.mkv`, `*_clips/` folders, etc.) are git-ignored — they're
  too large to commit. Keep them on disk alongside the app.
- The "All films" feed shuffles clips and avoids playing the same film twice in a row.
- Use the 🎬 menu (or press `F`) to filter to a single film.
