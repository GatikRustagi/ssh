import os
import time
import logging
from datetime import datetime
from dotenv import load_dotenv

# Tweepy for Twitter API v2
import tweepy

# Supabase for database
from supabase import create_client, Client

# ==============================================================================
# CONFIGURATION & SETUP
# ==============================================================================

# Configure logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Load credentials from .env file
load_dotenv()

# Twitter Credentials (API v2 Bearer Token is easiest for searching)
TWITTER_BEARER_TOKEN = os.getenv("TWITTER_BEARER_TOKEN")

# Supabase Credentials
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

# The topics/hashtags we want to monitor
TARGET_QUERY = "(#SIH2026 OR #AI OR #hackathon) -is:retweet"

if not all([TWITTER_BEARER_TOKEN, SUPABASE_URL, SUPABASE_KEY]):
    logger.error("Missing credentials! Please check your .env file for Twitter and Supabase keys.")
    exit(1)

# Initialize Supabase client
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Initialize Twitter Client (Tweepy API v2)
twitter_client = tweepy.Client(bearer_token=TWITTER_BEARER_TOKEN)

# ==============================================================================
# DATABASE HELPERS
# ==============================================================================

def get_or_create_platform() -> str:
    """Ensures 'X (Twitter)' exists in the platforms table and returns its UUID."""
    logger.info("Checking platforms table for 'X (Twitter)'...")
    response = supabase.table('platforms').select('id').eq('name', 'X (Twitter)').execute()
    
    if response.data:
        return response.data[0]['id']
    else:
        logger.info("Platform 'X (Twitter)' not found. Creating it...")
        new_platform = supabase.table('platforms').insert({
            'name': 'X (Twitter)',
            'status': 'live'
        }).execute()
        return new_platform.data[0]['id']

def upsert_author(platform_id: str, author_id: str, username: str, display_name: str, bio_text: str = "") -> str:
    """Inserts the author into the database, or updates them if they already exist."""
    # We use a combined handle for uniqueness, e.g., 'tw_12345678'
    handle = f"tw_{author_id}"
    
    # Check if author exists
    response = supabase.table('authors').select('id').eq('platform_id', platform_id).eq('handle', handle).execute()
    
    if response.data:
        # Update existing
        db_id = response.data[0]['id']
        supabase.table('authors').update({
            'display_name': display_name or username or "Unknown",
        }).eq('id', db_id).execute()
        return db_id
    else:
        # Insert new
        new_author = supabase.table('authors').insert({
            'platform_id': platform_id,
            'handle': handle,
            'display_name': display_name or username or "Unknown",
            'bio_text': bio_text,
        }).execute()
        return new_author.data[0]['id']

def insert_post(platform_id: str, db_author_id: str, tweet: tweepy.Tweet, username: str):
    """Inserts a new tweet into the posts table with virality metrics."""
    text = tweet.text
    if not text or len(text.strip()) == 0:
        return # Skip empty tweets
    
    # Extract URL if available
    url = f"https://twitter.com/{username}/status/{tweet.id}"
    
    # Capture Virality Metrics (Views, Retweets, Likes, Replies)
    public_metrics = tweet.public_metrics or {}
    views = public_metrics.get('impression_count', 0)
    retweets = public_metrics.get('retweet_count', 0)
    likes = public_metrics.get('like_count', 0)
    replies = public_metrics.get('reply_count', 0)
    
    # Calculate total engagement
    total_engagement = views + retweets + likes + replies
    
    # Insert post
    supabase.table('posts').insert({
        'platform_id': platform_id,
        'author_id': db_author_id,
        'content_text': text,
        'posted_at': tweet.created_at.isoformat() if tweet.created_at else datetime.utcnow().isoformat(),
        'raw_engagement_count': total_engagement,
        'url': url
    }).execute()
    logger.info(f"🚀 Inserted viral tweet ({total_engagement} engagements): {text[:50]}...")

# ==============================================================================
# MAIN LOGIC
# ==============================================================================

def main():
    logger.info("Starting Twitter Data Miner...")
    
    # Ensure platform exists in DB
    platform_id = get_or_create_platform()
    logger.info(f"Using Platform ID: {platform_id}")

    logger.info(f"Polling Twitter API for query: {TARGET_QUERY}")
    logger.info("Press Ctrl+C to stop.")
    
    # Note: Twitter API v2 does not have a simple async stream like Telethon.
    # We will use a polling loop (fetching recent tweets every 30 seconds).
    
    last_tweet_id = None
    
    while True:
        try:
            # Fetch recent tweets matching the query
            response = twitter_client.search_recent_tweets(
                query=TARGET_QUERY,
                max_results=10, # Get up to 10 latest tweets
                since_id=last_tweet_id,
                tweet_fields=['created_at', 'public_metrics'],
                expansions=['author_id'],
                user_fields=['username', 'name', 'description']
            )
            
            if response.data:
                # Map users for easy lookup
                users = {u.id: u for u in response.includes['users']} if 'users' in response.includes else {}
                
                for tweet in reversed(response.data): # Process oldest to newest
                    author = users.get(tweet.author_id)
                    if not author:
                        continue
                        
                    author_id = str(author.id)
                    username = author.username
                    display_name = author.name
                    bio = author.description or ""
                    
                    try:
                        # Save to DB
                        db_author_id = upsert_author(platform_id, author_id, username, display_name, bio)
                        insert_post(platform_id, db_author_id, tweet, username)
                    except Exception as e:
                        logger.error(f"Failed to insert tweet to DB: {e}")
                        
                    # Update the last tweet ID so we don't fetch duplicates
                    last_tweet_id = max(last_tweet_id or 0, tweet.id)
            
            # Wait 30 seconds before polling again to avoid API rate limits
            time.sleep(30)
            
        except KeyboardInterrupt:
            logger.info("Stopping Twitter Data Miner...")
            break
        except Exception as e:
            logger.error(f"Error fetching tweets: {e}")
            time.sleep(60) # Wait longer if there's an API error

if __name__ == '__main__':
    main()
