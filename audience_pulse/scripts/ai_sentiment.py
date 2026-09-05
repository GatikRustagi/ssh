import os
import time
from dotenv import load_dotenv
from supabase import create_client, Client
from google import genai

# 1. Load Environment Variables from a .env file
load_dotenv()

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

if not SUPABASE_URL or not SUPABASE_KEY or not GEMINI_API_KEY:
    print("❌ ERROR: Missing environment variables. Please check your .env file.")
    exit(1)

# 2. Connect to Supabase and Gemini
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
client = genai.Client(api_key=GEMINI_API_KEY)

def analyze_sentiment(text: str) -> str:
    """Ask Gemini to classify the sentiment of a social media post."""
    prompt = f"""
    Analyze the following social media post and classify its overall emotion/sentiment.
    You must respond with EXACTLY ONE of the following words (lowercase) and nothing else:
    positive, negative, neutral, sarcastic, anxious, supportive, against
    
    Post: "{text}"
    """
    
    try:
        response = client.models.generate_content(
            model='gemini-3.6-flash',
            contents=prompt,
        )
        label = response.text.strip().lower()
        
        # Ensure Gemini didn't give us weird formatting
        valid_labels = ['positive', 'negative', 'neutral', 'sarcastic', 'anxious', 'supportive', 'against']
        if label in valid_labels:
            return label
        else:
            print(f"⚠️ Gemini returned invalid label '{label}', defaulting to 'neutral'")
            return "neutral"
            
    except Exception as e:
        print(f"⚠️ Error asking Gemini: {e}")
        return "neutral"

def process_new_posts():
    print("🚀 Starting AI Sentiment Analysis Script...")
    
    # 3. Fetch recent posts from Supabase (e.g., top 10 most recent)
    # In a real app, you might want to fetch only posts that don't have a sentiment score yet.
    response = supabase.table("posts").select("id, content_text").order("posted_at", desc=True).limit(10).execute()
    posts = response.data
    
    if not posts:
        print("No posts found in the database.")
        return
        
    print(f"Found {len(posts)} posts to analyze.\n")
    
    # 4. Loop through each post, analyze it, and save the result
    for post in posts:
        post_id = post["id"]
        text = post["content_text"]
        
        print(f"Analyzing: '{text[:50]}...'")
        
        # Get the label from Gemini
        sentiment_label = analyze_sentiment(text)
        print(f"➔ Sentiment: {sentiment_label}")
        
        # Insert the result into the Supabase sentiment_scores table
        try:
            supabase.table("sentiment_scores").insert({
                "post_id": post_id,
                "sentiment_label": sentiment_label,
                "confidence": 0.85 # We are hardcoding confidence for now
            }).execute()
            print("✅ Saved to database!\n")
        except Exception as e:
            # If it fails, it might be because a score already exists for this post, which is fine
            print(f"⚠️ Could not save (might already exist): {e}\n")
            
        # Sleep to avoid hitting Gemini API rate limits (Free tier limit is low)
        time.sleep(15)
        
    print("🎉 Finished processing!")

if __name__ == "__main__":
    process_new_posts()
