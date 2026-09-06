import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../core/supabase/supabase_client.dart';
import '../core/constants/app_constants.dart';
import '../models/platform_model.dart';
import '../models/post.dart';
import '../models/sentiment_score.dart';
import '../models/trend.dart';
import '../models/network_graph.dart';
import '../models/demographic_summary.dart';

/// Central data-access layer. All Supabase reads/writes go through here.
/// One method per data type, fully typed.
///
/// Realtime streams use [SupabaseStreamBuilder] for live dashboard updates.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _client => SupabaseClientWrapper.client;

  // ── Platforms / Ingestion Status ──────────────────────────────────────────

  /// Returns all platforms with their live/coming_soon status.
  Future<List<PlatformModel>> getIngestionStatus() async {
    final data = await _client
        .from(AppConstants.tablePlatforms)
        .select()
        .order('name');
    return (data as List).map((e) => PlatformModel.fromJson(e)).toList();
  }

  // ── Sentiment Timeline ─────────────────────────────────────────────────────

  /// Returns a Realtime stream of sentiment scores.
  /// Filters are applied before calling .stream() for compatibility.
  Stream<List<SentimentScore>> getSentimentTimeline({String? platformId}) {
    // Supabase stream API: filters go before .stream()
    // Note: platform filter on a nested table requires a view/RPC for production.
    // For now we stream all and filter in-memory.
    return _client
        .from(AppConstants.tableSentimentScores)
        .stream(primaryKey: ['id'])
        .order('scored_at', ascending: false)
        .limit(200)
        .map((rows) => rows.map((r) => SentimentScore.fromJson(r)).toList());
  }

  /// One-shot fetch of sentiment scores with joined post data.
  Future<List<SentimentScore>> getSentimentTimelineOnce({
    DateTimeRange? range,
    String? platformId,
  }) async {
    // Build query: filter before select for correct type inference
    var query = _client
        .from(AppConstants.tableSentimentScores)
        .select('*, posts(posted_at, platform_id)');

    if (range != null) {
      query = query
          .gte('scored_at', range.start.toIso8601String())
          .lte('scored_at', range.end.toIso8601String());
    }

    final data = await query
        .order('scored_at', ascending: false)
        .limit(200);

    var scores = (data as List).map((e) => SentimentScore.fromJson(e)).toList();

    // In-memory platform filter via joined post data
    if (platformId != null) {
      scores = scores.where((s) => s.platformId == platformId).toList();
    }

    return scores;
  }

  // ── Trends ────────────────────────────────────────────────────────────────

  /// Returns the top [limit] trends ordered by growth rate (descending).
  Future<List<Trend>> getTopTrends({int limit = 10, String? platformId}) async {
    // Build filter before calling order/limit
    var query = _client.from(AppConstants.tableTrends).select();

    if (platformId != null) {
      query = query.eq('platform_id', platformId);
    }

    final data = await query
        .order('growth_rate', ascending: false)
        .limit(limit);

    return (data as List).map((e) => Trend.fromJson(e)).toList();
  }

  // ── Network Graph ─────────────────────────────────────────────────────────

  /// Fetches all authors and edges, computes node degrees,
  /// and returns a [NetworkGraph] ready for visualization.
  Future<NetworkGraph> getNetworkGraph({String? platformId}) async {
    // Fetch edges (no platform filter on edges table directly)
    final edgeData = await _client
        .from(AppConstants.tableNetworkEdges)
        .select()
        .order('occurred_at', ascending: false);

    final edges = (edgeData as List)
        .map((e) => NetworkEdge.fromJson(e))
        .toList();

    // Build a degree map (in + out weighted)
    final degreeMap = <String, int>{};
    for (final edge in edges) {
      degreeMap[edge.sourceAuthorId] =
          (degreeMap[edge.sourceAuthorId] ?? 0) + edge.weight;
      degreeMap[edge.targetAuthorId] =
          (degreeMap[edge.targetAuthorId] ?? 0) + edge.weight;
    }

    // Fetch authors — apply platform filter before select
    var authorQuery = _client.from(AppConstants.tableAuthors).select();
    if (platformId != null) {
      authorQuery = authorQuery.eq('platform_id', platformId);
    }
    final authorData = await authorQuery;

    final nodes = (authorData as List).map((a) {
      final degree = degreeMap[a['id'] as String] ?? 0;
      return NetworkNode.fromAuthorJson(a, degree: degree);
    }).toList();

    return NetworkGraph(nodes: nodes, edges: edges);
  }

  // ── Demographic Summary ───────────────────────────────────────────────────

  /// Returns all demographic summary rows, optionally filtered by platform.
  Future<List<DemographicSummary>> getDemographicSummary({
    String? platformId,
  }) async {
    var query = _client.from(AppConstants.tableDemographicSummaries).select();

    if (platformId != null) {
      query = query.eq('platform_id', platformId);
    }

    final data = await query
        .order('aggregate_count', ascending: false);

    return (data as List).map((e) => DemographicSummary.fromJson(e)).toList();
  }

  // ── Recent Posts (for AnalysisEngine) ────────────────────────────────────

  /// Returns the [limit] most recent posts for the sentiment explainer.
  /// Used by [sentimentExplainerProvider].
  Future<List<Post>> getRecentPostsForExplainer({
    String? platformId,
    int limit = 20,
  }) async {
    var query = _client.from(AppConstants.tablePosts).select();

    if (platformId != null) {
      query = query.eq('platform_id', platformId);
    }

    final data = await query
        .order('posted_at', ascending: false)
        .limit(limit);

    return (data as List).map((e) => Post.fromJson(e)).toList();
  }

  /// Returns the [limit] most viral posts (sorted by raw_engagement_count descending).
  /// Used for the Crisis Matrix.
  Future<List<Post>> getTopViralPosts({
    String? platformId,
    int limit = 50,
  }) async {
    var query = _client.from(AppConstants.tablePosts).select();

    if (platformId != null) {
      query = query.eq('platform_id', platformId);
    }

    final data = await query
        .order('raw_engagement_count', ascending: false)
        .limit(limit);

    return (data as List).map((e) => Post.fromJson(e)).toList();
  }

  /// Returns the [limit] most recent posts for the coordination-risk engine.
  /// Wider window (default 200) so the engine can detect bursts across clusters.
  /// Used by [coordinationAlertsProvider].
  Future<List<Post>> getRecentPostsForCoordination({
    String? platformId,
    int limit = 200,
  }) async {
    var query = _client.from(AppConstants.tablePosts).select();

    if (platformId != null) {
      query = query.eq('platform_id', platformId);
    }

    final data = await query
        .order('posted_at', ascending: false)
        .limit(limit);

    return (data as List).map((e) => Post.fromJson(e)).toList();
  }

  // ── Auth Helpers ──────────────────────────────────────────────────────────

  /// Current signed-in user, or null.
  User? get currentUser => _client.auth.currentUser;

  /// Auth state change stream.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(String email, String password) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'https://yyrxgmkeyxfohururkfi.supabase.co/auth/v1/callback',
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
