import 'package:flutter/material.dart';
import 'package:audience_pulse/core/theme/app_theme.dart';

/// App-wide constants: route paths, sentiment colors, platform IDs.
class AppConstants {
  AppConstants._();

  // ── Route Paths ───────────────────────────────────────────────────────────
  static const String routeLogin           = '/login';
  static const String routeDashboard       = '/dashboard';
  static const String routeIngestion       = '/ingestion';
  static const String routeTwitterDetails  = '/twitter-details';
  static const String routeTrends          = '/trends';

  // ── Supabase Table Names ──────────────────────────────────────────────────
  static const String tablePlatforms           = 'platforms';
  static const String tableAuthors             = 'authors';
  static const String tablePosts               = 'posts';
  static const String tableSentimentScores     = 'sentiment_scores';
  static const String tableTrends              = 'trends';
  static const String tableNetworkEdges        = 'network_edges';
  static const String tableDemographicSummaries= 'demographic_summaries';

  // ── Sentiment Label → Color ────────────────────────────────────────────────
  static const Map<String, Color> sentimentColors = {
    'positive'  : AppTheme.sentimentPositive,
    'negative'  : AppTheme.sentimentNegative,
    'neutral'   : AppTheme.sentimentNeutral,
    'sarcastic' : AppTheme.sentimentSarcastic,
    'anxious'   : AppTheme.sentimentAnxious,
    'supportive': AppTheme.sentimentSupportive,
    'against'   : AppTheme.sentimentAgainst,
  };

  // ── Sentiment Label → Emoji ────────────────────────────────────────────────
  static const Map<String, String> sentimentEmoji = {
    'positive'  : '',
    'negative'  : '',
    'neutral'   : '',
    'sarcastic' : '',
    'anxious'   : '',
    'supportive': '',
    'against'   : '',
  };

  // ── Platform Display Names ────────────────────────────────────────────────
  static const Map<String, String> platformIcons = {
    'X (Twitter)': '𝕏',
    'Telegram'   : '✈️',
    'Instagram'  : '📸',
    'Facebook'   : '📘',
    'Reddit'     : '🤖',
    'YouTube'    : '▶️',
  };

  // ── Dashboard ─────────────────────────────────────────────────────────────
  static const int defaultTrendLimit = 10;
  static const Duration realtimeThrottle = Duration(seconds: 5);
}
