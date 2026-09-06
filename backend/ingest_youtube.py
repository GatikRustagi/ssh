"""
ingest_youtube.py — Search YouTube for videos matching your queries, fetch
                    their comments, and store everything in Supabase.

What this does:
  1. Uses the YouTube Data API v3 (free — 10,000 units/day).
  2. Searches for recent videos matching each query in YOUTUBE_QUERIES.
  3. For each video, upserts the channel as an author in `authors`.
  4. Inserts the video (title + description) as a post in `posts`.
  5. Fetches top-level comments and upserts each commenter as an author.
  6. Inserts each comment as a post and creates a network edge
     (commenter → channel = "reply" interaction).
  7. Detects @mentions inside comment text → additional network edges.

Run manually:   python ingest_youtube.py
Run on a timer: python run_pipeline.py   (calls this every 15 minutes)

Getting a free API key (takes ~2 minutes):
  1. Go to https://console.cloud.google.com
  2. Select your project (or create a new one)
  3. Go to "APIs & Services" → "Library"
  4. Search "YouTube Data API v3" → Enable it
  5. Go to "APIs & Services" → "Credentials" → "Create Credentials" → "API Key"
  6. Copy the key into backend/.env as YOUTUBE_API_KEY
"""

import os
import sys
import re
import logging
from datetime import datetime, timezone

# Add parent dir so we can import config.py
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import load_env, get_supabase_client, PLATFORM_ID_YOUTUBE

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [youtube] %(levelname)s %(message)s",
)
log = logging.getLogger(__name__)

# ── How many videos to fetch per search query ────────────────────────────────
MAX_VIDEOS_PER_QUERY = 10


def run():
    load_env()

    api_key = os.environ.get("YOUTUBE_API_KEY", "")
    queries = [
        q.strip()
        for q in os.environ.get("YOUTUBE_QUERIES", "").split(",")
        if q.strip()
    ]
    max_comments = int(os.environ.get("YOUTUBE_MAX_COMMENTS", "100"))

    if not api_key or api_key == "your_youtube_api_key_here":
        log.error("YOUTUBE_API_KEY not set in .env — skipping YouTube ingest.")
        return
    if not queries:
        log.error("YOUTUBE_QUERIES is empty in .env — skipping YouTube ingest.")
        return

    try:
        from googleapiclient.discovery import build as yt_build
        from googleapiclient.errors import HttpError
    except ImportError:
        log.error(
            "google-api-python-client is not installed. "
            "Run: pip install google-api-python-client"
        )
        return

    supabase = get_supabase_client()
    youtube  = yt_build("youtube", "v3", developerKey=api_key)

    log.info("YouTube client ready. Queries: %s", queries)

    videos_processed  = 0
    comments_processed = 0
    edges_inserted    = 0

    for query in queries:
        log.info("Searching YouTube for: %s", query)

        # ── Step 1: Search for videos ─────────────────────────────────────
        try:
            search_resp = youtube.search().list(
                q=query,
                part="id,snippet",
                type="video",
                maxResults=MAX_VIDEOS_PER_QUERY,
                order="date",               # most recent first
                relevanceLanguage="en",
            ).execute()
        except HttpError as exc:
            log.error("YouTube search API error for '%s': %s", query, exc)
            continue

        video_items = search_resp.get("items", [])
        if not video_items:
            log.info("No videos found for query: %s", query)
            continue

        video_ids = [item["id"]["videoId"] for item in video_items]

        # ── Step 2: Get full video statistics (views, likes, comments) ────
        try:
            stats_resp = youtube.videos().list(
                id=",".join(video_ids),
                part="snippet,statistics",
            ).execute()
        except HttpError as exc:
            log.error("YouTube videos.list error: %s", exc)
            continue

        stats_by_id = {
            item["id"]: item for item in stats_resp.get("items", [])
        }

        for video_item in video_items:
            video_id = video_item["id"]["videoId"]
            snippet  = video_item.get("snippet", {})
            stats    = stats_by_id.get(video_id, {})
            full_snippet = stats.get("snippet", snippet)
            statistics   = stats.get("statistics", {})

            channel_id    = full_snippet.get("channelId", "")
            channel_title = full_snippet.get("channelTitle", "unknown")
            video_title   = full_snippet.get("title", "")
            video_desc    = full_snippet.get("description", "")
            published_at  = full_snippet.get("publishedAt", "")

            try:
                posted_at = datetime.fromisoformat(
                    published_at.replace("Z", "+00:00")
                )
            except Exception:
                posted_at = datetime.now(timezone.utc)

            engagement = (
                int(statistics.get("viewCount",    0))
                + int(statistics.get("likeCount",  0))
                + int(statistics.get("commentCount", 0))
            )

            video_url = f"https://www.youtube.com/watch?v={video_id}"

            # ── 3. Upsert channel as author ───────────────────────────────
            channel_handle = f"@{channel_id}"
            resp_author = (
                supabase.table("authors")
                .upsert(
                    {
                        "platform_id":       PLATFORM_ID_YOUTUBE,
                        "handle":            channel_handle,
                        "display_name":      channel_title,
                        "bio_text":          "",
                        "inferred_language": "en",
                        "follower_count":    int(statistics.get("viewCount", 0)),
                    },
                    on_conflict="platform_id,handle",
                )
                .execute()
            )
            channel_author_id = resp_author.data[0]["id"]

            # ── 4. Insert video as post ───────────────────────────────────
            content = f"{video_title}\n\n{video_desc}".strip()
            try:
                resp_post = (
                    supabase.table("posts")
                    .insert({
                        "platform_id":          PLATFORM_ID_YOUTUBE,
                        "author_id":            channel_author_id,
                        "content_text":         content,
                        "posted_at":            posted_at.isoformat(),
                        "raw_engagement_count": engagement,
                        "url":                  video_url,
                    })
                    .execute()
                )
                videos_processed += 1
            except Exception as exc:
                log.debug("Skipping duplicate video %s: %s", video_id, exc)
                continue

            # ── 5. Fetch comments for this video ──────────────────────────
            try:
                comments_resp = youtube.commentThreads().list(
                    videoId=video_id,
                    part="snippet",
                    maxResults=min(max_comments, 100),
                    order="relevance",
                    textFormat="plainText",
                ).execute()
            except HttpError as exc:
                # Comments disabled on this video — skip gracefully
                log.debug("Comments unavailable for video %s: %s", video_id, exc)
                continue

            for comment_item in comments_resp.get("items", []):
                top = comment_item["snippet"]["topLevelComment"]["snippet"]

                commenter_name     = top.get("authorDisplayName", "unknown")
                commenter_channel  = top.get("authorChannelId", {}).get("value", "")
                comment_text       = top.get("textDisplay", "")
                comment_likes      = top.get("likeCount", 0)
                comment_published  = top.get("publishedAt", "")

                if not comment_text.strip():
                    continue

                try:
                    comment_time = datetime.fromisoformat(
                        comment_published.replace("Z", "+00:00")
                    )
                except Exception:
                    comment_time = datetime.now(timezone.utc)

                # ── 6. Upsert commenter as author ─────────────────────────
                commenter_handle = (
                    f"@{commenter_channel}" if commenter_channel
                    else f"@yt_{commenter_name.replace(' ', '_')}"
                )
                resp_commenter = (
                    supabase.table("authors")
                    .upsert(
                        {
                            "platform_id":       PLATFORM_ID_YOUTUBE,
                            "handle":            commenter_handle,
                            "display_name":      commenter_name,
                            "bio_text":          "",
                            "inferred_language": _detect_lang(comment_text),
                            "follower_count":    0,
                        },
                        on_conflict="platform_id,handle",
                    )
                    .execute()
                )
                commenter_author_id = resp_commenter.data[0]["id"]

                # ── 7. Insert comment as post ─────────────────────────────
                try:
                    supabase.table("posts").insert({
                        "platform_id":          PLATFORM_ID_YOUTUBE,
                        "author_id":            commenter_author_id,
                        "content_text":         comment_text,
                        "posted_at":            comment_time.isoformat(),
                        "raw_engagement_count": int(comment_likes),
                        "url":                  video_url,
                    }).execute()
                    comments_processed += 1
                except Exception:
                    continue

                # ── 8. Network edge: commenter → video channel (reply) ────
                if commenter_author_id != channel_author_id:
                    try:
                        supabase.table("network_edges").insert({
                            "source_author_id": commenter_author_id,
                            "target_author_id": channel_author_id,
                            "interaction_type": "reply",
                            "weight":           1,
                            "occurred_at":      comment_time.isoformat(),
                        }).execute()
                        edges_inserted += 1
                    except Exception:
                        pass

                # ── 9. Detect @mentions in comment text ───────────────────
                mentions = re.findall(r"@([\w.-]+)", comment_text)
                for mentioned_handle in set(mentions):
                    target_data = (
                        supabase.table("authors")
                        .select("id")
                        .eq("platform_id", PLATFORM_ID_YOUTUBE)
                        .ilike("handle", f"%{mentioned_handle}%")
                        .limit(1)
                        .execute()
                    )
                    if target_data.data:
                        target_id = target_data.data[0]["id"]
                        if target_id != commenter_author_id:
                            try:
                                supabase.table("network_edges").insert({
                                    "source_author_id": commenter_author_id,
                                    "target_author_id": target_id,
                                    "interaction_type": "mention",
                                    "weight":           1,
                                    "occurred_at":      comment_time.isoformat(),
                                }).execute()
                                edges_inserted += 1
                            except Exception:
                                pass

    log.info(
        "YouTube ingest done. videos=%d  comments=%d  edges=%d",
        videos_processed, comments_processed, edges_inserted,
    )


# ── Helpers ──────────────────────────────────────────────────────────────────

def _detect_lang(text: str) -> str:
    """Very lightweight language guess based on script presence."""
    if any("\u0900" <= ch <= "\u097F" for ch in text):
        return "hi"
    return "en"


if __name__ == "__main__":
    run()
