# Draw Room

Honest UK Lotto & EuroMillions number generator and draw-history explorer — real stats from the full official draw record, no fake predictions.

## Folders

| Path | What it is |
|---|---|
| `web/` | **The website.** Static site (no build step): `index.html` + `draws.json`. Backed by Supabase for the social/account features. |
| `capacitor-app/` | **The mobile app.** Capacitor wrapper that packages `web/` into native iOS + Android shells. |
| `artifact-source/` | The original claude.ai Artifact version, for reference. Uses Artifact-only `db`/`user` capabilities — it will *not* work as a plain website. |
| `draw-room-project.zip` | Snapshot including the pre-generated `android/` and `ios/` native projects, if you'd rather not regenerate them. |

## 1. Put it on GitHub (recommended first step)

1. Create an **empty** repo at <https://github.com/new> — no README, no .gitignore, no licence. Name it e.g. `draw-room`.
2. Double-click **`setup-github.bat`** and paste the repo URL when prompted.

That does `git init` → commit → push to `main`. A `.gitignore` is already in place so `node_modules/` and the generated `android/`/`ios/` folders stay out of the repo.

## 2. Deploy the website

**Option A — via GitHub (best: auto-deploys on every push).** After step 1, go to <https://vercel.com/new>, import the repo, and set **Root Directory** to `web`. Every future `git push` redeploys automatically.

**Option B — straight from this folder.** Double-click **`deploy-to-vercel.bat`**, or:

```
cd web
npx vercel deploy --prod --yes
```

First time only: `npx vercel login`.

Any static host works too (Netlify, Cloudflare Pages, GitHub Pages) — it's just two files.

### After the first deploy

Supabase must trust the new domain for email sign-in links to work. In the Supabase dashboard → **Authentication → URL Configuration**, add your Vercel URL to **Redirect URLs** (e.g. `https://draw-room.vercel.app/**`).

## 3. Build the mobile app

Double-click **`setup-capacitor.bat`** (runs `npm install` then adds both platforms), or:

```
cd capacitor-app
npm install
npx cap add android
npx cap add ios
```

**Android** — open `capacitor-app\android` in Android Studio and Run, or:
```
cd capacitor-app\android
gradlew assembleDebug
```
Needs the Android SDK (you already have `~\android-dev`, so likely installed).

**iOS** — requires a Mac with Xcode + CocoaPods. Not buildable on Windows. On a Mac:
```
cd capacitor-app/ios/App && pod install
```
then open `App.xcworkspace` in Xcode.

### After editing the site

The app bundles its own copy of the web assets, so re-copy and re-sync:
```
copy web\index.html capacitor-app\www\
copy web\draws.json capacitor-app\www\
cd capacitor-app && npx cap sync
```

## Backend (Supabase)

Project **`draw-room`** — id `talubhstvuqluwaztllv`, region ap-southeast-1, in your `kampot-match` organization. Already created and migrated.

| Table | Purpose |
|---|---|
| `profiles` | One row per user; `is_admin` flag, auto-set on signup for `artifarty@tutamail.com`. |
| `circles`, `circle_members` | Focus Circles — purely social, never affects odds. |
| `predictions`, `results` | The Prediction Test. Real results are fetched automatically (see below); manual entry is an admin-only fallback, enforced by RLS. |
| `sync_log` | Throttle bookkeeping for the results sync. Not readable by clients. |

### Automatic results

A Postgres function, `sync_results_internal()`, reads the official National Lottery results feed (the same XML the National Lottery site uses) from inside Supabase, validates it, and upserts into `results`. A `pg_cron` job (`sync-official-results`) runs it every 15 minutes. Signed-in users can also trigger a throttled refresh from the site ("Check for the result now"), which also happens automatically when a draw they predicted has closed but its result isn't in yet.

The feed only exposes the latest draw, so the job needs to keep running to avoid gaps. To check it: `select jobname, schedule, active from cron.job;` and `select * from sync_log;`.

### Prediction integrity

A database trigger on `predictions` rejects any prediction for a draw whose sales have already closed (7:30pm UK time for both games), for a draw that already has a result, for a non-draw day, or with invalid numbers. This holds even for someone calling the API directly, so the test can't be gamed after the fact.
| `quiz_history` | Intuition Quiz results, private per user (`user_id = auth.uid()`). |

All tables have Row Level Security on. The anon key embedded in `index.html` is safe to ship publicly — RLS is what protects the data, same model as a Firebase web key.

Sign-in is email magic-link (OTP). No passwords stored.

## Design notes

- **Lotto stats** use only the current 6/59 format (from Oct 2015) — the 6/49 era isn't comparable.
- **Lotto changed again on 10 June 2026:** each draw now has **two rounds** (two sets of six numbers plus a bonus ball), and every ticket is checked against both. The Prediction Test handles this — a Lotto ticket is scored against both rounds and the chance baseline doubles to match. `draws.json` only holds one set per draw from that date, which is fine for number-frequency stats but isn't a full record of the new format.
- `draws.json` currently ends in mid-September 2026; it is a static snapshot and is not updated by the results sync.
- **EuroMillions Lucky Star stats** use only the stable 1–12 era (from Sep 2016). The star pool grew 9 → 11 → 12 over time; including the earlier draws made stars 10–12 look "cold" and produced a bogus p < 0.0001. Restricted to the stable era, p = 0.19 — i.e. no signal, which is the correct answer.
- The chi-square test is computed client-side with a Wilson–Hilferty approximation, so there's no stats library dependency.
- The generator's "hot"/"cold"/"balanced" modes are presented as *styles of picking*, not edges. The app says plainly, in several places, that none of them change the odds — because they don't.
