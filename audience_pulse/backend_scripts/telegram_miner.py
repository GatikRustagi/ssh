import os
import asyncio
import logging
from datetime import datetime
from dotenv import load_dotenv

# Telethon for Telegram
from telethon import TelegramClient, events
from telethon.tl.types import Message, PeerChannel

# Supabase for database
from supabase import create_client, Client

# ==============================================================================
# CONFIGURATION & SETUP
# ==============================================================================

# Configure logging so we can see what the script is doing
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Load credentials from .env file
load_dotenv()

# Telegram Credentials
TELEGRAM_API_ID = os.getenv("TELEGRAM_API_ID")
TELEGRAM_API_HASH = os.getenv("TELEGRAM_API_HASH")

# Supabase Credentials
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

# The channels we want to monitor (you can add more here)
TARGET_CHANNELS = [
    'telegram',         # Official Telegram News
    'indianexpress',    # Indian News (Tech/Global)
    'binanceexchange',  # Highly active Crypto group
]

if not all([TELEGRAM_API_ID, TELEGRAM_API_HASH, SUPABASE_URL, SUPABASE_KEY]):
    logger.error("Missing credentials! Please check your .env file.")
    exit(1)

# Initialize Supabase client
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Initialize Telegram client
# 'session_name' creates a local file to store your login so you don't have to log in every time.
client = TelegramClient('session_name', TELEGRAM_API_ID, TELEGRAM_API_HASH)

# ==============================================================================
# DATABASE HELPERS
# ==============================================================================

def get_or_create_platform() -> str:
    """Ensures 'Telegram' exists in the platforms table and returns its UUID."""
    logger.info("Checking platforms table for 'Telegram'...")
    response = supabase.table('platforms').select('id').eq('name', 'Telegram').execute()
    
    if response.data:
        return response.data[0]['id']
    else:
        logger.info("Platform 'Telegram' not found. Creating it...")
        new_platform = supabase.table('platforms').insert({
            'name': 'Telegram',
            'status': 'live'
        }).execute()
        return new_platform.data[0]['id']

def upsert_author(platform_id: str, author_id: str, username: str, display_name: str) -> str:
    """Inserts the author into the database, or updates them if they already exist."""
    # We use a combined handle for uniqueness, e.g., 'tg_12345678'
    handle = f"tg_{author_id}"
    
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
            'bio_text': '',  # Telethon can fetch bios but it requires extra API calls; leaving blank for speed
        }).execute()
        return new_author.data[0]['id']

def insert_post(platform_id: str, db_author_id: str, message: Message):
    """Inserts a new message into the posts table."""
    text = message.message
    if not text or len(text.strip()) == 0:
        return # Skip empty messages (e.g., just photos)
    
    # Extract URL if available
    url = f"https://t.me/c/{message.peer_id.channel_id}/{message.id}" if isinstance(message.peer_id, PeerChannel) else None
    
    views = getattr(message, 'views', 0) or 0
    forwards = getattr(message, 'forwards', 0) or 0
    
    # Calculate reactions if any
    reaction_count = 0
    if getattr(message, 'reactions', None) and getattr(message.reactions, 'results', None):
        for reaction in message.reactions.results:
            reaction_count += getattr(reaction, 'count', 0)

    total_engagement = views + forwards + reaction_count
    
    # Insert post
    supabase.table('posts').insert({
        'platform_id': platform_id,
        'author_id': db_author_id,
        'content_text': text,
        'posted_at': message.date.isoformat(),
        'raw_engagement_count': total_engagement,
        'url': url
    }).execute()
    logger.info(f"🚀 Inserted viral post ({total_engagement} engagements): {text[:50]}...")

# ==============================================================================
# MAIN LOGIC
# ==============================================================================

async def main():
    logger.info("Starting Telegram Data Miner...")
    
    # Ensure platform exists in DB
    platform_id = get_or_create_platform()
    logger.info(f"Using Platform ID: {platform_id}")

    # Start the Telegram client
    await client.start()
    logger.info("Successfully connected to Telegram!")

    # --------------------------------------------------------------------------
    # OPTION A: Live Stream Mode (Listen for new messages in real-time)
    # --------------------------------------------------------------------------
    @client.on(events.NewMessage(chats=TARGET_CHANNELS))
    async def handler(event):
        message: Message = event.message
        
        # Get sender info
        sender = await event.get_sender()
        if not sender:
            return
            
        author_id = str(sender.id)
        username = getattr(sender, 'username', '')
        
        # Telegram users have first/last name, channels have titles
        display_name = getattr(sender, 'title', '')
        if not display_name:
            first = getattr(sender, 'first_name', '')
            last = getattr(sender, 'last_name', '')
            display_name = f"{first} {last}".strip()
            
        try:
            # Save to DB
            db_author_id = upsert_author(platform_id, author_id, username, display_name)
            insert_post(platform_id, db_author_id, message)
        except Exception as e:
            logger.error(f"Failed to insert message to DB: {e}")

    logger.info(f"Listening for live messages in: {TARGET_CHANNELS}")
    logger.info("Press Ctrl+C to stop.")
    
    # Run until interrupted
    await client.run_until_disconnected()

    # --------------------------------------------------------------------------
    # OPTION B: Historical Fetch Mode (Fast Test!)
    # --------------------------------------------------------------------------
    """
    for channel in TARGET_CHANNELS:
        logger.info(f"Fetching 10 historical messages from {channel} to test...")
        # Get the last 10 messages
        async for message in client.iter_messages(channel, limit=10):
            if not message.message:
                continue
                
            sender = await message.get_sender()
            if not sender:
                continue
                
            author_id = str(sender.id)
            username = getattr(sender, 'username', '')
            display_name = getattr(sender, 'title', '')
            if not display_name:
                first = getattr(sender, 'first_name', '')
                last = getattr(sender, 'last_name', '')
                display_name = f"{first} {last}".strip()
                
            try:
                db_author_id = upsert_author(platform_id, author_id, username, display_name)
                insert_post(platform_id, db_author_id, message)
            except Exception as e:
                logger.error(f"Failed to insert historical message: {e}")
                
    logger.info("Fast test complete! You can switch back to Option A (Live Stream) when you are ready.")
    """

if __name__ == '__main__':
    # Run the async main function
    asyncio.run(main())
