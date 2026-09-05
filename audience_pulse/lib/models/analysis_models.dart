/// ============================================================
/// Analysis Models
/// ============================================================
/// Typed result types returned by [AnalysisEngine].
/// These replace the generic Maps previously used by MLStubService.
/// ============================================================
library analysis_models;

/// Result of a rule-based sentiment classification.
class SentimentResult {
  /// One of: positive | negative | neutral | sarcastic | anxious | supportive | against
  final String label;

  /// 0.0 – 1.0 continuous score (higher = stronger signal in that direction)
  final double score;

  /// 0.0 – 1.0 confidence. Low when matched terms are few or contradictory.
  final double confidence;

  /// Human-readable evidence, e.g. "matched: excited(+0.8), great(+0.6)"
  final String because;

  const SentimentResult({
    required this.label,
    required this.score,
    required this.confidence,
    required this.because,
  });

  /// Returns true when the result is meaningful enough to surface in the UI.
  bool get isConfident => confidence >= 0.3;

  @override
  String toString() => 'SentimentResult($label, score=$score, conf=$confidence)';
}

// ── Trend Growth ───────────────────────────────────────────────────────────────

/// Badge shown on trend cards.
enum TrendBadge { rising, stable, declining }

/// Result of a trend-growth calculation.
class TrendGrowthResult {
  /// (recent - baseline) / max(baseline, 1)  — can be negative.
  final double growthRate;

  final TrendBadge badge;

  /// e.g. "22 mentions in last 15 min vs 4 baseline (+450%)"
  final String reason;

  const TrendGrowthResult({
    required this.growthRate,
    required this.badge,
    required this.reason,
  });
}

// ── Coordination Risk ──────────────────────────────────────────────────────────

/// A single observable signal that contributes to coordination risk.
class CoordinationSignal {
  /// Short identifier for the rule that fired, e.g. "duplicate_burst"
  final String ruleId;

  /// User-facing description of the evidence.
  final String evidence;

  /// Weight this signal adds to the total risk score (0.0 – 1.0).
  final double weight;

  const CoordinationSignal({
    required this.ruleId,
    required this.evidence,
    required this.weight,
  });
}

/// Overall risk level for a narrative cluster.
enum RiskLevel { high, medium, low }

/// Result of the coordination-risk computation for a set of posts.
class CoordinationRiskResult {
  /// Narrative label inferred from the dominant hashtag / keyword.
  final String narrativeLabel;

  final RiskLevel riskLevel;

  /// Aggregated 0.0 – 1.0 score (sum of signal weights, clamped).
  final double riskScore;

  /// All signals that fired; empty when risk is low.
  final List<CoordinationSignal> signals;

  /// Start of the detection window.
  final DateTime windowStart;

  /// End of the detection window.
  final DateTime windowEnd;

  const CoordinationRiskResult({
    required this.narrativeLabel,
    required this.riskLevel,
    required this.riskScore,
    required this.signals,
    required this.windowStart,
    required this.windowEnd,
  });

  /// Convenience: true when risk is high.
  bool get isHighRisk => riskLevel == RiskLevel.high;

  /// Short summary for the alert badge, e.g. "14 near-duplicates in 7 min".
  String get shortSummary {
    if (signals.isEmpty) return 'No signals';
    return signals.first.evidence;
  }
}
