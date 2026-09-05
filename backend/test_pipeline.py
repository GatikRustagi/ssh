"""
test_pipeline.py — Quick sanity-check script for Team Member 4.

Injects realistic FAKE data directly into Supabase to simulate what the
real ingestion + trend/network scripts would produce.

Use this to:
  1. Verify your Supabase credentials work.
  2. Watch the Flutter dashboard come alive without needing real Twitter/Telegram APIs.
  3. Demo the Top Trends and Influence Network panels to judges.

Run:  python test_pipeline.py
"""

import os
import sys
import random
import logging
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import load_env, get_supabase_client, PLATFORM_ID_TWITTER, PLATFORM_ID_TELEGRAM

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger(__name__)

# ── Sample data pools ─────────────────────────────────────────────────────────
SAMPLE_TWEETS = [
    ("@test_techblog",  "TechBlog India",  "#IndiaAI is changing the future of healthcare! Amazing results from the pilot program. #AI #HealthTech", "en"),
    ("@test_devguy",    "Dev Sharma",      "Just attended the #SIH2026 finale. The innovation level was insane! 🚀 Proud of all the student teams.", "en"),
    ("@test_airesearch","AI Research Lab", "New paper: Constitutional AI improves alignment by 34%. RT @test_techblog for the PDF link. #AISafety", "en"),
    ("@test_cryptofan", "Crypto Fan",      "BTC and AI are converging. #Web3 + #IndiaAI = the next big wave. DYR 📈", "en"),
    ("@test_skeptic",   "Skeptic Sam",     "Hot take: most '#IndiaAI' startups are just reskinning OpenAI APIs. Where is the real R&D? 🤔", "en"),
    ("@test_policywatch","PolicyWatch",    "MEITY releases new #AIPolicy draft. Section 12 on data localisation is going to shake up #IndiaAI startups.", "en"),
    ("@test_startup",   "StartupWala",     "3 Indian #AIStartup companies just raised $50M in Series B. The ecosystem is maturing fast! #IndiaAI", "en"),
    ("@test_educator",  "EduTech India",   "AI literacy for rural students — we trained 1000+ kids this month. Technology must be inclusive! #DigitalIndia", "en"),
    ("@test_journalist","Tech Journalist", "BREAKING: Government announces ₹10,000 crore fund for #IndiaAI compute infrastructure. This is huge!", "en"),
    ("@test_engineer",  "ML Engineer",     "Fine-tuned LLaMA-3 on Indic languages dataset. Hindi + Tamil + Bengali. Open-sourcing next week! #IndiaAI #OpenSource", "en"),
]

SAMPLE_TG_POSTS = [
    ("@tg_test_indiatech",  "Indiatech News",    "🔥 Big update: India's sovereign AI compute cluster launches next month! 10,000 GPUs for researchers. #IndiaAI"),
    ("@tg_test_aiforum",    "AI Forum India",    "Paper of the day: Multi-agent debate improves Constitutional AI safety scores by 40%. #AISafety"),
    ("@tg_test_startupind", "Startup India TG",  "SEBI new circular: AI-driven robo-advisors must provide explainability by April 2027. #FinTech #IndiaAI"),
    ("@tg_test_cryptohive", "CryptoHive",        "BTC holding strong. AI trading bots now at 45% of volume. The future is algorithmic. #Crypto"),
    ("@tg_test_policy",     "Policy Radar",      "Draft Digital India Act 2026 — Section 47 on AI intermediary liability needs community feedback. #AIPolicy"),
]


def inject_test_data():
    load_env()
    supabase = get_supabase_client()

    log.info("Injecting test data into Supabase...")

    now = datetime.now(timezone.utc)
    author_ids: list[str] = []

    # ── 1. Upsert test Twitter authors and posts ──────────────────────────────
    log.info("  → Upserting %d Twitter authors + posts...", len(SAMPLE_TWEETS))
    for i, (handle, display_name, text, lang) in enumerate(SAMPLE_TWEETS):
        # Upsert author
        resp = (
            supabase.table("authors")
            .upsert(
                {
                    "platform_id":       PLATFORM_ID_TWITTER,
                    "handle":            handle,
                    "display_name":      display_name,
                    "bio_text":          f"Test account for AudiencePulse demo. {display_name}.",
                    "inferred_language": lang,
                    "follower_count":    random.randint(1000, 50000),
                },
                on_conflict="platform_id,handle",
            )
            .execute()
        )
        author_id = resp.data[0]["id"]
        author_ids.append(author_id)

        # Insert post with a timestamp spread over the last 90 minutes
        posted_at = now - timedelta(minutes=random.randint(5, 90))
        supabase.table("posts").insert({
            "platform_id":          PLATFORM_ID_TWITTER,
            "author_id":            author_id,
            "content_text":         text,
            "posted_at":            posted_at.isoformat(),
            "raw_engagement_count": random.randint(50, 5000),
            "url":                  f"https://x.com/{handle.lstrip('@')}/status/{random.randint(10**15, 10**16)}",
        }).execute()

    # ── 2. Upsert test Telegram authors and posts ─────────────────────────────
    log.info("  → Upserting %d Telegram channels + posts...", len(SAMPLE_TG_POSTS))
    tg_author_ids: list[str] = []
    for handle, display_name, text in SAMPLE_TG_POSTS:
        resp = (
            supabase.table("authors")
            .upsert(
                {
                    "platform_id":       PLATFORM_ID_TELEGRAM,
                    "handle":            handle,
                    "display_name":      display_name,
                    "bio_text":          f"Telegram channel: {display_name}",
                    "inferred_language": "en",
                    "follower_count":    random.randint(5000, 100000),
                },
                on_conflict="platform_id,handle",
            )
            .execute()
        )
        author_id = resp.data[0]["id"]
        tg_author_ids.append(author_id)

        posted_at = now - timedelta(minutes=random.randint(10, 60))
        supabase.table("posts").insert({
            "platform_id":          PLATFORM_ID_TELEGRAM,
            "author_id":            author_id,
            "content_text":         text,
            "posted_at":            posted_at.isoformat(),
            "raw_engagement_count": random.randint(100, 8000),
            "url":                  None,
        }).execute()

    # ── 3. Inject realistic trend rows ───────────────────────────────────────
    log.info("  → Inserting trend rows...")
    trends = [
        ("#IndiaAI",     PLATFORM_ID_TWITTER,  random.randint(50, 200),  random.uniform(80, 300)),
        ("#SIH2026",     PLATFORM_ID_TWITTER,  random.randint(30, 150),  random.uniform(200, 600)),
        ("#AISafety",    PLATFORM_ID_TWITTER,  random.randint(20, 100),  random.uniform(30, 120)),
        ("#AIStartup",   PLATFORM_ID_TWITTER,  random.randint(15, 80),   random.uniform(20, 90)),
        ("#DigitalIndia",PLATFORM_ID_TWITTER,  random.randint(10, 60),   random.uniform(10, 60)),
        ("#OpenSource",  PLATFORM_ID_TWITTER,  random.randint(8, 40),    random.uniform(5, 40)),
        ("#AIPolicy",    PLATFORM_ID_TELEGRAM, random.randint(12, 55),   random.uniform(40, 150)),
        ("#FinTech",     PLATFORM_ID_TELEGRAM, random.randint(10, 45),   random.uniform(25, 100)),
    ]

    win_start = now - timedelta(hours=1)
    win_end   = now

    for keyword, platform_id, count, growth in trends:
        supabase.table("trends").insert({
            "keyword_or_topic": keyword,
            "platform_id":      platform_id,
            "mention_count":    count,
            "growth_rate":      round(growth, 1),
            "window_start":     win_start.isoformat(),
            "window_end":       win_end.isoformat(),
        }).execute()

    # ── 4. Inject network edges between the test authors ─────────────────────
    log.info("  → Inserting network edges...")
    interaction_types = ["reply", "retweet", "mention"]

    # Create a web of connections between Twitter test authors
    for i in range(min(8, len(author_ids))):
        for j in range(i + 1, min(len(author_ids), i + 3)):
            interaction = random.choice(interaction_types)
            occurred_at = now - timedelta(minutes=random.randint(5, 60))
            supabase.table("network_edges").insert({
                "source_author_id": author_ids[i],
                "target_author_id": author_ids[j],
                "interaction_type": interaction,
                "weight":           random.randint(1, 5),
                "occurred_at":      occurred_at.isoformat(),
            }).execute()

    # Telegram forwarding cluster
    for i in range(len(tg_author_ids) - 1):
        occurred_at = now - timedelta(minutes=random.randint(5, 45))
        supabase.table("network_edges").insert({
            "source_author_id": tg_author_ids[i + 1],
            "target_author_id": tg_author_ids[0],
            "interaction_type": "forward",
            "weight":           random.randint(2, 6),
            "occurred_at":      occurred_at.isoformat(),
        }).execute()

    log.info("✅ Test data injection complete!")
    log.info("   Check your Flutter dashboard — the charts should update within seconds.")


if __name__ == "__main__":
    inject_test_data()
