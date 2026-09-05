/// A rising keyword or topic detected over a time window.
class Trend {
  final String id;
  final String keywordOrTopic;
  final String? platformId;
  final int mentionCount;
  final double growthRate; // e.g. 127.4 means +127.4%
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime createdAt;

  const Trend({
    required this.id,
    required this.keywordOrTopic,
    this.platformId,
    required this.mentionCount,
    required this.growthRate,
    required this.windowStart,
    required this.windowEnd,
    required this.createdAt,
  });

  bool get isRising => growthRate > 0;

  factory Trend.fromJson(Map<String, dynamic> json) {
    return Trend(
      id:              json['id'] as String,
      keywordOrTopic:  json['keyword_or_topic'] as String,
      platformId:      json['platform_id'] as String?,
      mentionCount:    (json['mention_count'] as num).toInt(),
      growthRate:      (json['growth_rate'] as num).toDouble(),
      windowStart:     DateTime.parse(json['window_start'] as String),
      windowEnd:       DateTime.parse(json['window_end'] as String),
      createdAt:       DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'keyword_or_topic': keywordOrTopic,
    'platform_id': platformId,
    'mention_count': mentionCount,
    'growth_rate': growthRate,
    'window_start': windowStart.toIso8601String(),
    'window_end': windowEnd.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}
