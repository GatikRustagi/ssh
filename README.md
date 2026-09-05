# AudiencePulse — SIH 2026

AI-Driven Social Media Audience Intelligence Platform.

---

## Repository Structure

```
ssh/
├── twitter_scraper.js       ← JS scraper (Team Member 1: Twitter Data Miner)
├── package.json
├── .env                     ← Your local secrets (git-ignored)
├── .env.example             ← Template — copy this to .env and fill in values
└── audience_pulse/          ← Flutter app (Team Member 2+: Frontend / Flutter)
    └── lib/
        ├── features/
        │   ├── dashboard/            ← Main analytics dashboard
        │   ├── trends/               ← Twitter Trend Analysis Screen ← NEW
        │   │   ├── trend_analysis_screen.dart
        │   │   └── providers/trend_providers.dart
        │   ├── auth/
        │   └── ingestion_status/
        ├── models/
        ├── services/
        └── router/
```

---

## Branch Strategy

| Branch | Owner | Purpose |
|---|---|---|
| `main` | All | Stable, reviewed code |
| `feature/twitter-scraper` | Team Member 1 | JS scraper + Flutter Trend Screen |

---

## Team Member 1: Twitter Data Miner — Setup Guide

### 1. Clone & switch to your branch

```powershell
git clone <repo-url>
cd ssh
git checkout feature/twitter-scraper
```

### 2. Set up environment variables

```powershell
copy .env.example .env
# Now open .env and fill in:
#   SUPABASE_URL  → your Supabase Project URL (Project Settings → API → Project URL)
#   SUPABASE_KEY  → service_role key from the same page
#   TWITTER_USERNAME / TWITTER_PASSWORD / TWITTER_EMAIL → your Twitter credentials
```

> **⚠️ IMPORTANT — Fix common .env mistakes:**
> - `SUPABASE_URL` must NOT have a trailing `;` or `/`
> - `SUPABASE_KEY` must be the full JWT token (starts with `eyJ…`)
> - Never commit your real `.env` to git (it's already in `.gitignore`)

### 3. Install Node dependencies

```powershell
npm install
```

### 4. Run the scraper

```powershell
# Option A: Scrape tweets only (writes to authors + posts tables)
node twitter_scraper.js hashtag "#SIH2026"

# Option B: Scrape + extract trending hashtags (writes authors, posts AND trends)
node twitter_scraper.js analyze "#SIH2026"

# Option C: Scrape a specific user's timeline
node twitter_scraper.js timeline elonmusk

# Option D: Fetch live Twitter trends from twitterapi.io (requires API key in .env)
node twitter_scraper.js trends
```

You can pass a custom max items as the 3rd argument:
```powershell
node twitter_scraper.js analyze "#AI" 100
```

### 5. Verify data in Supabase

Open your Supabase project → Table Editor → check `authors`, `posts`, `trends` tables.

---

## Flutter App — Setup Guide

### 1. Prerequisites

- Flutter SDK ≥ 3.0 installed ([flutter.dev](https://flutter.dev))
- Android Studio or VS Code with Flutter extension

### 2. Create Flutter env file

Create `audience_pulse/.env` (or use the `--dart-define` approach):

The Flutter app reads Supabase credentials from `lib/core/supabase/supabase_client.dart` — update the URL and anon key there, **or** use `--dart-define` flags:

```powershell
cd audience_pulse
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```

### 3. Install Flutter dependencies

```powershell
cd audience_pulse
flutter pub get
```

### 4. Run the app

```powershell
# Web (recommended for dashboard)
flutter run -d chrome

# Android (connect device or emulator first)
flutter run -d android
```

### 5. Using the Trend Analysis Screen

After running the scraper (`node twitter_scraper.js analyze "#SIH2026"`):

1. Open the Flutter app
2. Click **"Trends"** in the dashboard AppBar
3. You'll see 3 tabs:
   - **Trending Now** — bar chart of top hashtags by growth rate
   - **Engagement** — hourly engagement line chart over 48h
   - **Top Authors** — ranked authors by total engagement with podium

---

## Supabase Table Reference

| Table | Written by scraper | Read by Flutter |
|---|---|---|
| `platforms` | ✅ auto-created | ✅ ingestion status |
| `authors` | ✅ every run | ✅ network graph, top authors |
| `posts` | ✅ every run | ✅ all panels |
| `trends` | ✅ `analyze` command | ✅ Trends panel + Trend screen |
| `sentiment_scores` | ❌ (AI pipeline) | ✅ sentiment chart |
| `network_edges` | ❌ (AI pipeline) | ✅ network graph |
| `demographic_summaries` | ❌ (AI pipeline) | ✅ demographics panel |

---

## Contributing

1. Create your feature branch from `main`: `git checkout -b feature/your-feature main`
2. Commit your changes with clear messages
3. Push: `git push origin feature/your-feature`
4. Open a Pull Request → `main`