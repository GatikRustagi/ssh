import '../models/sentiment_score.dart';

/// ============================================================
/// ML Stub Service
/// ============================================================
/// This file contains stub signatures for all ML/NLP pipeline
/// methods that will be implemented in a future sprint.
///
/// DO NOT implement real logic here yet.
/// Replace stubs with calls to your chosen NLP service
/// (e.g., Google Natural Language API, HuggingFace Inference API,
///  or a fine-tuned model deployed on Vertex AI / Replicate).
/// ============================================================

class MLStubService {
  MLStubService._();
  static final MLStubService instance = MLStubService._();

  // ── Sentiment Classification ──────────────────────────────────────────────

  /// TODO: Implement real NLP sentiment classification.
  ///
  /// This should:
  /// 1. Send [text] to your NLP endpoint (e.g., POST /classify)
  /// 2. Return a [SentimentScore] with the predicted label and confidence.
  ///
  /// Suggested labels: positive | negative | neutral | sarcastic | anxious | supportive | against
  ///
  /// For a demo quick-win, you can use:
  ///   - Google Cloud Natural Language API (sentimentScore + magnitude → map to labels)
  ///   - HuggingFace cardiffnlp/twitter-roberta-base-sentiment
  ///   - Fine-tuned multilingual BERT for Hindi/English code-switching
  Future<SentimentScore> classifySentiment(String text, {String? postId}) async {
    // STUB: returns a random neutral score for now
    return SentimentScore(
      id: 'stub-${DateTime.now().millisecondsSinceEpoch}',
      postId: postId ?? 'unknown',
      sentimentLabel: 'neutral',
      confidence: 0.5,
      scoredAt: DateTime.now(),
    );
  }

  // ── Entity / Keyword Extraction ───────────────────────────────────────────

  /// TODO: Implement named entity recognition and keyword extraction.
  ///
  /// This should extract hashtags, named entities, and topic keywords
  /// from [text] to populate the trends table.
  ///
  /// Suggested approaches:
  ///   - Google Cloud Natural Language API (entity analysis)
  ///   - spaCy (via a Python Edge Function sidecar)
  ///   - KeyBERT for keyword extraction
  Future<List<String>> extractKeywords(String text) async {
    // STUB: returns empty list
    return [];
  }

  // ── Demographic Inference ─────────────────────────────────────────────────

  /// TODO: Implement demographic inference from author bio and post content.
  ///
  /// This should infer:
  ///   - [ageBracket]: '18-24' | '25-34' | '35-44' | '45+'
  ///   - [region]: ISO country / region string
  ///   - [language]: BCP-47 language code
  ///
  /// Suggested approaches:
  ///   - Language detection: langdetect (Python) or lingua (Dart)
  ///   - Region inference: NLP location entity extraction
  ///   - Age inference: profile embeddings + regression model
  Future<Map<String, String?>> inferDemographics({
    required String bioText,
    required String recentPostText,
  }) async {
    // STUB: returns empty inference
    return {
      'age_bracket': null,
      'region': null,
      'language': null,
    };
  }

  // ── Network Analysis ──────────────────────────────────────────────────────

  /// TODO: Implement community detection on the network graph.
  ///
  /// This should run a community detection algorithm (e.g., Louvain)
  /// on the [networkEdges] to identify clusters.
  ///
  /// Return a map of author_id → community_id.
  ///
  /// Suggested: igraph Python library via a Supabase Edge Function
  Future<Map<String, int>> detectCommunities(List<Map<String, dynamic>> networkEdges) async {
    // STUB: returns empty community assignment
    return {};
  }
}
