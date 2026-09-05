/// Represents a social media author / account.
class Author {
  final String id;
  final String platformId;
  final String handle;
  final String? displayName;
  final String? bioText;
  final String? inferredLanguage;
  final String? inferredRegion;
  final String? inferredAgeBracket;
  final int followerCount;
  final DateTime createdAt;

  const Author({
    required this.id,
    required this.platformId,
    required this.handle,
    this.displayName,
    this.bioText,
    this.inferredLanguage,
    this.inferredRegion,
    this.inferredAgeBracket,
    required this.followerCount,
    required this.createdAt,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id:                  json['id'] as String,
      platformId:          json['platform_id'] as String,
      handle:              json['handle'] as String,
      displayName:         json['display_name'] as String?,
      bioText:             json['bio_text'] as String?,
      inferredLanguage:    json['inferred_language'] as String?,
      inferredRegion:      json['inferred_region'] as String?,
      inferredAgeBracket:  json['inferred_age_bracket'] as String?,
      followerCount:       (json['follower_count'] as num).toInt(),
      createdAt:           DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'platform_id': platformId,
    'handle': handle,
    'display_name': displayName,
    'bio_text': bioText,
    'inferred_language': inferredLanguage,
    'inferred_region': inferredRegion,
    'inferred_age_bracket': inferredAgeBracket,
    'follower_count': followerCount,
    'created_at': createdAt.toIso8601String(),
  };
}
