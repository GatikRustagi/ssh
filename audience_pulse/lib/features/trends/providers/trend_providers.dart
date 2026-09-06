import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../models/trend.dart';

// ── Trending Hashtags ─────────────────────────────────────────────────────────

/// Top trends from the `trends` table, sorted by growth_rate descending.
/// Used for the bar chart and trend list in [TrendAnalysisScreen].
final trendingHashtagsProvider = FutureProvider.autoDispose<List<Trend>>((ref) async {
  final data = await SupabaseClientWrapper.client
      .from(AppConstants.tableTrends)
      .select()
      .order('growth_rate', ascending: false)
      .limit(15);

  return (data as List).map((e) => Trend.fromJson(e)).toList();
});

// ── Hourly Engagement ─────────────────────────────────────────────────────────

/// Fetches the last 48 h of posts and groups by hour to build a time-series
/// of total engagement. Returns a list of [HourlyEngagement] records.
final hourlyEngagementProvider =
    FutureProvider.autoDispose<List<HourlyEngagement>>((ref) async {
  final since = DateTime.now().subtract(const Duration(hours: 48));

  final data = await SupabaseClientWrapper.client
      .from(AppConstants.tablePosts)
      .select('posted_at, raw_engagement_count, platform_id')
      .gte('posted_at', since.toIso8601String())
      .order('posted_at', ascending: true);

  final rows = data as List;

  // Group by truncated hour
  final Map<DateTime, int> buckets = {};
  for (final row in rows) {
    final postedAt = DateTime.tryParse(row['posted_at'] as String? ?? '');
    if (postedAt == null) continue;
    final hour = DateTime(
        postedAt.toLocal().year,
        postedAt.toLocal().month,
        postedAt.toLocal().day,
        postedAt.toLocal().hour);
    buckets[hour] = (buckets[hour] ?? 0) +
        ((row['raw_engagement_count'] as num?)?.toInt() ?? 0);
  }

  final result = buckets.entries
      .map((e) => HourlyEngagement(hour: e.key, totalEngagement: e.value))
      .toList()
    ..sort((a, b) => a.hour.compareTo(b.hour));

  return result;
});

// ── Top Authors by Engagement ─────────────────────────────────────────────────

/// Fetches posts with joined authors, aggregates total engagement per author,
/// and returns the top 20 by sum.
final topAuthorsProvider =
    FutureProvider.autoDispose<List<AuthorEngagement>>((ref) async {
  final twitterPlatformId = '11111111-0000-0000-0000-000000000001';

  final data = await SupabaseClientWrapper.client
      .from(AppConstants.tablePosts)
      .select('raw_engagement_count, authors(id, handle, display_name)')
      .eq('platform_id', twitterPlatformId)
      .order('raw_engagement_count', ascending: false)
      .limit(200);

  final rows = data as List;
  final Map<String, AuthorEngagement> agg = {};

  for (final row in rows) {
    final author = row['authors'] as Map<String, dynamic>?;
    if (author == null) continue;
    final id          = author['id'] as String? ?? '';
    final handle      = author['handle'] as String? ?? 'unknown';
    final displayName = author['display_name'] as String? ?? handle;
    final eng         = (row['raw_engagement_count'] as num?)?.toInt() ?? 0;

    if (agg.containsKey(id)) {
      agg[id] = AuthorEngagement(
        id:           id,
        handle:       handle,
        displayName:  displayName,
        totalEngagement: agg[id]!.totalEngagement + eng,
      );
    } else {
      agg[id] = AuthorEngagement(
        id:           id,
        handle:       handle,
        displayName:  displayName,
        totalEngagement: eng,
      );
    }
  }

  final result = agg.values.toList()
    ..sort((a, b) => b.totalEngagement.compareTo(a.totalEngagement));
  return result.take(20).toList();
});

// ── Data Models ───────────────────────────────────────────────────────────────

class HourlyEngagement {
  final DateTime hour;
  final int totalEngagement;
  const HourlyEngagement({required this.hour, required this.totalEngagement});
}

class AuthorEngagement {
  final String id;
  final String handle;
  final String displayName;
  final int totalEngagement;
  const AuthorEngagement({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.totalEngagement,
  });
}
