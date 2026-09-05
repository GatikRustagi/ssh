import os
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Fetch latest 3 posts from Telegram ONLY
posts = supabase.table('posts').select('content_text, posted_at, authors(handle, display_name)').eq('platform_id', '11111111-0000-0000-0000-000000000002').order('created_at', desc=True).limit(3).execute()

print("\n" + "="*60)
print("  YOUR RAW TELEGRAM DATA IN SUPABASE (LATEST 3 POSTS)")
print("="*60)

for p in posts.data:
    author = p.get('authors', {})
    handle = author.get('handle', 'Unknown')
    name = author.get('display_name', 'Unknown')
    content = p.get('content_text', '').replace('\n', ' ')
    if len(content) > 100:
        content = content[:97] + "..."
    
    print(f"\n👤 Author: {name} ({handle})")
    print(f"🕒 Time:   {p.get('posted_at')}")
    print(f"💬 Message: {content}")

print("\n" + "="*60 + "\n")
