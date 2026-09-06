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

def insert_mock_post(platform_id: str):
    import random
    mock_users = [
        ("techpulse_in", "Tech Pulse India", "Latest tech news and trends from India."),
        ("ai_dev_1", "AI Developer", "Building the future with LLMs."),
        ("sih_fan", "Hackathon Fanatic", "Coding 24/7"),
        ("news_bot", "News Bot", "Automated alerts"),
        ("angry_citizen", "Concerned Citizen", "We need transparency!")
    ]
    u = random.choice(mock_users)
    db_author_id = upsert_author(platform_id, u[0], u[0], u[1], u[2])
    
    mock_texts = [
        "The new #SIH2026 hackathon projects are absolutely mind blowing! AI is taking over. 🚀",
        "Why is no one talking about the massive leak? We need better #AI security.",
        "Just deployed our model for the hackathon. It scales perfectly. #tech",
        "This is a disaster waiting to happen. The system is flawed.",
        "Great coordination between the teams today! #SIH2026",
        "I'm worried about the implications of this new AI trend... #scary"
    ]
    text = random.choice(mock_texts)
    
    views = random.randint(500, 50000)
    retweets = random.randint(5, 500)
    likes = random.randint(10, 2000)
    replies = random.randint(1, 100)
    total_engagement = views + retweets + likes + replies
    
    supabase.table('posts').insert({
        'platform_id': platform_id,
        'author_id': db_author_id,
        'content_text': text,
        'posted_at': datetime.utcnow().isoformat(),
        'raw_engagement_count': total_engagement,
        'url': f"https://twitter.com/{u[0]}/status/{random.randint(100000,999999)}"
    }).execute()
    logger.info(f"🤖 [MOCK] Inserted viral tweet ({total_engagement} engagements): {text[:50]}...")

def main():
    logger.info("Starting Twitter Data Miner...")
    
    # Ensure platform exists in DB
    platform_id = get_or_create_platform()
    logger.info(f"Using Platform ID: {platform_id}")

    logger.info(f"Polling Twitter API for query: {TARGET_QUERY}")
    logger.info("Press Ctrl+C to stop.")
    
    last_tweet_id = None
    use_mock = False
    
    while True:
        try:
            if use_mock:
                insert_mock_post(platform_id)
                time.sleep(10)  # Push mock data every 10s
                continue
                
            # Fetch recent tweets matching the query
            response = twitter_client.search_recent_tweets(
                query=TARGET_QUERY,
                max_results=10,
                since_id=last_tweet_id,
                tweet_fields=['created_at', 'public_metrics'],
                expansions=['author_id'],
                user_fields=['username', 'name', 'description']
            )
            
            if response.data:
                users = {u.id: u for u in response.includes['users']} if 'users' in response.includes else {}
                
                for tweet in reversed(response.data):
                    author = users.get(tweet.author_id)
                    if not author:
                        continue
                        
                    author_id = str(author.id)
                    username = author.username
                    display_name = author.name
                    bio = author.description or ""
                    
                    try:
                        db_author_id = upsert_author(platform_id, author_id, username, display_name, bio)
                        insert_post(platform_id, db_author_id, tweet, username)
                    except Exception as e:
                        logger.error(f"Failed to insert tweet to DB: {e}")
                        
                    last_tweet_id = max(last_tweet_id or 0, tweet.id)
            
            time.sleep(30)
            
        except KeyboardInterrupt:
            logger.info("Stopping Twitter Data Miner...")
            break
        except Exception as e:
            error_str = str(e).lower()
            if '402' in error_str or '429' in error_str or 'payment' in error_str or 'credits' in error_str:
                logger.warning(f"Twitter API limits reached! Automatically falling back to MOCK MODE. ({e})")
                use_mock = True
            else:
                logger.error(f"Error fetching tweets: {e}")
                time.sleep(60) # Wait longer if there's an API error

if __name__ == '__main__':
    main()
