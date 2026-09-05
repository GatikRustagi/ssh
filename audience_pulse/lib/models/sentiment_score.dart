/// ML-computed sentiment classification for a post.
///
/// Sentiment labels: positive | negative | neutral | sarcastic | anxious | supportive | against
class SentimentScore {
  final String id;
  final String postId;
  final String sentimentLabel;
  final double confidence;
  final DateTime scoredAt;

  // Optional joined fields from posts table
  final DateTime? postedAt;
  final String? platformId;

  const SentimentScore({
    required this.id,
    required this.postId,
    required this.sentimentLabel,
    required this.confidence,
    required this.scoredAt,
    this.postedAt,
    this.platformId,
  });

  factory SentimentScore.fromJson(Map<String, dynamic> json) {
    // Support flat join: sentiment_scores joined with posts
    final postData = json['posts'] as Map<String, dynamic>?;

    return SentimentScore(
      id:             json['id'] as String,
      postId:         json['post_id'] as String,
      sentimentLabel: json['sentiment_label'] as String,
      confidence:     (json['confidence'] as num).toDouble(),
      scoredAt:       DateTime.parse(json['scored_at'] as String),
      postedAt:       postData != null
          ? DateTime.parse(postData['posted_at'] as String)
          : null,
      platformId: postData?['platform_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'post_id': postId,
    'sentiment_label': sentimentLabel,
    'confidence': confidence,
    'scored_at': scoredAt.toIso8601String(),
  };
}
