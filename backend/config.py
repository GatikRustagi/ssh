"""
config.py — Shared configuration loader for all backend scripts.

Reads from .env in the same directory. Call load_env() once at startup.
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# ── IDs of the two "live" platforms seeded in the database ──────────────────
PLATFORM_ID_TWITTER  = "11111111-0000-0000-0000-000000000001"
PLATFORM_ID_TELEGRAM = "11111111-0000-0000-0000-000000000002"


def load_env() -> None:
    """Load .env from the backend/ directory (one level up from any script)."""
    env_path = Path(__file__).parent / ".env"
    if not env_path.exists():
        raise FileNotFoundError(
            f".env not found at {env_path}. "
            "Copy .env.example → .env and fill in your credentials."
        )
    load_dotenv(env_path)


def get_supabase_client():
    """Return an authenticated Supabase client using the service role key."""
    from supabase import create_client, Client

    url = os.environ["SUPABASE_URL"]
    key = os.environ["SUPABASE_SERVICE_KEY"]

    if "YOUR_PROJECT_REF" in url or not key or key == "your_service_role_key_here":
        raise ValueError(
            "SUPABASE_URL / SUPABASE_SERVICE_KEY not set. "
            "Edit backend/.env with your real credentials."
        )

    client: Client = create_client(url, key)
    return client
