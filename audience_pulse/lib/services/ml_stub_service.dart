import '../models/sentiment_score.dart';
import '../models/analysis_models.dart';
import 'analysis_engine.dart';

/// ============================================================
/// ML Stub Service — now delegates to AnalysisEngine
/// ============================================================
/// Method signatures are unchanged so no call-sites break.
/// Previously returned hard-coded neutral stubs; now returns
/// real rule-based results from the deterministic AnalysisEngine.
///
/// To swap in a real NLP backend later, replace the
/// AnalysisEngine.instance.* calls with your HTTP calls.
/// ============================================================

class MLStubService {
  MLStubService._();
  static final MLStubService instance = MLStubService._();

  // ── Sentiment Classification ──────────────────────────────────────────────

  /// Classifies [text] using the deterministic emotion-lexicon engine.
  ///
  /// Returns a [SentimentScore] compatible with the existing Supabase schema.
  /// The [because] evidence is stored nowhere currently — extend the schema
  /// to persist it if you want per-post audit trails.
  Future<SentimentScore> classifySentiment(String text, {String? postId}) async {
    final result = AnalysisEngine.instance.classifySentiment(text);
    return SentimentScore(
      id: 'engine-${DateTime.now().millisecondsSinceEpoch}',
      postId: postId ?? 'unknown',
      sentimentLabel: result.label,
      confidence: result.confidence,
      scoredAt: DateTime.now(),
    );
  }

  /// Convenience method that exposes the full [SentimentResult] with evidence.
  SentimentResult classifySentimentFull(String text) =>
      AnalysisEngine.instance.classifySentiment(text);

  // ── Entity / Keyword Extraction ───────────────────────────────────────────

  /// Extracts hashtags and high-frequency keywords from [text].
  Future<List<String>> extractKeywords(String text) async =>
      AnalysisEngine.instance.extractKeywords(text);

  // ── Demographic Inference ─────────────────────────────────────────────────

  /// Demographic inference stub — still returns empty inference.
  ///
  /// The project plan specifies using only declared/observable public signals
  /// (language, region, declared interest) counted in aggregate groups.
  /// Individual-level inference is intentionally out of scope.
  Future<Map<String, String?>> inferDemographics({
    required String bioText,
    required String recentPostText,
  }) async {
    // TODO (future sprint): Use public region/language signals only.
    // Detect language from text → map to BCP-47 code.
    // Extract location mentions from bio → resolve to region string.
    // Never infer age or identity from content.
    return {
      'age_bracket': null,
      'region': null,
      'language': null,
    };
  }

  // ── Network Analysis ──────────────────────────────────────────────────────

  /// Community detection stub — still returns empty assignment.
  ///
  /// In production: send [networkEdges] to a Supabase Edge Function
  /// running python-igraph (Louvain), receive community_id per node.
  Future<Map<String, int>> detectCommunities(
    List<Map<String, dynamic>> networkEdges,
  ) async {
    // TODO (future sprint): igraph Louvain via Edge Function.
    return {};
  }
}
