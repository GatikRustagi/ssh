import os
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Fetch platforms to map IDs to Names
platforms_response = supabase.table('platforms').select('id, name').execute()
platforms = {p['id']: p['name'] for p in platforms_response.data}

# Fetch latest 10 posts across ALL platforms
posts = supabase.table('posts').select('content_text, posted_at, platform_id, authors(handle, display_name)').order('created_at', desc=True).limit(50).execute()

print("\n" + "="*70)
print("  🚀 LATEST 10 POSTS IN DATABASE (ACROSS ALL PLATFORMS)")
print("="*70)

twitter_count = 0
telegram_count = 0

for p in posts.data:
    author = p.get('authors') or {}
    handle = author.get('handle', 'Unknown')
    name = author.get('display_name', 'Unknown')
    platform_name = platforms.get(p.get('platform_id'), 'Unknown Platform')
    
    if platform_name == 'X (Twitter)':
        twitter_count += 1
    elif platform_name == 'Telegram':
        telegram_count += 1
        
    content = p.get('content_text', '').replace('\n', ' ')
    if len(content) > 80:
        content = content[:77] + "..."
    
    print(f"\n[{platform_name}] 👤 {name} (@{handle})")
    print(f"🕒 {p.get('posted_at')}")
    print(f"💬 {content}")

print("\n" + "="*70)
print(f"SUMMARY OF LAST 10 POSTS: {twitter_count} from Twitter | {telegram_count} from Telegram")
print("="*70 + "\n")
