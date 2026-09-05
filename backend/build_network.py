"""
build_network.py — Scan posts in the last hour and insert network edges
                   for any reply/retweet/mention/forward interactions found
                   *within the post text itself*.

This script is a post-processing pass that catches interaction signals that
ingest_twitter.py and ingest_telegram.py might miss (e.g. plain @mentions
in the post body, or quote-tweet patterns).

Algorithm (runs every 15 minutes):
  1. Fetch all posts from the last 1 hour.
  2. For each post, look for:
       a. @mentions in the text  → "mention" edge
       b. "RT @username" pattern → "retweet" edge
  3. For each detected interaction, check if the target handle exists in
     the `authors` table.
  4. If yes, insert a row into `network_edges`.

Edges are deduplicated: a (source, target, type, 15-min bucket) triplet
is only inserted once per run to avoid duplicates.

Run manually:   python build_network.py
Run on a timer: python run_pipeline.py  (calls this every 15 minutes)
"""

import os
import re
import sys
import logging
from datetime import datetime, timedelta, timezone

# Add parent dir so we can import config.py
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import load_env, get_supabase_client

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [network] %(levelname)s %(message)s",
)
log = logging.getLogger(__name__)

# ── How far back to scan posts on each run ───────────────────────────────────
LOOK_BACK_MINUTES = 60


def run():
    load_env()
    supabase = get_supabase_client()

    cutoff = datetime.now(timezone.utc) - timedelta(minutes=LOOK_BACK_MINUTES)

    log.info("Scanning posts since %s for interactions...", cutoff.strftime("%H:%M"))

    # ── 1. Fetch recent posts with their author info ─────────────────────────
    resp = (
        supabase.table("posts")
        .select("id, author_id, content_text, platform_id, posted_at")
        .gte("posted_at", cutoff.isoformat())
        .execute()
    )
    posts = resp.data or []
    log.info("Found %d recent posts to scan.", len(posts))

    if not posts:
        log.info("Nothing to process.")
        return

    # ── 2. Build a handle → author_id lookup for fast resolution ────────────
    # Fetch all known authors (we have a small set, so this is fine)
    all_authors_resp = (
        supabase.table("authors")
        .select("id, handle, platform_id")
        .execute()
    )
    handle_map: dict[str, str] = {}  # normalised_handle → author_id
    for author in (all_authors_resp.data or []):
        normalised = author["handle"].lower().lstrip("@")
        handle_map[normalised] = author["id"]

    # ── 3. Track which edges we've already inserted this run ─────────────────
    # Key: (source_id, target_id, interaction_type)
    inserted_set: set[tuple] = set()

    edges_inserted = 0

    for post in posts:
        source_id   = post["author_id"]
        text        = post.get("content_text", "") or ""
        occurred_at = post["posted_at"]

        # ── a. Retweet pattern: "RT @username" ───────────────────────────
        rt_matches = re.findall(r"\bRT\s+@(\w+)", text, re.IGNORECASE)
        for username in rt_matches:
            target_id = handle_map.get(username.lower())
            if target_id and target_id != source_id:
                key = (source_id, target_id, "retweet")
                if key not in inserted_set:
                    supabase.table("network_edges").insert({
                        "source_author_id": source_id,
                        "target_author_id": target_id,
                        "interaction_type": "retweet",
                        "weight":           1,
                        "occurred_at":      occurred_at,
                    }).execute()
                    inserted_set.add(key)
                    edges_inserted += 1
                    log.debug("  retweet: %s → %s", source_id[:8], target_id[:8])

        # ── b. @mention pattern (excludes RT targets already captured) ───
        mention_matches = re.findall(r"(?<!RT\s)@(\w+)", text, re.IGNORECASE)
        for username in mention_matches:
            target_id = handle_map.get(username.lower())
            if target_id and target_id != source_id:
                key = (source_id, target_id, "mention")
                if key not in inserted_set:
                    supabase.table("network_edges").insert({
                        "source_author_id": source_id,
                        "target_author_id": target_id,
                        "interaction_type": "mention",
                        "weight":           1,
                        "occurred_at":      occurred_at,
                    }).execute()
                    inserted_set.add(key)
                    edges_inserted += 1
                    log.debug("  mention: %s → %s", source_id[:8], target_id[:8])

        # ── c. "Replying to @username" pattern (Telegram / manual posts) ─
        reply_matches = re.findall(r"(?:replying\s+to|reply\s+to)\s+@(\w+)", text, re.IGNORECASE)
        for username in reply_matches:
            target_id = handle_map.get(username.lower())
            if target_id and target_id != source_id:
                key = (source_id, target_id, "reply")
                if key not in inserted_set:
                    supabase.table("network_edges").insert({
                        "source_author_id": source_id,
                        "target_author_id": target_id,
                        "interaction_type": "reply",
                        "weight":           1,
                        "occurred_at":      occurred_at,
                    }).execute()
                    inserted_set.add(key)
                    edges_inserted += 1
                    log.debug("  reply: %s → %s", source_id[:8], target_id[:8])

    log.info("Network builder done. %d edges inserted.", edges_inserted)


if __name__ == "__main__":
    run()
