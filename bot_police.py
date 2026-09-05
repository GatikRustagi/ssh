"""
============================================================
👮‍♂️ Bot Police — Coordination Risk Detector (Team Member 5)
============================================================
Scans Supabase posts in real-time.
If multiple different users post identical/near-identical text
within a short time window, it triggers a Coordination Alert!
============================================================
"""

import sys
import time
from datetime import datetime, timezone, timedelta
from collections import defaultdict
from rich.console import Console
from rich.panel import Panel

console = Console()

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

from supabase import create_client, Client

# 1. Connect to Supabase
SUPABASE_URL = "https://yyrxgmkeyxfohururkfi.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5cnhnbWtleXhmb2h1cnVya2ZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg2MjY1NDEsImV4cCI6MjEwNDIwMjU0MX0.2gKiuhHCK7U7_yB4TeNRa0wmxTmN7hDXZ3V2fEE0G0o"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Rules for detecting bots:
TIME_WINDOW_MINUTES = 30   # How far back to look
BOT_THRESHOLD = 3          # If 3 or more accounts post the same thing -> BOTS!

def clean_text(text: str) -> str:
    """Removes extra spaces and makes lowercase so 'Hello' and 'hello ' match."""
    return " ".join(text.lower().strip().split())

def scan_for_bots():
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 🔍 Scanning for bot attacks...")

    # A. Fetch posts from the database
    # In production, we check posts created recently
    response = supabase.table("posts").select("id, author_id, content_text, posted_at, platform_id").order("posted_at", desc=True).limit(50).execute()
    posts = response.data

    if not posts:
        print("No posts found in database.")
        return

    # B. Group posts by clean message text
    text_to_authors = defaultdict(set)
    text_to_post_ids = defaultdict(list)
    text_to_samples = {}

    for post in posts:
        msg = clean_text(post.get("content_text", ""))
        # Ignore very short messages like 'ok', 'yes', 'lol'
        if len(msg) < 15:
            continue
        
        author = post.get("author_id")
        text_to_authors[msg].add(author)
        text_to_post_ids[msg].append(post.get("id"))
        text_to_samples[msg] = post

    # C. Check if any text was repeated by multiple different authors (Duplicate Text)
    bot_detected = False
    now_utc = datetime.now(timezone.utc)
    window_start = (now_utc - timedelta(minutes=TIME_WINDOW_MINUTES)).isoformat()
    window_end = now_utc.isoformat()

    for msg, authors in text_to_authors.items():
        count = len(authors)
        if count >= BOT_THRESHOLD:
            bot_detected = True
            
            # Print a cool red alarm box in the terminal!
            alarm_message = f"[bold yellow]👉 Message:[/bold yellow] [white]\"{msg[:60]}...\"[/white]\n"
            alarm_message += f"[bold yellow]👉 Shared by:[/bold yellow] [bold red]{count} different accounts![/bold red]"
            
            console.print(Panel(alarm_message, title="🚨 ALERT! Found Coordinated Text Attack! 🚨", border_style="red", expand=False))

            sample_post = text_to_samples[msg]
            matching_post_ids = text_to_post_ids[msg]

            narrative_label = f"Coordinated Bot Burst ({count} Accounts)"
            alert_data = {
                "narrative_label": narrative_label,
                "risk_level": "high" if count >= 4 else "medium",
                "risk_score": round(min(0.99, 0.4 + (count * 0.12)), 2),
                "evidence": [
                    f"Detected {count} unique accounts posting identical content within {TIME_WINDOW_MINUTES} minutes.",
                    f"Sample text: {msg[:100]}"
                ],
                "post_ids": matching_post_ids,
                "window_start": window_start,
                "window_end": window_end,
                "resolved": False
            }

            existing = supabase.table("coordination_alerts").select("id").eq("narrative_label", narrative_label).execute()
            if not existing.data:
                supabase.table("coordination_alerts").insert(alert_data).execute()
                console.print("[bold green]✅ Red Alert successfully logged to Supabase![/bold green]\n")
            else:
                console.print("[dim cyan]ℹ️ Alert for this attack was already logged in Supabase.[/dim cyan]\n")

    # =========================================================================
    # NEW SUPERPOWER: Idea 3 - The "Hashtag Swarm" Detector
    # =========================================================================
    import re
    hashtag_to_authors = defaultdict(set)
    hashtag_to_post_ids = defaultdict(list)
    
    # 1. Look inside every post for hashtags
    for post in posts:
        msg = post.get("content_text", "").lower()
        author = post.get("author_id")
        post_id = post.get("id")
        
        # Pull out any word that starts with # (like #BuyMyFakeCoin)
        hashtags_found = set(re.findall(r'#\w+', msg))
        
        for hashtag in hashtags_found:
            hashtag_to_authors[hashtag].add(author)
            hashtag_to_post_ids[hashtag].append(post_id)

    # 2. Check if a hashtag is being used by too many different people!
    for hashtag, authors in hashtag_to_authors.items():
        count = len(authors)
        if count >= BOT_THRESHOLD:
            bot_detected = True
            
            swarm_message = f"[bold yellow]👉 Hashtag:[/bold yellow] [white]{hashtag}[/white]\n"
            swarm_message += f"[bold yellow]👉 Used by:[/bold yellow] [bold red]{count} different accounts![/bold red]"
            
            console.print(Panel(swarm_message, title="🚨 ALERT! Hashtag Swarm Detected! 🚨", border_style="magenta", expand=False))

            narrative_label = f"Hashtag Swarm: {hashtag} ({count} Accounts)"
            alert_data = {
                "narrative_label": narrative_label,
                "risk_level": "high" if count >= 4 else "medium",
                "risk_score": round(min(0.99, 0.4 + (count * 0.1)), 2),
                "evidence": [
                    f"Hashtag {hashtag} was suddenly used by {count} unique accounts.",
                    f"Time window: {TIME_WINDOW_MINUTES} minutes."
                ],
                "post_ids": hashtag_to_post_ids[hashtag],
                "window_start": window_start,
                "window_end": window_end,
                "resolved": False
            }

            existing = supabase.table("coordination_alerts").select("id").eq("narrative_label", narrative_label).execute()
            if not existing.data:
                supabase.table("coordination_alerts").insert(alert_data).execute()
                console.print("[bold green]✅ Hashtag Swarm Alert logged to Supabase![/bold green]\n")
            else:
                console.print("[dim cyan]ℹ️ This hashtag swarm was already logged.[/dim cyan]\n")
    # =========================================================================

    # =========================================================================
    # NEW SUPERPOWER: Idea 4 - The Clean-Up Crew (Hate Speech / Spam Filter)
    # =========================================================================
    bad_words = ["free money", "scam", "click here", "stupid", "idiot", "hate"]
    
    for post in posts:
        msg = post.get("content_text", "").lower()
        author = post.get("author_id")
        post_id = post.get("id")
        
        found_bad_words = [word for word in bad_words if word in msg]
        
        if found_bad_words:
            bot_detected = True
            bad_word_list = ", ".join(found_bad_words)
            
            spam_message = f"[bold yellow]👉 Toxic Word(s):[/bold yellow] [white]{bad_word_list}[/white]\n"
            spam_message += f"[bold yellow]👉 Author:[/bold yellow] [bold red]{author}[/bold red]\n"
            spam_message += f"[bold yellow]👉 Message:[/bold yellow] [dim]{msg[:60]}...[/dim]"
            
            console.print(Panel(spam_message, title="🚨 ALERT! Toxic/Spam Content Detected! 🚨", border_style="dark_orange", expand=False))

            narrative_label = f"Toxic/Spam Content: '{found_bad_words[0]}'"
            alert_data = {
                "narrative_label": narrative_label,
                "risk_level": "medium",
                "risk_score": 0.85,
                "evidence": [
                    f"Message contained toxic/spam keywords: {bad_word_list}",
                    f"Sample text: {msg[:100]}"
                ],
                "post_ids": [post_id],
                "window_start": window_start,
                "window_end": window_end,
                "resolved": False
            }

            existing = supabase.table("coordination_alerts").select("id").eq("narrative_label", narrative_label).execute()
            if not existing.data:
                supabase.table("coordination_alerts").insert(alert_data).execute()
                console.print("[bold green]✅ Toxic Content Alert logged to Supabase![/bold green]\n")
            else:
                console.print("[dim cyan]ℹ️ This toxic content was already logged.[/dim cyan]\n")
    # =========================================================================

    if not bot_detected:
        console.print("[bold green]✅ Playground is safe! No attacks, swarms, or toxic words detected.[/bold green]")

if __name__ == "__main__":
    console.print(Panel("[bold cyan]👮‍♂️ Bot Police is on duty! Press Ctrl+C to stop.[/bold cyan]", expand=False))
    while True:
        try:
            scan_for_bots()
            # Wait 30 seconds before checking again
            time.sleep(30)
        except KeyboardInterrupt:
            console.print("\n[bold magenta]Officer signing off![/bold magenta]")
            break
        except Exception as e:
            print(f"⚠️ Error scanning: {e}")
            time.sleep(10)
