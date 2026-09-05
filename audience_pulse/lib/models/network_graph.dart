/// A node in the influence network graph (represents an author).
class NetworkNode {
  final String id;         // author ID
  final String handle;
  final String? displayName;
  final int followerCount;
  final String platformId;
  final int degree;        // computed: in-degree + out-degree in the network

  const NetworkNode({
    required this.id,
    required this.handle,
    this.displayName,
    required this.followerCount,
    required this.platformId,
    this.degree = 0,
  });

  factory NetworkNode.fromAuthorJson(Map<String, dynamic> json, {int degree = 0}) {
    return NetworkNode(
      id:           json['id'] as String,
      handle:       json['handle'] as String,
      displayName:  json['display_name'] as String?,
      followerCount:(json['follower_count'] as num).toInt(),
      platformId:   json['platform_id'] as String,
      degree:       degree,
    );
  }

  NetworkNode copyWith({int? degree}) => NetworkNode(
    id: id,
    handle: handle,
    displayName: displayName,
    followerCount: followerCount,
    platformId: platformId,
    degree: degree ?? this.degree,
  );
}

/// A directed edge in the influence network graph.
class NetworkEdge {
  final String id;
  final String sourceAuthorId;
  final String targetAuthorId;
  final String interactionType; // 'reply' | 'retweet' | 'mention' | 'forward'
  final int weight;
  final DateTime occurredAt;

  const NetworkEdge({
    required this.id,
    required this.sourceAuthorId,
    required this.targetAuthorId,
    required this.interactionType,
    required this.weight,
    required this.occurredAt,
  });

  factory NetworkEdge.fromJson(Map<String, dynamic> json) {
    return NetworkEdge(
      id:               json['id'] as String,
      sourceAuthorId:   json['source_author_id'] as String,
      targetAuthorId:   json['target_author_id'] as String,
      interactionType:  json['interaction_type'] as String,
      weight:           (json['weight'] as num).toInt(),
      occurredAt:       DateTime.parse(json['occurred_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'source_author_id': sourceAuthorId,
    'target_author_id': targetAuthorId,
    'interaction_type': interactionType,
    'weight': weight,
    'occurred_at': occurredAt.toIso8601String(),
  };
}

/// Container returned by getNetworkGraph().
class NetworkGraph {
  final List<NetworkNode> nodes;
  final List<NetworkEdge> edges;

  const NetworkGraph({required this.nodes, required this.edges});

  /// Returns the top N nodes by degree (Key Opinion Leaders).
  List<NetworkNode> topKols(int n) {
    final sorted = [...nodes]..sort((a, b) => b.degree.compareTo(a.degree));
    return sorted.take(n).toList();
  }
}
