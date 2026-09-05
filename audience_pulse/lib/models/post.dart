/// Represents a single social media post / message.
class Post {
  final String id;
  final String platformId;
  final String authorId;
  final String contentText;
  final DateTime postedAt;
  final int rawEngagementCount;
  final String? url;
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.platformId,
    required this.authorId,
    required this.contentText,
    required this.postedAt,
    required this.rawEngagementCount,
    this.url,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id:                  json['id'] as String,
      platformId:          json['platform_id'] as String,
      authorId:            json['author_id'] as String,
      contentText:         json['content_text'] as String,
      postedAt:            DateTime.parse(json['posted_at'] as String),
      rawEngagementCount:  (json['raw_engagement_count'] as num).toInt(),
      url:                 json['url'] as String?,
      createdAt:           DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'platform_id': platformId,
    'author_id': authorId,
    'content_text': contentText,
    'posted_at': postedAt.toIso8601String(),
    'raw_engagement_count': rawEngagementCount,
    'url': url,
    'created_at': createdAt.toIso8601String(),
  };
}
