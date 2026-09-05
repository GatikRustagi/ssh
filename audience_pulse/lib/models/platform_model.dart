/// Represents a social media platform (X, Telegram, etc.).
class PlatformModel {
  final String id;
  final String name;
  final String status; // 'live' | 'coming_soon'
  final DateTime? lastSyncedAt;
  final DateTime createdAt;

  const PlatformModel({
    required this.id,
    required this.name,
    required this.status,
    this.lastSyncedAt,
    required this.createdAt,
  });

  bool get isLive => status == 'live';

  factory PlatformModel.fromJson(Map<String, dynamic> json) {
    return PlatformModel(
      id:           json['id'] as String,
      name:         json['name'] as String,
      status:       json['status'] as String,
      lastSyncedAt: json['last_synced_at'] != null
          ? DateTime.parse(json['last_synced_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': status,
    'last_synced_at': lastSyncedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}
