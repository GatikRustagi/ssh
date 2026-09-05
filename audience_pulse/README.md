# AudiencePulse 🎯
### AI-Driven Social Media Audience Intelligence Platform
*Smart India Hackathon 2026*

[![Flutter](https://img.shields.io/badge/Flutter-3.44-blue?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-2.x-green?logo=supabase)](https://supabase.com)

---

## What It Does

AudiencePulse ingests social media data (X/Twitter, Telegram) and delivers four kinds of audience intelligence:

| Panel | What it shows |
|-------|--------------|
| 📈 **Sentiment Timeline** | Emotion trends over time, color-coded per label (positive / negative / sarcastic / anxious / supportive / against) |
| 🔥 **Top Trends** | Rising keywords & topics ranked by growth rate |
| 🕸️ **Influence Network** | Force-directed graph of authors with KOL highlighting |
| 👥 **Demographics** | Age, language, and region distribution of followers |

---

## Quick Start

### 1. Prerequisites

- Flutter 3.44+ (`flutter --version`)
- A Supabase project (yours is already set up at `yyrxgmkeyxfohururkfi`)

### 2. Run the Supabase Migration

1. Open [Supabase SQL Editor](https://supabase.com/dashboard/project/yyrxgmkeyxfohururkfi/sql)
2. Paste and run `supabase/migrations/0001_init.sql`
3. Paste and run `supabase/seed.sql`

> ⚠️ Run the migration **before** the seed — seed data references tables created in the migration.

### 3. Install Flutter Dependencies

```bash
cd audience_pulse
flutter pub get
```

### 4. Run the App (Web)

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://yyrxgmkeyxfohururkfi.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

> 💡 The anon key is already set as the default value in `supabase_client.dart`, so you can also just run `flutter run -d chrome` for development.

### 5. Run on Android

```bash
flutter run -d android \
  --dart-define=SUPABASE_URL=https://yyrxgmkeyxfohururkfi.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

---

## Project Structure

```
audience_pulse/
├── lib/
│   ├── core/
│   │   ├── constants/        # App constants, sentiment colors, route paths
│   │   ├── supabase/         # Supabase client singleton (reads from --dart-define)
│   │   ├── theme/            # Dark theme (Linear/Notion aesthetic, Inter font)
│   │   └── utils/            # Date formatting, number compaction
│   ├── models/               # Dart data models (Post, Author, SentimentScore, etc.)
│   ├── features/
│   │   ├── auth/             # Login screen (email + Google OAuth)
│   │   ├── dashboard/        # 4-panel analytics dashboard
│   │   │   ├── providers/    # Riverpod providers (StreamProvider, FutureProvider)
│   │   │   └── widgets/      # SentimentChartPanel, TrendsPanel, NetworkGraphPanel, DemographicsPanel
│   │   └── ingestion_status/ # Pipeline status screen
│   ├── router/               # GoRouter with auth guard
│   └── services/
│       ├── supabase_service.dart  # All DB reads, typed per data type
│       └── ml_stub_service.dart   # Stub signatures for NLP/ML (TODO)
├── supabase/
│   ├── migrations/0001_init.sql   # Schema: 7 tables, RLS policies, indexes
│   ├── seed.sql                    # ~50 rows of mock data (48-hour window)
│   └── functions/
│       ├── ingest_x/index.ts       # X API ingestion stub (TODO)
│       └── ingest_telegram/index.ts # Telegram ingestion stub (TODO)
└── README.md
```

---

## Supabase Schema

| Table | Purpose |
|-------|---------|
| `platforms` | X, Telegram, Instagram, etc. with live/coming_soon status |
| `authors` | Social media accounts with inferred demographics |
| `posts` | Individual posts/messages |
| `sentiment_scores` | ML-computed emotion labels per post |
| `trends` | Rising keywords ranked by growth rate |
| `network_edges` | Author interaction graph (replies, retweets, forwards) |
| `demographic_summaries` | Aggregated audience demographics per platform |

**RLS Policy:** Authenticated users can READ all tables. Service role (edge functions) bypasses RLS for writes.

**Realtime:** `posts` and `sentiment_scores` tables are added to `supabase_realtime` publication so the dashboard updates live.

---

## Auth

- **Email/password** via Supabase Auth
- **Google OAuth** — requires Google Cloud Console setup:
  1. Create OAuth 2.0 credentials at [console.cloud.google.com](https://console.cloud.google.com)
  2. Add `https://yyrxgmkeyxfohururkfi.supabase.co/auth/v1/callback` as an authorized redirect URI
  3. Enable Google provider in [Supabase Auth settings](https://supabase.com/dashboard/project/yyrxgmkeyxfohururkfi/auth/providers)

---

## State Management

Uses **Riverpod** `FutureProvider` and `StreamProvider` (no code generation needed):

- `sentimentTimelineProvider` — `FutureProvider` (initial load with joined post data)
- `sentimentStreamProvider` — `StreamProvider` (Realtime updates via Supabase stream)
- `topTrendsProvider` — `FutureProvider`
- `networkGraphProvider` — `FutureProvider`
- `demographicsProvider` — `FutureProvider`
- `platformFilterProvider` — `StateProvider` (drives all panels simultaneously)

---

## 🔭 Next Steps (TODOs for Sprint 2)

### 1. Real X (Twitter) Ingestion
**File:** `supabase/functions/ingest_x/index.ts`
- [ ] Get X API v2 Bearer Token and store in Supabase Vault
- [ ] Implement `GET /2/tweets/search/recent` with keyword/handle filters
- [ ] Upsert authors, insert posts into DB
- [ ] Schedule via `pg_cron` every 15 minutes

### 2. Real Telegram Ingestion
**File:** `supabase/functions/ingest_telegram/index.ts`
- [ ] Create a Telegram Bot via @BotFather
- [ ] Connect to target channels via GramJS (MTProto API)
- [ ] Implement webhook or polling loop
- [ ] Schedule via `pg_cron` every 5 minutes

### 3. Real NLP / Sentiment Classification
**File:** `lib/services/ml_stub_service.dart`
- [ ] Implement `classifySentiment()` — options:
  - Google Cloud Natural Language API (easiest)
  - HuggingFace `cardiffnlp/twitter-roberta-base-sentiment`
  - Fine-tuned multilingual BERT for Hindi-English code-switching
- [ ] Implement `extractKeywords()` for trend detection
- [ ] Implement `inferDemographics()` for demographic profiling

### 4. Community Detection (Network Graph)
- [ ] Add a Supabase Edge Function that runs Louvain community detection on `network_edges`
- [ ] Color-code network graph nodes by community in the UI

### 5. Instagram / Facebook / Reddit / YouTube
- [ ] Add to `platforms` table and implement ingestion Edge Functions
- [ ] Update ingestion status screen roadmap dates

---

## Team Notes

- **Keys:** Never commit API keys. Use `--dart-define` for Flutter, Supabase Vault for Edge Functions.
- **Extending the DB:** Add new columns/tables via `supabase/migrations/000N_name.sql` — never edit existing migration files.
- **Adding a new dashboard panel:** Create a widget in `lib/features/dashboard/widgets/`, wrap it in `PanelCard`, add a Riverpod provider in `dashboard_providers.dart`.
- **Running `flutter analyze`** before every commit is strongly recommended.

---

*Built for Smart India Hackathon 2026 — AudiencePulse Team*
