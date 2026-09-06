"""
build_trends.py — Extract trending hashtags/keywords from recent posts
                  and write them into the `trends` Supabase table.

Algorithm (runs every hour):
  CURRENT WINDOW  = posts from the last 1 hour
  PREVIOUS WINDOW = posts from the hour before that (1h–2h ago)

  For each window:
    1. Extract all hashtags (words starting with #).
    2. Extract high-frequency plain keywords (stop-word filtered).
    3. Count occurrences per keyword.

  Growth rate = ((current_count - prev_count) / max(prev_count, 1)) * 100

  Rows inserted into `trends` with window_start / window_end timestamps.

Run manually:   python build_trends.py
Run on a timer: python run_pipeline.py  (calls this every 60 minutes)
"""

import os
import re
import sys
import logging
from collections import Counter
from datetime import datetime, timedelta, timezone

# Add parent dir so we can import config.py
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import load_env, get_supabase_client

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [trends] %(levelname)s %(message)s",
)
log = logging.getLogger(__name__)

# ── Tuning knobs ─────────────────────────────────────────────────────────────
TOP_N_TRENDS     = 10    # how many trends to write per run
MIN_MENTIONS     = 2     # ignore keywords mentioned fewer than this many times
WINDOW_HOURS     = 48    # expanded to 48 hours for hackathon testing

# Words to ignore when extracting plain keywords
STOP_WORDS = {
    "the", "a", "an", "and", "or", "is", "in", "to", "of", "for",
    "this", "that", "it", "on", "at", "by", "with", "from", "are",
    "was", "be", "as", "we", "i", "you", "not", "have", "has",
    "will", "our", "your", "their", "my", "but", "if", "so",
    "now", "just", "also", "here", "there", "all", "new", "more",
    "can", "get", "its", "been", "they", "he", "she", "what",
    "how", "why", "when", "which", "who", "do", "did", "up",
    "out", "re", "s", "t", "ve", "d", "ll", "m",
    "rt", "via", "amp", "https", "http", "co", "www",
}


def run():
    load_env()
    supabase = get_supabase_client()

    now      = datetime.now(timezone.utc)
    win_end  = now
    win_start = now - timedelta(hours=WINDOW_HOURS)
    prev_start = win_start - timedelta(hours=WINDOW_HOURS)

    log.info(
        "Building trends | current: %s → %s | previous: %s → %s",
        win_start.strftime("%H:%M"),
        win_end.strftime("%H:%M"),
        prev_start.strftime("%H:%M"),
        win_start.strftime("%H:%M"),
    )

    # ── Fetch posts in the CURRENT window ───────────────────────────────────
    current_posts = _fetch_posts(supabase, win_start, win_end)
    log.info("Current window: %d posts", len(current_posts))

    # ── Fetch posts in the PREVIOUS window ──────────────────────────────────
    previous_posts = _fetch_posts(supabase, prev_start, win_start)
    log.info("Previous window: %d posts", len(previous_posts))

    # ── Count keywords in each window ────────────────────────────────────────
    current_counts  = _count_keywords(current_posts)
    previous_counts = _count_keywords(previous_posts)

    if not current_counts:
        log.info("No keywords found in current window — nothing to write.")
        return

    # ── Compute growth rates ─────────────────────────────────────────────────
    # Sort by current count descending, take top N
    top_keywords = current_counts.most_common(TOP_N_TRENDS)

    rows_inserted = 0
    for keyword, count in top_keywords:
        if count < MIN_MENTIONS:
            continue

        prev_count  = previous_counts.get(keyword, 0)
        growth_rate = ((count - prev_count) / max(prev_count, 1)) * 100.0

        # Which platform_id does this keyword belong to?
        # We detect by checking which posts mention the keyword most.
        platform_id = _dominant_platform(supabase, keyword, win_start, win_end)

        trend_row = {
            "keyword_or_topic": keyword,
            "platform_id":      platform_id,
            "mention_count":    count,
            "growth_rate":      round(growth_rate, 2),
            "window_start":     win_start.isoformat(),
            "window_end":       win_end.isoformat(),
        }

        supabase.table("trends").insert(trend_row).execute()
        rows_inserted += 1
        log.info(
            "  %-25s  count=%-4d  prev=%-4d  growth=%+.1f%%",
            keyword, count, prev_count, growth_rate,
        )

    log.info("Trends done. %d rows inserted.", rows_inserted)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _fetch_posts(supabase, start: datetime, end: datetime) -> list[dict]:
    """Return all posts with their platform_id in the [start, end] window."""
    resp = (
        supabase.table("posts")
        .select("id, content_text, platform_id, posted_at")
        .gte("posted_at", start.isoformat())
        .lt("posted_at", end.isoformat())
        .execute()
    )
    return resp.data or []


def _count_keywords(posts: list[dict]) -> Counter:
    """
    Extract hashtags and meaningful plain words from a list of post dicts.
    Returns a Counter: keyword → total mention count.
    """
    counter: Counter = Counter()

    for post in posts:
        text = post.get("content_text", "") or ""

        # 1. Extract hashtags (preserve the # sign, lowercased)
        hashtags = re.findall(r"#(\w+)", text)
        for ht in hashtags:
            counter[f"#{ht.lower()}"] += 1

        # 2. Extract plain words (3+ chars, no digits-only, not a stop word)
        words = re.findall(r"\b[a-zA-Z]{3,}\b", text)
        for w in words:
            w_lower = w.lower()
            if w_lower not in STOP_WORDS:
                counter[w_lower] += 1

    return counter


def _dominant_platform(supabase, keyword: str, start: datetime, end: datetime) -> str | None:
    """
    Return the platform_id whose posts mention `keyword` the most.
    Falls back to None if we can't determine.
    """
    resp = (
        supabase.table("posts")
        .select("platform_id")
        .ilike("content_text", f"%{keyword}%")
        .gte("posted_at", start.isoformat())
        .lt("posted_at", end.isoformat())
        .execute()
    )
    if not resp.data:
        return None

    platform_counts: Counter = Counter()
    for row in resp.data:
        pid = row.get("platform_id")
        if pid:
            platform_counts[pid] += 1

    return platform_counts.most_common(1)[0][0] if platform_counts else None


if __name__ == "__main__":
    run()
