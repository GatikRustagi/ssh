"""
run_pipeline.py — Master scheduler that runs all backend scripts on a timer.

Schedule:
  Every 15 min  →  ingest_twitter + ingest_telegram + build_network
  Every 60 min  →  build_trends

Usage:
  python run_pipeline.py          # runs forever (Ctrl+C to stop)
  python run_pipeline.py --once   # run everything once and exit (good for testing)

Logs are written to stdout so you can pipe them into a file:
  python run_pipeline.py >> pipeline.log 2>&1
"""

import sys
import logging
import argparse
from datetime import datetime

import schedule
import time

# ── Configure logging ────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [pipeline] %(levelname)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

# ── Import individual pipeline steps ─────────────────────────────────────────
import ingest_twitter
import ingest_telegram
import build_network
import build_trends


def job_ingest_and_network():
    """Runs every 15 minutes: ingest new posts + extract network edges."""
    log.info("=== [15-min job] Starting ingestion + network build ===")
    try:
        ingest_twitter.run()
    except Exception as exc:
        log.error("ingest_twitter failed: %s", exc, exc_info=True)

    try:
        ingest_telegram.run()
    except Exception as exc:
        log.error("ingest_telegram failed: %s", exc, exc_info=True)

    try:
        build_network.run()
    except Exception as exc:
        log.error("build_network failed: %s", exc, exc_info=True)

    log.info("=== [15-min job] Done ===")


def job_trends():
    """Runs every 60 minutes: compute trending keywords from DB."""
    log.info("=== [60-min job] Starting trend computation ===")
    try:
        build_trends.run()
    except Exception as exc:
        log.error("build_trends failed: %s", exc, exc_info=True)
    log.info("=== [60-min job] Done ===")


def run_once():
    """Run every job exactly once — useful for testing / hackathon demo."""
    log.info("Running pipeline in one-shot mode...")
    job_ingest_and_network()
    job_trends()
    log.info("One-shot pipeline complete.")


def run_forever():
    """Register jobs with `schedule` and loop until interrupted."""
    log.info("Starting AudiencePulse pipeline scheduler...")
    log.info("  Ingestion + Network : every 15 minutes")
    log.info("  Trends              : every 60 minutes")
    log.info("Press Ctrl+C to stop.\n")

    # Run immediately on startup so the dashboard has data right away
    job_ingest_and_network()
    job_trends()

    # Then schedule recurring runs
    schedule.every(15).minutes.do(job_ingest_and_network)
    schedule.every(60).minutes.do(job_trends)

    while True:
        schedule.run_pending()
        time.sleep(30)   # check every 30 seconds


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="AudiencePulse backend pipeline")
    parser.add_argument(
        "--once",
        action="store_true",
        help="Run all jobs once and exit (for testing)",
    )
    args = parser.parse_args()

    if args.once:
        run_once()
    else:
        try:
            run_forever()
        except KeyboardInterrupt:
            log.info("Pipeline stopped by user.")
            sys.exit(0)
