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
  return SupabaseService.instance.getSentimentTimelineOnce(
    platformId: platformId,
    range: DateTimeRange(
      start: DateTime.now().subtract(const Duration(hours: 48)),
      end: DateTime.now(),
    ),
  );
});

// ── Sentiment Explainer ───────────────────────────────────────────────────────

/// Derives the dominant sentiment label and evidence string from the latest
/// sentiment scores using AnalysisEngine on the combined text of recent posts.
///
/// Used by [SentimentChartPanel] to display the "because: …" chip.
final sentimentExplainerProvider = FutureProvider.autoDispose<SentimentResult?>((ref) async {
  final platformId = ref.watch(platformFilterProvider);
  final posts = await SupabaseService.instance.getRecentPostsForExplainer(
    platformId: platformId,
    limit: 20,
  );
  if (posts.isEmpty) return null;
  final combined = posts.map((p) => p.contentText).join(' ');
  return AnalysisEngine.instance.classifySentiment(combined);
});

// ── Trends ────────────────────────────────────────────────────────────────────

final topTrendsProvider = FutureProvider.autoDispose<List<Trend>>((ref) async {
  final platformId = ref.watch(platformFilterProvider);
  return SupabaseService.instance.getTopTrends(limit: 10, platformId: platformId);
});

// ── Network Graph ─────────────────────────────────────────────────────────────

final networkGraphProvider = FutureProvider.autoDispose<NetworkGraph>((ref) async {
  final platformId = ref.watch(platformFilterProvider);
  return SupabaseService.instance.getNetworkGraph(platformId: platformId);
});

// ── Demographics ──────────────────────────────────────────────────────────────

final demographicsProvider = FutureProvider.autoDispose<List<DemographicSummary>>((ref) async {
  final platformId = ref.watch(platformFilterProvider);
  return SupabaseService.instance.getDemographicSummary(platformId: platformId);
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
