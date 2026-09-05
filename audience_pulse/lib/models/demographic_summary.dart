/// Aggregate demographic breakdown for a platform over a time window.
class DemographicSummary {
  final String id;
  final String? platformId;
  final String ageBracket;
  final String region;
  final String language;
  final String? professionalInterest;
  final int aggregateCount;
  final DateTime computedAt;

  const DemographicSummary({
    required this.id,
    this.platformId,
    required this.ageBracket,
    required this.region,
    required this.language,
    this.professionalInterest,
    required this.aggregateCount,
    required this.computedAt,
  });

  factory DemographicSummary.fromJson(Map<String, dynamic> json) {
    return DemographicSummary(
      id:                   json['id'] as String,
      platformId:           json['platform_id'] as String?,
      ageBracket:           json['age_bracket'] as String,
      region:               json['region'] as String,
      language:             json['language'] as String,
      professionalInterest: json['professional_interest'] as String?,
      aggregateCount:       (json['aggregate_count'] as num).toInt(),
      computedAt:           DateTime.parse(json['computed_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'platform_id': platformId,
    'age_bracket': ageBracket,
    'region': region,
    'language': language,
    'professional_interest': professionalInterest,
    'aggregate_count': aggregateCount,
    'computed_at': computedAt.toIso8601String(),
  };
}
