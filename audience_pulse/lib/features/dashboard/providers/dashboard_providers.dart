import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supabase_service.dart';
import '../../../services/analysis_engine.dart';
import '../../../models/sentiment_score.dart';
import '../../../models/trend.dart';
import '../../../models/network_graph.dart';
import '../../../models/demographic_summary.dart';
import '../../../models/analysis_models.dart';

// ── Platform Filter State ─────────────────────────────────────────────────────
/// Holds the currently selected platform ID filter (null = All).
final platformFilterProvider = StateProvider<String?>((ref) => null);

// ── Time Range Filter State ───────────────────────────────────────────────────
/// Holds the currently selected time range filter.
final timeRangeFilterProvider = StateProvider<String>((ref) => '1D');

// ── Trend Sentiment Filter State ──────────────────────────────────────────────
/// Holds the currently selected sentiment filter for Top Trends.
final trendSentimentFilterProvider = StateProvider<String>((ref) => 'All');

// ── Sentiment Timeline ────────────────────────────────────────────────────────

/// Realtime stream of sentiment scores.
/// Automatically re-emits whenever sentiment_scores rows change.
final sentimentStreamProvider = StreamProvider.autoDispose<List<SentimentScore>>((ref) {
  final platformId = ref.watch(platformFilterProvider);
  return SupabaseService.instance.getSentimentTimeline(platformId: platformId);
});

/// One-shot fetch used for the initial chart render (includes joined posted_at).
final sentimentTimelineProvider = FutureProvider.autoDispose<List<SentimentScore>>((ref) async {
  final platformId = ref.watch(platformFilterProvider);
  final timeRange = ref.watch(timeRangeFilterProvider);
  
  Duration duration;
  switch (timeRange) {
    case '1H': duration = const Duration(hours: 1); break;
    case '1D': duration = const Duration(days: 1); break;
    case '1W': duration = const Duration(days: 7); break;
    case '1M': duration = const Duration(days: 30); break;
    case '1Y': duration = const Duration(days: 365); break;
    case 'ALL': duration = const Duration(days: 3650); break;
    default: duration = const Duration(days: 1); break;
  }

  try {
    final res = await SupabaseService.instance.getSentimentTimelineOnce(
      platformId: platformId,
      range: DateTimeRange(
        start: DateTime.now().subtract(duration),
        end: DateTime.now(),
      ),
    );
    if (res.isNotEmpty) return res;
  } catch (_) {}
  return _fallbackSentimentScores();
});

// ── Sentiment Explainer ───────────────────────────────────────────────────────

/// Derives the dominant sentiment label and evidence string from the latest
/// sentiment scores using AnalysisEngine on the combined text of recent posts.
///
/// Used by [SentimentChartPanel] to display the "because: …" chip.
final sentimentExplainerProvider = FutureProvider.autoDispose<SentimentResult?>((ref) async {
  final platformId = ref.watch(platformFilterProvider);
  try {
    final posts = await SupabaseService.instance.getRecentPostsForExplainer(
      platformId: platformId,
      limit: 20,
    );
    if (posts.isNotEmpty) {
      final combined = posts.map((p) => p.contentText).join(' ');
      return AnalysisEngine.instance.classifySentiment(combined);
    }
  } catch (_) {}
  return AnalysisEngine.instance.classifySentiment('Tech innovation and AI growth community support');
});

// ── Trends ────────────────────────────────────────────────────────────────────

final topTrendsProvider = FutureProvider.autoDispose<List<Trend>>((ref) async {
  final platformId = ref.watch(platformFilterProvider);
  try {
    final res = await SupabaseService.instance.getTopTrends(limit: 10, platformId: platformId);
    if (res.isNotEmpty) return res;
  } catch (_) {}
  return _fallbackTrends();
});

// ── Network Graph ─────────────────────────────────────────────────────────────

final networkGraphProvider = FutureProvider.autoDispose<NetworkGraph>((ref) async {
  final platformId = ref.watch(platformFilterProvider);
  try {
    final res = await SupabaseService.instance.getNetworkGraph(platformId: platformId);
    if (res.nodes.isNotEmpty) return res;
  } catch (_) {}
  return _fallbackNetworkGraph();
});

// ── Demographics ──────────────────────────────────────────────────────────────

final demographicsProvider = FutureProvider.autoDispose<List<DemographicSummary>>((ref) async {
  final platformId = ref.watch(platformFilterProvider);
  try {
    final res = await SupabaseService.instance.getDemographicSummary(platformId: platformId);
    if (res.isNotEmpty) return res;
  } catch (_) {}
  return _fallbackDemographics();
});

// ── Ingestion Status ──────────────────────────────────────────────────────────

final ingestionStatusProvider = FutureProvider.autoDispose((ref) async {
  return SupabaseService.instance.getIngestionStatus();
});

// ── Coordination Risk Alerts ──────────────────────────────────────────────────

/// Fetches recent posts, runs the deterministic AnalysisEngine coordination-
/// risk rules on them, and returns a list of [CoordinationRiskResult] sorted
/// by risk score (highest first).
///
/// Auto-refreshes every 60 seconds via a delayed self-invalidation.
final coordinationAlertsProvider =
    FutureProvider.autoDispose<List<CoordinationRiskResult>>((ref) async {
  final platformId = ref.watch(platformFilterProvider);

  // Schedule refresh after 60 s
  ref.keepAlive();
  Future.delayed(const Duration(seconds: 60), () {
    ref.invalidateSelf();
  });

  final posts = await SupabaseService.instance.getRecentPostsForCoordination(
    platformId: platformId,
    limit: 200,
  );
  return AnalysisEngine.instance.computeCoordinationRisk(posts);
});

// ── Crisis Matrix ─────────────────────────────────────────────────────────────

class CrisisPoint {
  final String author;
  final String content;
  final int virality;
  final double sentimentScore; // -1.0 to 1.0
  
  CrisisPoint({
    required this.author,
    required this.content,
    required this.virality,
    required this.sentimentScore,
  });
}

final crisisMatrixProvider = FutureProvider.autoDispose<List<CrisisPoint>>((ref) async {
  final platformId = ref.watch(platformFilterProvider);
  final posts = await SupabaseService.instance.getTopViralPosts(
    platformId: platformId,
    limit: 50,
  );
  
  final points = <CrisisPoint>[];
  for (final post in posts) {
    final result = AnalysisEngine.instance.classifySentiment(post.contentText);
    double y = result.score;
    if (['negative', 'anxious', 'against', 'sarcastic'].contains(result.label)) {
      y = -y;
    } else if (result.label == 'neutral') {
      y = 0.0;
    }
    
    // Slight jitter to avoid overlapping dots perfectly
    final jitter = (DateTime.now().millisecondsSinceEpoch % 100) / 1000.0;
    y += jitter * (y < 0 ? 1 : -1);
    
    points.add(CrisisPoint(
      author: post.authorId, // Ideally we map this to handle, but author_id works for now
      content: post.contentText,
      virality: post.rawEngagementCount,
      sentimentScore: y.clamp(-1.0, 1.0),
    ));
  }
  return points;
});

// ── Last Updated ──────────────────────────────────────────────────────────────

/// Simple notifier that tracks the last-refresh timestamp per panel key.
class LastUpdatedNotifier extends StateNotifier<Map<String, DateTime>> {
  LastUpdatedNotifier() : super({});

  void markUpdated(String panelKey) {
    state = {...state, panelKey: DateTime.now()};
  }
}

final lastUpdatedProvider =
    StateNotifierProvider<LastUpdatedNotifier, Map<String, DateTime>>(
  (ref) => LastUpdatedNotifier(),
);

// ── Saved Trends ──────────────────────────────────────────────────────────────
class SavedTrendsNotifier extends StateNotifier<List<Trend>> {
  SavedTrendsNotifier() : super([]);

  void saveTrend(Trend trend) {
    if (!state.any((t) => t.id == trend.id)) {
      state = [...state, trend];
    }
  }

  void removeTrend(String id) {
    state = state.where((t) => t.id != id).toList();
  }
}

final savedTrendsProvider =
    StateNotifierProvider<SavedTrendsNotifier, List<Trend>>(
  (ref) => SavedTrendsNotifier(),
);

// ── Fallback Mock Generators ──────────────────────────────────────────────────

List<Trend> _fallbackTrends() {
  final now = DateTime.now();
  final start = now.subtract(const Duration(hours: 1));
  return [
    Trend(id: 't1', platformId: 'p1', keywordOrTopic: '#TechInnovation2026', mentionCount: 18400, growthRate: 1.85, windowStart: start, windowEnd: now, createdAt: now),
    Trend(id: 't2', platformId: 'p1', keywordOrTopic: '#AIAssembly', mentionCount: 14200, growthRate: 1.42, windowStart: start, windowEnd: now, createdAt: now),
    Trend(id: 't3', platformId: 'p1', keywordOrTopic: '#QuantumLeap', mentionCount: 9800, growthRate: 0.95, windowStart: start, windowEnd: now, createdAt: now),
    Trend(id: 't4', platformId: 'p1', keywordOrTopic: 'SafeCity Campaign', mentionCount: 7600, growthRate: 0.72, windowStart: start, windowEnd: now, createdAt: now),
    Trend(id: 't5', platformId: 'p1', keywordOrTopic: '#CyberDefense', mentionCount: 6100, growthRate: 0.48, windowStart: start, windowEnd: now, createdAt: now),
    Trend(id: 't6', platformId: 'p1', keywordOrTopic: 'Cloud Native Infra', mentionCount: 4900, growthRate: 0.35, windowStart: start, windowEnd: now, createdAt: now),
    Trend(id: 't7', platformId: 'p1', keywordOrTopic: '#DataPrivacy', mentionCount: 3800, growthRate: -0.15, windowStart: start, windowEnd: now, createdAt: now),
  ];
}

List<DemographicSummary> _fallbackDemographics() {
  final now = DateTime.now();
  return [
    DemographicSummary(id: 'd1', platformId: 'p1', ageBracket: '18-24', region: 'India', language: 'English', aggregateCount: 14200, computedAt: now),
    DemographicSummary(id: 'd2', platformId: 'p1', ageBracket: '25-34', region: 'United States', language: 'Hindi', aggregateCount: 21800, computedAt: now),
    DemographicSummary(id: 'd3', platformId: 'p1', ageBracket: '35-44', region: 'United Kingdom', language: 'Spanish', aggregateCount: 16500, computedAt: now),
    DemographicSummary(id: 'd4', platformId: 'p1', ageBracket: '45+', region: 'Germany', language: 'German', aggregateCount: 9800, computedAt: now),
    DemographicSummary(id: 'd5', platformId: 'p1', ageBracket: '25-34', region: 'Japan', language: 'Japanese', aggregateCount: 7400, computedAt: now),
    DemographicSummary(id: 'd6', platformId: 'p1', ageBracket: '18-24', region: 'Canada', language: 'French', aggregateCount: 5200, computedAt: now),
  ];
}

NetworkGraph _fallbackNetworkGraph() {
  final now = DateTime.now();
  final nodes = [
    const NetworkNode(id: 'a1', handle: '@techpulse_in', followerCount: 125000, platformId: 'p1', degree: 48),
    const NetworkNode(id: 'a2', handle: '@tg_test_indistech', followerCount: 84000, platformId: 'p1', degree: 36),
    const NetworkNode(id: 'a3', handle: '@test_startup', followerCount: 52000, platformId: 'p1', degree: 28),
    const NetworkNode(id: 'a4', handle: '@dev_insider', followerCount: 31000, platformId: 'p1', degree: 18),
    const NetworkNode(id: 'a5', handle: '@ai_frontiers', followerCount: 45000, platformId: 'p1', degree: 22),
    const NetworkNode(id: 'a6', handle: '@cyber_analyst', followerCount: 28000, platformId: 'p1', degree: 14),
    const NetworkNode(id: 'a7', handle: '@cloud_architect', followerCount: 39000, platformId: 'p1', degree: 20),
  ];
  final edges = [
    NetworkEdge(id: 'e1', sourceAuthorId: 'a1', targetAuthorId: 'a2', interactionType: 'retweet', weight: 4, occurredAt: now),
    NetworkEdge(id: 'e2', sourceAuthorId: 'a1', targetAuthorId: 'a3', interactionType: 'reply', weight: 3, occurredAt: now),
    NetworkEdge(id: 'e3', sourceAuthorId: 'a2', targetAuthorId: 'a4', interactionType: 'mention', weight: 2, occurredAt: now),
    NetworkEdge(id: 'e4', sourceAuthorId: 'a3', targetAuthorId: 'a5', interactionType: 'forward', weight: 3, occurredAt: now),
    NetworkEdge(id: 'e5', sourceAuthorId: 'a5', targetAuthorId: 'a6', interactionType: 'retweet', weight: 2, occurredAt: now),
    NetworkEdge(id: 'e6', sourceAuthorId: 'a1', targetAuthorId: 'a7', interactionType: 'reply', weight: 3, occurredAt: now),
    NetworkEdge(id: 'e7', sourceAuthorId: 'a7', targetAuthorId: 'a4', interactionType: 'mention', weight: 2, occurredAt: now),
  ];
  return NetworkGraph(nodes: nodes, edges: edges);
}

List<SentimentScore> _fallbackSentimentScores() {
  final now = DateTime.now();
  final labels = ['positive', 'positive', 'anxious', 'sarcastic', 'positive', 'supportive', 'negative'];
  return List.generate(48, (i) => SentimentScore(
    id: 'score-$i',
    postId: 'post-$i',
    sentimentLabel: labels[i % labels.length],
    confidence: 0.7 + (i % 3) * 0.1,
    scoredAt: now.subtract(Duration(hours: i)),
  ));
}
