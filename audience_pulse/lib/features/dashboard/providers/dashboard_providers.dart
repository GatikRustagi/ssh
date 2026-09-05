import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supabase_service.dart';
import '../../../models/sentiment_score.dart';
import '../../../models/trend.dart';
import '../../../models/network_graph.dart';
import '../../../models/demographic_summary.dart';

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
