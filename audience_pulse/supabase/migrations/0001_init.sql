-- ============================================================
-- AudiencePulse — Supabase Migration 0001
-- AI-Driven Social Media Audience Intelligence Platform
-- Run this in: Supabase Dashboard > SQL Editor
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE platform_status AS ENUM ('live', 'coming_soon');

CREATE TYPE sentiment_label AS ENUM (
  'positive', 'negative', 'neutral',
  'sarcastic', 'anxious', 'supportive', 'against'
);

CREATE TYPE interaction_type AS ENUM (
  'reply', 'retweet', 'mention', 'forward'
);

-- ============================================================
-- TABLE: platforms
-- ============================================================

CREATE TABLE IF NOT EXISTS platforms (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT NOT NULL UNIQUE,
  status        platform_status NOT NULL DEFAULT 'coming_soon',
  last_synced_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: authors
-- ============================================================

CREATE TABLE IF NOT EXISTS authors (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  platform_id         UUID NOT NULL REFERENCES platforms(id) ON DELETE CASCADE,
  handle              TEXT NOT NULL,
  display_name        TEXT,
  bio_text            TEXT,
  inferred_language   TEXT,
  inferred_region     TEXT,
  inferred_age_bracket TEXT,         -- e.g. '18-24', '25-34', '35-44', '45+'
  follower_count      INTEGER NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(platform_id, handle)
);

CREATE INDEX IF NOT EXISTS idx_authors_platform_id ON authors(platform_id);
CREATE INDEX IF NOT EXISTS idx_authors_created_at  ON authors(created_at);

-- ============================================================
-- TABLE: posts
-- ============================================================

CREATE TABLE IF NOT EXISTS posts (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  platform_id          UUID NOT NULL REFERENCES platforms(id) ON DELETE CASCADE,
  author_id            UUID NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
  content_text         TEXT NOT NULL,
  posted_at            TIMESTAMPTZ NOT NULL,
  raw_engagement_count INTEGER NOT NULL DEFAULT 0,
  url                  TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_posts_platform_id ON posts(platform_id);
CREATE INDEX IF NOT EXISTS idx_posts_author_id   ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_posted_at   ON posts(posted_at DESC);

-- ============================================================
-- TABLE: sentiment_scores
-- ============================================================

CREATE TABLE IF NOT EXISTS sentiment_scores (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id         UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  sentiment_label sentiment_label NOT NULL,
  confidence      FLOAT NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
  scored_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sentiment_post_id   ON sentiment_scores(post_id);
CREATE INDEX IF NOT EXISTS idx_sentiment_scored_at ON sentiment_scores(scored_at DESC);
CREATE INDEX IF NOT EXISTS idx_sentiment_label     ON sentiment_scores(sentiment_label);

-- ============================================================
-- TABLE: trends
-- ============================================================

CREATE TABLE IF NOT EXISTS trends (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  keyword_or_topic  TEXT NOT NULL,
  platform_id       UUID REFERENCES platforms(id) ON DELETE SET NULL,
  mention_count     INTEGER NOT NULL DEFAULT 0,
  growth_rate       FLOAT NOT NULL DEFAULT 0.0,  -- percentage e.g. 45.2 means +45.2%
  window_start      TIMESTAMPTZ NOT NULL,
  window_end        TIMESTAMPTZ NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trends_platform_id  ON trends(platform_id);
CREATE INDEX IF NOT EXISTS idx_trends_window_end   ON trends(window_end DESC);
CREATE INDEX IF NOT EXISTS idx_trends_growth_rate  ON trends(growth_rate DESC);

-- ============================================================
-- TABLE: network_edges
-- ============================================================

CREATE TABLE IF NOT EXISTS network_edges (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_author_id UUID NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
  target_author_id UUID NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
  interaction_type interaction_type NOT NULL,
  weight           INTEGER NOT NULL DEFAULT 1,
  occurred_at      TIMESTAMPTZ NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_edges_source      ON network_edges(source_author_id);
CREATE INDEX IF NOT EXISTS idx_edges_target      ON network_edges(target_author_id);
CREATE INDEX IF NOT EXISTS idx_edges_occurred_at ON network_edges(occurred_at DESC);

-- ============================================================
-- TABLE: demographic_summaries
-- ============================================================

CREATE TABLE IF NOT EXISTS demographic_summaries (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  platform_id          UUID REFERENCES platforms(id) ON DELETE SET NULL,
  age_bracket          TEXT NOT NULL,      -- '18-24', '25-34', etc.
  region               TEXT NOT NULL,
  language             TEXT NOT NULL,
  professional_interest TEXT,
  aggregate_count      INTEGER NOT NULL DEFAULT 0,
  computed_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_demo_platform_id ON demographic_summaries(platform_id);
CREATE INDEX IF NOT EXISTS idx_demo_computed_at ON demographic_summaries(computed_at DESC);

-- ============================================================
-- ROW-LEVEL SECURITY (RLS)
-- Authenticated users: READ all
-- Service role (edge functions): WRITE via bypass
-- ============================================================

ALTER TABLE platforms              ENABLE ROW LEVEL SECURITY;
ALTER TABLE authors                ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE sentiment_scores       ENABLE ROW LEVEL SECURITY;
ALTER TABLE trends                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE network_edges          ENABLE ROW LEVEL SECURITY;
ALTER TABLE demographic_summaries  ENABLE ROW LEVEL SECURITY;

-- Authenticated users can SELECT everything
CREATE POLICY "auth_read_platforms"             ON platforms             FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read_authors"               ON authors               FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read_posts"                 ON posts                 FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read_sentiment_scores"      ON sentiment_scores      FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read_trends"                ON trends                FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read_network_edges"         ON network_edges         FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read_demographic_summaries" ON demographic_summaries FOR SELECT TO authenticated USING (true);

-- Service role bypasses RLS automatically — no extra policy needed.
-- For anon access during development, also allow anon to read (comment out for production):
CREATE POLICY "anon_read_platforms"             ON platforms             FOR SELECT TO anon USING (true);
CREATE POLICY "anon_read_authors"               ON authors               FOR SELECT TO anon USING (true);
CREATE POLICY "anon_read_posts"                 ON posts                 FOR SELECT TO anon USING (true);
CREATE POLICY "anon_read_sentiment_scores"      ON sentiment_scores      FOR SELECT TO anon USING (true);
CREATE POLICY "anon_read_trends"                ON trends                FOR SELECT TO anon USING (true);
CREATE POLICY "anon_read_network_edges"         ON network_edges         FOR SELECT TO anon USING (true);
CREATE POLICY "anon_read_demographic_summaries" ON demographic_summaries FOR SELECT TO anon USING (true);

-- Enable Realtime on the two live-updating tables
ALTER PUBLICATION supabase_realtime ADD TABLE posts;
ALTER PUBLICATION supabase_realtime ADD TABLE sentiment_scores;
