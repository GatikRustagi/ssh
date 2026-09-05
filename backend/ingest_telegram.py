"""
ingest_telegram.py — Read messages from public Telegram channels and store
                     them in Supabase.

What this does:
  1. Connects to Telegram using your API credentials (Telethon).
  2. Reads the last N messages from each channel in TELEGRAM_CHANNELS.
  3. Upserts each channel as an author and each message as a post.
  4. Detects forward (message.forward) interactions → network_edges.

Run manually:   python ingest_telegram.py
Run on a timer: python run_pipeline.py  (calls this every 15 minutes)

NOTE: First run will ask you to enter the OTP Telegram sends to your phone.
      After that, a session file (telegram_session.session) is saved so
      subsequent runs are silent.
"""

import os
import sys
import asyncio
import logging
from datetime import datetime, timezone

# Add parent dir so we can import config.py
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import load_env, get_supabase_client, PLATFORM_ID_TELEGRAM

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [telegram] %(levelname)s %(message)s",
)
log = logging.getLogger(__name__)

MESSAGES_PER_CHANNEL = 50   # how many recent messages to read per channel
SESSION_FILE = "telegram_session"   # stored in backend/ directory


async def _run_async():
    load_env()

    api_id   = os.environ.get("TELEGRAM_API_ID", "")
    api_hash = os.environ.get("TELEGRAM_API_HASH", "")
    phone    = os.environ.get("TELEGRAM_PHONE", "")
    channels = [
        c.strip()
        for c in os.environ.get("TELEGRAM_CHANNELS", "").split(",")
        if c.strip()
    ]

    if not api_id or api_id == "your_api_id_here":
        log.error("TELEGRAM_API_ID not set in .env — skipping Telegram ingest.")
        return
    if not channels:
        log.error("TELEGRAM_CHANNELS is empty in .env — skipping Telegram ingest.")
        return

    from telethon import TelegramClient
    from telethon.tl.types import MessageFwdHeader

    supabase = get_supabase_client()

    # Session file lives in the same directory as this script
    session_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), SESSION_FILE)

    async with TelegramClient(session_path, int(api_id), api_hash) as client:
        await client.start(phone=phone)
        log.info("Telegram client connected.")

        posts_processed = 0
        edges_inserted  = 0

        for channel_username in channels:
            log.info("Reading channel: @%s", channel_username)
            try:
                entity = await client.get_entity(channel_username)
            except Exception as exc:
                log.warning("Cannot access @%s: %s", channel_username, exc)
                continue

            # ── Upsert channel as an author ────────────────────────────────
            channel_handle = f"@{channel_username}"
            channel_name   = getattr(entity, "title", channel_username)
            channel_about  = getattr(entity, "about", "") or ""
            subscriber_count = getattr(entity, "participants_count", 0) or 0

            resp_author = (
                supabase.table("authors")
                .upsert(
                    {
                        "platform_id":    PLATFORM_ID_TELEGRAM,
                        "handle":         channel_handle,
                        "display_name":   channel_name,
                        "bio_text":       channel_about,
                        "inferred_language": "en",
                        "follower_count": subscriber_count,
                    },
                    on_conflict="platform_id,handle",
                )
                .execute()
            )
            channel_author_id = resp_author.data[0]["id"]

            # ── Fetch recent messages ─────────────────────────────────────
            async for message in client.iter_messages(entity, limit=MESSAGES_PER_CHANNEL):
                if not message.text:
                    continue

                posted_at = (message.date or datetime.now(timezone.utc))
                if posted_at.tzinfo is None:
                    posted_at = posted_at.replace(tzinfo=timezone.utc)

                engagement = (
                    (getattr(message, "views", 0) or 0)
                    + (getattr(message, "forwards", 0) or 0)
                    + (getattr(message, "replies", None) and message.replies.replies or 0)
                )

                resp_post = (
                    supabase.table("posts")
                    .insert({
                        "platform_id":          PLATFORM_ID_TELEGRAM,
                        "author_id":            channel_author_id,
                        "content_text":         message.text,
                        "posted_at":            posted_at.isoformat(),
                        "raw_engagement_count": engagement,
                        "url":                  None,
                    })
                    .execute()
                )
                post_db_id = resp_post.data[0]["id"]
                posts_processed += 1

                # ── Forward → network edge ─────────────────────────────────
                if isinstance(message.fwd_from, MessageFwdHeader):
                    fwd_from_id = getattr(message.fwd_from, "channel_id", None)
                    if fwd_from_id:
                        fwd_handle = f"@channel_{fwd_from_id}"
                        # Try to find in our DB (may not exist yet)
                        target_data = (
                            supabase.table("authors")
                            .select("id")
                            .eq("platform_id", PLATFORM_ID_TELEGRAM)
                            .ilike("handle", f"%{fwd_from_id}%")
                            .limit(1)
                            .execute()
                        )
                        if target_data.data:
                            target_id = target_data.data[0]["id"]
                            if target_id != channel_author_id:
                                supabase.table("network_edges").insert({
                                    "source_author_id": channel_author_id,
                                    "target_author_id": target_id,
                                    "interaction_type": "forward",
                                    "weight":           1,
                                    "occurred_at":      posted_at.isoformat(),
                                }).execute()
                                edges_inserted += 1

        log.info(
            "Telegram ingest done. posts=%d  edges=%d",
            posts_processed, edges_inserted,
        )


def run():
    asyncio.run(_run_async())


if __name__ == "__main__":
    run()
