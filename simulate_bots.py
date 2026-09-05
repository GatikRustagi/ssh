# simulate_bots.py
import sys

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

from supabase import create_client

SUPABASE_URL = "https://yyrxgmkeyxfohururkfi.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5cnhnbWtleXhmb2h1cnVya2ZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg2MjY1NDEsImV4cCI6MjEwNDIwMjU0MX0.2gKiuhHCK7U7_yB4TeNRa0wmxTmN7hDXZ3V2fEE0G0o"
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# 1. Grab 4 existing authors
authors = supabase.table("authors").select("id, platform_id").limit(4).execute().data

# 2. Inject identical spam message from 4 different authors (Coordinated Text Attack)
spam_message = "URGENT 🚨 Claim your free SIH prize tokens now at http://fake-scam-link.xyz!"

print("🤖 Injecting 4 fake bot posts (Duplicate Text Attack)...")
for author in authors[:4]:
    supabase.table("posts").insert({
        "platform_id": author["platform_id"],
        "author_id": author["id"],
        "content_text": spam_message,
        "posted_at": "2026-09-06T00:00:00Z",
        "raw_engagement_count": 0
    }).execute()

# 3. Inject a Hashtag Swarm Attack (Idea 3)
print("🤖 Injecting 4 fake bot posts (Hashtag Swarm Attack)...")
swarm_messages = [
    "I just bought a new car! #BuyMyFakeCoin",
    "Wow what a beautiful day today! #BuyMyFakeCoin",
    "Can't believe I saw this on the news... #BuyMyFakeCoin",
    "Does anyone know a good pizza place? #BuyMyFakeCoin"
]

for i in range(4):
    supabase.table("posts").insert({
        "platform_id": authors[i]["platform_id"],
        "author_id": authors[i]["id"],
        "content_text": swarm_messages[i],
        "posted_at": "2026-09-06T00:01:00Z",
        "raw_engagement_count": 0
    }).execute()

print("✅ Bot posts injected! Now run bot_police.py to see it catch them!")
