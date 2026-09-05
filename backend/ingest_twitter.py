"""
ingest_twitter.py — Fetch recent tweets and store them in Supabase.

What this does:
  1. Calls Twitter v2 "recent search" API using your TWITTER_QUERY.
  2. For each tweet, upserts the author into the `authors` table.
  3. Upserts the tweet into the `posts` table.
  4. Detects reply/retweet/mention from tweet metadata and inserts a row
     into `network_edges` if an interaction is found.

Run manually:   python ingest_twitter.py
Run on a timer: python run_pipeline.py   (calls this every 15 minutes)
"""

import os
import sys
import uuid
import logging
from datetime import datetime, timezone

import tweepy

# Add parent dir so we can import config.py
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import load_env, get_supabase_client, PLATFORM_ID_TWITTER

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [twitter] %(levelname)s %(message)s",
)
log = logging.getLogger(__name__)

# ── How many tweets to fetch per run (max 100 for free tier) ────────────────
MAX_RESULTS = 100


def run():
    load_env()
    supabase = get_supabase_client()
    bearer   = os.environ["TWITTER_BEARER_TOKEN"]
    query    = os.environ.get(
        "TWITTER_QUERY",
        "#IndiaAI OR #SIH2026 OR #AIStartup OR #DigitalIndia -is:retweet lang:en",
    )

    if not bearer or bearer == "your_twitter_bearer_token_here":
        log.error("TWITTER_BEARER_TOKEN not set in .env — skipping Twitter ingest.")
        return

    client = tweepy.Client(bearer_token=bearer, wait_on_rate_limit=True)

    log.info("Searching Twitter for: %s", query)

    # ── Fetch tweets ─────────────────────────────────────────────────────────
    try:
        response = client.search_recent_tweets(
            query=query,
            max_results=MAX_RESULTS,
            tweet_fields=[
                "created_at", "author_id", "text",
                "referenced_tweets", "entities",
                "public_metrics", "in_reply_to_user_id",
            ],
            user_fields=[
                "id", "username", "name",
                "description", "public_metrics",
                "location",
            ],
            expansions=["author_id", "referenced_tweets.id"],
        )
    except tweepy.TweepyException as exc:
        log.error("Twitter API error: %s", exc)
        return

    if not response.data:
        log.info("No tweets returned for this query.")
        return

    # Build a lookup: twitter_user_id → user object
    users_by_id: dict = {}
    if response.includes and "users" in response.includes:
        for u in response.includes["users"]:
            users_by_id[u.id] = u

    tweets_processed = 0
    edges_inserted   = 0

    for tweet in response.data:
        author_tw = users_by_id.get(tweet.author_id)
        if not author_tw:
            continue

        # ── 1. Upsert author ──────────────────────────────────────────────
        follower_count = 0
        if author_tw.public_metrics:
            follower_count = author_tw.public_metrics.get("followers_count", 0)

        author_row = {
            "platform_id":   PLATFORM_ID_TWITTER,
            "handle":        f"@{author_tw.username}",
            "display_name":  author_tw.name,
            "bio_text":      author_tw.description or "",
            "inferred_language": _detect_lang(tweet.text),
            "follower_count": follower_count,
        }

        # upsert by (platform_id, handle) — the unique constraint
        resp_author = (
            supabase.table("authors")
            .upsert(author_row, on_conflict="platform_id,handle")
            .execute()
        )
        author_db_id = resp_author.data[0]["id"]

        # ── 2. Upsert post ────────────────────────────────────────────────
        posted_at = tweet.created_at or datetime.now(timezone.utc)
        engagement = 0
        if tweet.public_metrics:
            m = tweet.public_metrics
            engagement = (
                m.get("like_count", 0)
                + m.get("retweet_count", 0)
                + m.get("reply_count", 0)
            )

        tweet_url = (
            f"https://x.com/{author_tw.username}/status/{tweet.id}"
        )

        post_row = {
            "platform_id":          PLATFORM_ID_TWITTER,
            "author_id":            author_db_id,
            "content_text":         tweet.text,
            "posted_at":            posted_at.isoformat(),
            "raw_engagement_count": engagement,
            "url":                  tweet_url,
        }

        resp_post = supabase.table("posts").insert(post_row).execute()
        post_db_id = resp_post.data[0]["id"]
        tweets_processed += 1

        # ── 3. Detect & insert network edges ──────────────────────────────
        if tweet.referenced_tweets:
            for ref in tweet.referenced_tweets:
                interaction = _ref_type_to_interaction(ref.type)
                if interaction is None:
                    continue

                # We only create an edge if we know the target author.
                # The target is the original tweet's author — we'd need to
                # look it up; for now we store with source only and skip
                # if the target isn't in our DB. A fuller implementation
                # would fetch the referenced tweet's author_id and resolve it.
                #
                # For the demo we create a self-referencing edge stub so the
                # record lands in the DB and the graph renders relationships.
                edge_row = {
                    "source_author_id": author_db_id,
                    "target_author_id": author_db_id,   # updated below if resolvable
                    "interaction_type": interaction,
                    "weight":           1,
                    "occurred_at":      posted_at.isoformat(),
                }

                # Try to resolve the target author from the in_reply_to field
                if interaction == "reply" and tweet.in_reply_to_user_id:
                    target_handle_data = (
                        supabase.table("authors")
                        .select("id")
                        .eq("platform_id", PLATFORM_ID_TWITTER)
                        .ilike("handle", f"%{tweet.in_reply_to_user_id}%")
                        .limit(1)
                        .execute()
                    )
                    if target_handle_data.data:
                        edge_row["target_author_id"] = target_handle_data.data[0]["id"]

                # Don't insert self-loops
                if edge_row["source_author_id"] != edge_row["target_author_id"]:
                    supabase.table("network_edges").insert(edge_row).execute()
                    edges_inserted += 1

        # ── 4. Handle @mentions in text ───────────────────────────────────
        if tweet.entities and "mentions" in tweet.entities:
            for mention in tweet.entities["mentions"]:
                mentioned_handle = f"@{mention['username']}"
                target_data = (
                    supabase.table("authors")
                    .select("id")
                    .eq("platform_id", PLATFORM_ID_TWITTER)
                    .eq("handle", mentioned_handle)
                    .limit(1)
                    .execute()
                )
                if target_data.data:
                    target_id = target_data.data[0]["id"]
                    if target_id != author_db_id:
                        supabase.table("network_edges").insert({
                            "source_author_id": author_db_id,
                            "target_author_id": target_id,
                            "interaction_type": "mention",
                            "weight":           1,
                            "occurred_at":      posted_at.isoformat(),
                        }).execute()
                        edges_inserted += 1

    log.info(
        "Twitter ingest done. tweets=%d  edges=%d",
        tweets_processed, edges_inserted,
    )


# ── Helpers ──────────────────────────────────────────────────────────────────

def _ref_type_to_interaction(ref_type: str) -> str | None:
    """Map a Twitter referenced_tweet type to our interaction_type enum."""
    mapping = {
        "replied_to":  "reply",
        "retweeted":   "retweet",
        "quoted":      "mention",
    }
    return mapping.get(ref_type)


def _detect_lang(text: str) -> str:
    """Very lightweight language guess based on script presence."""
    # Devanagari range (Hindi)
    if any("\u0900" <= ch <= "\u097F" for ch in text):
        return "hi"
    return "en"


if __name__ == "__main__":
    run()
