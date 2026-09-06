#!/bin/bash
echo "🚀 Starting AudiencePulse Hackathon Pipeline..."

# 1. Start the Data Miners in the background
cd backend_scripts
source venv/bin/activate

echo "🐦 Starting Twitter Miner in background..."
python twitter_miner.py > twitter.log 2>&1 &
TWITTER_PID=$!

echo "✈️ Starting Telegram Miner in background..."
python telegram_miner.py > telegram.log 2>&1 &
TELEGRAM_PID=$!
cd ..

# 2. Start the AI Sentiment Engine in a continuous loop in the background
echo "🧠 Starting AI Sentiment Engine in background..."
(
  cd scripts
  # Use the same virtual environment as the miners
  source ../backend_scripts/venv/bin/activate
  while true; do
    python ai_sentiment.py >> sentiment.log 2>&1
    sleep 30
  done
) &
SENTIMENT_PID=$!

# Ensure all background Python scripts are killed if you press Ctrl+C
trap "echo '🛑 Stopping all background services...'; kill $TWITTER_PID $TELEGRAM_PID $SENTIMENT_PID 2>/dev/null; exit" INT TERM EXIT

echo ""
echo "✅ All backend services (Miners + AI) are streaming data in the background!"
echo "Logs are being saved to: backend_scripts/twitter.log and scripts/sentiment.log"
echo ""
echo "🎨 Now starting the Flutter Dashboard..."

# 3. Start the Frontend in the foreground
flutter clean
flutter run -d chrome
