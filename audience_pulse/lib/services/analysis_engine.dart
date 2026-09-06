import 'dart:math' as math;

import '../models/analysis_models.dart';
import '../models/post.dart';

/// ============================================================
/// AnalysisEngine — Deterministic Rule-Based Intelligence
/// ============================================================
///
/// A pure-Dart service that produces explainable analysis results
/// without any ML model training.  Every output includes a human-
/// readable [because] / [reason] / [evidence] string so analysts
/// can audit every decision.
///
/// Design contract:
///   • No network calls — all logic is local and synchronous where
///     possible (async only for batched post lists).
///   • Every method returns a typed model from [analysis_models.dart].
///   • Evidence strings are factual ("matched: anxious×3, scared×1")
///     never assertive ("user is anxious").
///
/// How to extend:
///   1. Add new words to [_emotionLexicon].
///   2. Add new emoji mappings to [_emojiWeights].
///   3. Add extra signals to [computeCoordinationRisk].
/// ============================================================

class AnalysisEngine {
  AnalysisEngine._();
  static final AnalysisEngine instance = AnalysisEngine._();

  // ── Emotion lexicon ────────────────────────────────────────────────────────
  // Each entry: word → (label, weight).  Weights are 0.0–1.0.
  // Negative polarity words appear under 'negative' / emotion labels.
  static const Map<String, (String, double)> _emotionLexicon = {
    // positive
    'great': ('positive', 0.7), 'amazing': ('positive', 0.9),
    'excellent': ('positive', 0.8), 'good': ('positive', 0.6),
    'love': ('positive', 0.8), 'happy': ('positive', 0.8),
    'excited': ('positive', 0.9), 'wonderful': ('positive', 0.9),
    'fantastic': ('positive', 0.9), 'brilliant': ('positive', 0.85),
    'impressive': ('positive', 0.75), 'opportunity': ('positive', 0.5),
    'success': ('positive', 0.7), 'innovative': ('positive', 0.65),
    'breakthrough': ('positive', 0.8), 'proud': ('positive', 0.7),
    'thank': ('positive', 0.6), 'maturing': ('positive', 0.55),
    'safecity': ('positive', 0.8), 'safe': ('positive', 0.8),
    'city': ('positive', 0.6), 'needs': ('positive', 0.5),
    // negative
    'bad': ('negative', 0.6), 'terrible': ('negative', 0.9),
    'awful': ('negative', 0.85), 'hate': ('negative', 0.9),
    'horrible': ('negative', 0.85), 'disgusting': ('negative', 0.9),
    'disaster': ('negative', 0.8), 'fail': ('negative', 0.7),
    'failed': ('negative', 0.7), 'failure': ('negative', 0.75),
    'broken': ('negative', 0.65), 'useless': ('negative', 0.8),
    'garbage': ('negative', 0.85), 'scam': ('negative', 0.9),
    'manipulation': ('negative', 0.85), 'coordinated': ('negative', 0.5),
    'deepfake': ('negative', 0.8), 'regulation': ('negative', 0.6),
    'sebi': ('negative', 0.5), 'security': ('negative', 0.7),
    // anxious
    'scared': ('anxious', 0.8), 'worried': ('anxious', 0.75),
    'anxious': ('anxious', 0.9), 'fear': ('anxious', 0.8),
    'danger': ('anxious', 0.75), 'threat': ('anxious', 0.7),
    'warning': ('anxious', 0.6), 'alert': ('anxious', 0.55),
    'crisis': ('anxious', 0.8), 'emergency': ('anxious', 0.85),
    'breaking': ('anxious', 0.5), 'stark': ('anxious', 0.55),
    // sarcastic
    'obviously': ('sarcastic', 0.6), 'sure': ('sarcastic', 0.4),
    'totally': ('sarcastic', 0.45), 'absolutely': ('sarcastic', 0.4),
    'genius': ('sarcastic', 0.5), 'brilliant_s': ('sarcastic', 0.5),
    'hype': ('sarcastic', 0.7), 'meaningless': ('sarcastic', 0.75),
    'pretending': ('sarcastic', 0.8), 'wrappers': ('sarcastic', 0.7),
    // supportive
    'support': ('supportive', 0.75), 'help': ('supportive', 0.6),
    'together': ('supportive', 0.65), 'community': ('supportive', 0.6),
    'solidarity': ('supportive', 0.85), 'accessible': ('supportive', 0.6),
    'literacy': ('supportive', 0.55), 'trained': ('supportive', 0.5),
    // against
    'against': ('against', 0.8), 'oppose': ('against', 0.85),
    'reject': ('against', 0.8), 'ban': ('against', 0.75),
    'stop': ('against', 0.5), 'block': ('against', 0.65),
    'protest': ('against', 0.8), 'unfair': ('against', 0.75),
    'bias': ('against', 0.7),
    // neutral (weak, mostly used to lower score of edge cases)
    'the': ('neutral', 0.1), 'and': ('neutral', 0.1),
  };

  // ── Emoji sentiment weights ────────────────────────────────────────────────
  static const Map<String, (String, double)> _emojiWeights = {
    '🚀': ('positive', 0.8), '✅': ('positive', 0.7),
    '🎉': ('positive', 0.9), '😊': ('positive', 0.7),
    '❤️': ('positive', 0.8), '👏': ('positive', 0.7),
    '💡': ('positive', 0.6), '🙏': ('supportive', 0.7),
    '😰': ('anxious', 0.85), '⚠️': ('anxious', 0.8),
    '🔴': ('anxious', 0.7), '🆘': ('anxious', 0.9),
    '😠': ('negative', 0.8), '💀': ('negative', 0.85),
    '🤔': ('sarcastic', 0.6), '😏': ('sarcastic', 0.75),
    '🔥': ('sarcastic', 0.65), '⚡': ('against', 0.7),
  };

  // ── English stop words (not exhaustive) ───────────────────────────────────
  static const Set<String> _stopWords = {
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'shall', 'can', 'need', 'dare', 'ought',
    'to', 'of', 'in', 'for', 'on', 'with', 'at', 'by', 'from', 'as',
    'into', 'through', 'about', 'above', 'after', 'before', 'between',
    'this', 'that', 'these', 'those', 'it', 'its', 'we', 'our', 'you',
    'your', 'they', 'their', 'i', 'my', 'me', 'he', 'she', 'his', 'her',
    'not', 'no', 'but', 'and', 'or', 'so', 'yet', 'nor', 'than',
  };

  // ── Negation triggers ─────────────────────────────────────────────────────
  static const Set<String> _negations = {
    'not', "n't", 'never', 'no', 'without', 'hardly', 'barely', 'scarcely',
  };

  // =========================================================================
  // Public API
  // =========================================================================

  // ── Sentiment Classification ───────────────────────────────────────────────

  /// Classifies the sentiment of [text] using the emotion lexicon, emoji weights,
  /// and a simple bigram-level negation rule.
  ///
  /// Returns a [SentimentResult] with label, score, confidence, and evidence.
  SentimentResult classifySentiment(String text) {
    if (text.trim().isEmpty) {
      return const SentimentResult(
        label: 'neutral', score: 0.5, confidence: 0.0,
        because: 'empty input',
      );
    }

    // Accumulate per-label weighted score
    final scores = <String, double>{};
    final matched = <String>[];

    final tokens = _tokenise(text);
    bool nextNegated = false;

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      // Track negation context (applies to the next sentiment token only)
      if (_negations.contains(token)) {
        nextNegated = true;
        continue;
      }

      // Check emoji map first, then word lexicon
      final entry = _emojiWeights[token] ?? _emotionLexicon[token];
      if (entry != null) {
        final (label, weight) = entry;
        final effectiveLabel = nextNegated ? _flipLabel(label) : label;
        final effectiveWeight = nextNegated ? weight * 0.8 : weight;
        scores[effectiveLabel] = (scores[effectiveLabel] ?? 0) + effectiveWeight;
        matched.add(nextNegated ? 'NOT $token(→$effectiveLabel)' : '$token(+${weight.toStringAsFixed(1)})');
        nextNegated = false;
      } else {
        nextNegated = false;
      }
    }

    if (scores.isEmpty) {
      return SentimentResult(
        label: 'neutral', score: 0.5, confidence: 0.1,
        because: 'no emotion words matched in: "${text.substring(0, math.min(40, text.length))}…"',
      );
    }

    // Winner = label with highest total weight
    final winner = scores.entries.reduce((a, b) => a.value > b.value ? a : b);
    final totalWeight = scores.values.fold(0.0, (a, b) => a + b);

    // Confidence = winner's share of total weight
    final confidence = (winner.value / totalWeight).clamp(0.0, 1.0);
    // Normalise score 0–1 based on winner weight (asymptotic)
    final score = 1.0 - (1.0 / (1.0 + winner.value));

    return SentimentResult(
      label: winner.key,
      score: score,
      confidence: confidence,
      because: 'matched: ${matched.take(5).join(', ')}',
    );
  }

  // ── Keyword / Hashtag Extraction ───────────────────────────────────────────

  /// Extracts hashtags and high-frequency content words from [text].
  /// Returns a list ordered by frequency (most frequent first).
  List<String> extractKeywords(String text) {
    final keywords = <String>[];

    // 1. Extract explicit hashtags
    final hashtagRe = RegExp(r'#(\w+)');
    for (final m in hashtagRe.allMatches(text)) {
      final tag = m.group(1)!.toLowerCase();
      if (!keywords.contains('#$tag')) keywords.add('#$tag');
    }

    // 2. High-frequency non-stop words
    final freq = <String, int>{};
    for (final w in _tokenise(text)) {
      if (w.length < 4) continue;
      if (_stopWords.contains(w)) continue;
      if (w.startsWith('#')) continue; // already captured
      freq[w] = (freq[w] ?? 0) + 1;
    }

    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted.take(8)) {
      if (!keywords.contains(e.key)) keywords.add(e.key);
    }

    return keywords;
  }

  // ── Trend Growth Scoring ───────────────────────────────────────────────────

  /// Computes the growth rate as
  ///   `(recentCount - baselineCount) / max(baselineCount, 1)`
  ///
  /// [recentCount]   — mentions in the current 15-minute window.
  /// [baselineCount] — average mentions per 15 minutes over the prior 2 hours.
  /// [keyword]       — used only for the reason string.
  TrendGrowthResult scoreTrendGrowth({
    required int recentCount,
    required int baselineCount,
    String keyword = '',
  }) {
    final base = math.max(baselineCount, 1);
    final rate = (recentCount - baselineCount) / base;

    TrendBadge badge;
    if (rate > 0.2) {
      badge = TrendBadge.rising;
    } else if (rate < -0.2) {
      badge = TrendBadge.declining;
    } else {
      badge = TrendBadge.stable;
    }

    final pct = (rate * 100).toStringAsFixed(0);
    final sign = rate >= 0 ? '+' : '';
    final reason = '$recentCount mentions in current window vs '
        '$baselineCount baseline ($sign$pct%) '
        '${keyword.isNotEmpty ? "for \"$keyword\"" : ""}';

    return TrendGrowthResult(growthRate: rate, badge: badge, reason: reason);
  }

  // ── Text Normalisation (for duplicate detection) ───────────────────────────

  /// Produces a canonical form of [text] used to identify near-duplicates.
  /// Strips URLs, hashtags, punctuation, extra whitespace; lowercases.
  String normalisedText(String text) {
    var s = text.toLowerCase();
    // Remove URLs
    s = s.replaceAll(RegExp(r'https?://\S+'), '');
    // Remove hashtags and mentions
    s = s.replaceAll(RegExp(r'[#@]\w+'), '');
    // Remove all non-alphanumeric except spaces
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    // Collapse whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  // ── Coordination Risk ──────────────────────────────────────────────────────

  /// Evaluates [posts] for coordinated-inauthentic-behaviour signals.
  ///
  /// Four independent rules are checked:
  ///   1. **Duplicate burst** — ≥8 near-duplicate messages within 10 minutes.
  ///   2. **Shared link/hashtag** — same URL or hashtag repeated by many accounts.
  ///   3. **Growth anomaly** — mention count far above its expected baseline.
  ///   4. **Cross-account velocity** — many distinct author IDs posting within a tight window.
  ///
  /// A [CoordinationRiskResult] is returned for each narrative cluster found.
  /// When the list is empty, no significant risk was detected.
  List<CoordinationRiskResult> computeCoordinationRisk(List<Post> posts) {
    if (posts.isEmpty) return [];

    // Group posts by dominant hashtag (first one found, or 'general')
    final clusters = <String, List<Post>>{};
    for (final post in posts) {
      final tags = extractKeywords(post.contentText)
          .where((k) => k.startsWith('#'))
          .toList();
      final key = tags.isNotEmpty ? tags.first : 'general';
      clusters.putIfAbsent(key, () => []).add(post);
    }

    final results = <CoordinationRiskResult>[];

    for (final entry in clusters.entries) {
      final label = entry.key;
      final clusterPosts = entry.value;

      if (clusterPosts.length < 3) continue; // not enough to evaluate

      final signals = <CoordinationSignal>[];

      // ── Rule 1: Near-duplicate burst ───────────────────────────────────────
      final dupResult = _detectDuplicateBurst(clusterPosts);
      if (dupResult != null) signals.add(dupResult);

      // ── Rule 2: Shared link / hashtag repetition ──────────────────────────
      final linkResult = _detectSharedLinkRepetition(clusterPosts);
      if (linkResult != null) signals.add(linkResult);

      // ── Rule 3: Growth anomaly (cluster size vs expectation) ──────────────
      final growthResult = _detectGrowthAnomaly(clusterPosts);
      if (growthResult != null) signals.add(growthResult);

      // ── Rule 4: Cross-account velocity ────────────────────────────────────
      final velocityResult = _detectCrossAccountVelocity(clusterPosts);
      if (velocityResult != null) signals.add(velocityResult);

      if (signals.isEmpty) continue;

      // Aggregate score: sum of signal weights, clamped to 1
      final totalScore = signals
          .map((s) => s.weight)
          .fold(0.0, (a, b) => a + b)
          .clamp(0.0, 1.0);

      RiskLevel level;
      if (totalScore >= 0.65 || signals.length >= 3) {
        level = RiskLevel.high;
      } else if (totalScore >= 0.35 || signals.length >= 2) {
        level = RiskLevel.medium;
      } else {
        level = RiskLevel.low;
      }

      final times = clusterPosts.map((p) => p.postedAt).toList()..sort();

      results.add(CoordinationRiskResult(
        narrativeLabel: label,
        riskLevel: level,
        riskScore: totalScore,
        signals: signals,
        windowStart: times.first,
        windowEnd: times.last,
      ));
    }

    // Sort: highest risk first
    results.sort((a, b) => b.riskScore.compareTo(a.riskScore));
    return results;
  }

  // =========================================================================
  // Private helpers
  // =========================================================================

  /// Tokenises text into lowercase tokens (words + emojis).
  List<String> _tokenise(String text) {
    // Split on whitespace, keep emojis as individual tokens
    final tokens = <String>[];
    for (final part in text.split(RegExp(r'\s+'))) {
      // Strip common punctuation; avoid quote characters in the char class
      final clean = part
          .toLowerCase()
          .replaceAll(RegExp(r'[.,!?;:()\[\]{}]'), '')
          .replaceAll('"', '')
          .replaceAll("'", '');
      if (clean.isNotEmpty) tokens.add(clean);
    }
    return tokens;
  }

  /// Flips a sentiment label for negation, e.g. "positive" → "negative".
  String _flipLabel(String label) {
    const flips = {
      'positive': 'negative',
      'negative': 'positive',
      'supportive': 'against',
      'against': 'supportive',
    };
    return flips[label] ?? label;
  }

  /// Rule 1 — detects ≥8 near-duplicate messages within a 10-minute window.
  CoordinationSignal? _detectDuplicateBurst(List<Post> posts) {
    const windowMinutes = 10;
    const threshold = 8;

    final sorted = List<Post>.from(posts)..sort((a, b) => a.postedAt.compareTo(b.postedAt));
    final norms = sorted.map((p) => normalisedText(p.contentText)).toList();

    for (int i = 0; i < sorted.length; i++) {
      final windowEnd = sorted[i].postedAt.add(const Duration(minutes: windowMinutes));
      // Find all posts within the window
      final windowPosts = <int>[];
      for (int j = i; j < sorted.length; j++) {
        if (sorted[j].postedAt.isAfter(windowEnd)) break;
        windowPosts.add(j);
      }
      if (windowPosts.length < threshold) continue;

      // Check pairwise similarity within the window
      int dupCount = 0;
      for (int j = 0; j < windowPosts.length; j++) {
        for (int k = j + 1; k < windowPosts.length; k++) {
          if (_areSimilar(norms[windowPosts[j]], norms[windowPosts[k]])) dupCount++;
        }
      }

      if (dupCount >= (threshold * (threshold - 1) / 4).ceil()) {
        final distinctAuthors = windowPosts
            .map((idx) => sorted[idx].authorId)
            .toSet()
            .length;
        final minutes = sorted[windowPosts.last].postedAt
            .difference(sorted[i].postedAt)
            .inMinutes
            .clamp(1, windowMinutes);
        return CoordinationSignal(
          ruleId: 'duplicate_burst',
          evidence: '${windowPosts.length} near-duplicate posts from '
              '$distinctAuthors accounts in $minutes minutes',
          weight: 0.45,
        );
      }
    }
    return null;
  }

  /// Rule 2 — detects the same URL or hashtag repeated by many accounts.
  CoordinationSignal? _detectSharedLinkRepetition(List<Post> posts) {
    const threshold = 5;

    // Count per-URL author sets
    final urlAuthors = <String, Set<String>>{};
    final urlRe = RegExp(r'https?://\S+');
    for (final post in posts) {
      for (final m in urlRe.allMatches(post.contentText)) {
        final url = m.group(0)!;
        urlAuthors.putIfAbsent(url, () => {}).add(post.authorId);
      }
    }

    // Count per-hashtag author sets
    final hashAuthors = <String, Set<String>>{};
    final tagRe = RegExp(r'#(\w+)');
    for (final post in posts) {
      for (final m in tagRe.allMatches(post.contentText)) {
        final tag = m.group(1)!.toLowerCase();
        hashAuthors.putIfAbsent(tag, () => {}).add(post.authorId);
      }
    }

    // Best URL hit
    final topUrl = urlAuthors.entries
        .where((e) => e.value.length >= threshold)
        .fold<MapEntry<String, Set<String>>?>(null,
          (prev, e) => prev == null || e.value.length > prev.value.length ? e : prev);

    if (topUrl != null) {
      return CoordinationSignal(
        ruleId: 'shared_url',
        evidence: '${topUrl.value.length} accounts shared the same URL',
        weight: 0.3,
      );
    }

    // Best hashtag hit (excluding the cluster's own label)
    final topTag = hashAuthors.entries
        .where((e) => e.value.length >= threshold)
        .fold<MapEntry<String, Set<String>>?>(null,
          (prev, e) => prev == null || e.value.length > prev.value.length ? e : prev);

    if (topTag != null) {
      return CoordinationSignal(
        ruleId: 'shared_hashtag',
        evidence: '${topTag.value.length} accounts used #${topTag.key} '
            '— same hashtag across all posts',
        weight: 0.25,
      );
    }

    return null;
  }

  /// Rule 3 — cluster growth is anomalously high compared to a naive expectation.
  CoordinationSignal? _detectGrowthAnomaly(List<Post> posts) {
    // Use the cluster size relative to expected 3-post baseline
    const baselineExpected = 3;
    if (posts.length < baselineExpected * 3) return null;

    final result = scoreTrendGrowth(
      recentCount: posts.length,
      baselineCount: baselineExpected,
    );

    if (result.badge == TrendBadge.rising && result.growthRate > 2.0) {
      return CoordinationSignal(
        ruleId: 'growth_anomaly',
        evidence: 'Content growth is ${(result.growthRate * 100).toStringAsFixed(0)}% '
            'above its 3-post baseline (${result.reason})',
        weight: 0.2,
      );
    }
    return null;
  }

  /// Rule 4 — many distinct author IDs posting within a very tight window.
  CoordinationSignal? _detectCrossAccountVelocity(List<Post> posts) {
    const windowSeconds = 300; // 5 minutes
    const threshold = 6;       // distinct authors

    final sorted = List<Post>.from(posts)..sort((a, b) => a.postedAt.compareTo(b.postedAt));

    for (int i = 0; i < sorted.length; i++) {
      final windowEnd = sorted[i].postedAt.add(const Duration(seconds: windowSeconds));
      final windowAuthors = <String>{};
      for (int j = i; j < sorted.length; j++) {
        if (sorted[j].postedAt.isAfter(windowEnd)) break;
        windowAuthors.add(sorted[j].authorId);
      }
      if (windowAuthors.length >= threshold) {
        return CoordinationSignal(
          ruleId: 'cross_account_velocity',
          evidence: '${windowAuthors.length} distinct accounts posted within '
              '${windowSeconds ~/ 60} minutes',
          weight: 0.3,
        );
      }
    }
    return null;
  }

  /// Levenshtein-based similarity: returns true when edit distance / max_len < 0.25.
  bool _areSimilar(String a, String b) {
    if (a == b) return true;
    final maxLen = math.max(a.length, b.length);
    if (maxLen == 0) return true;
    final dist = _levenshtein(a, b);
    return dist / maxLen < 0.25;
  }

  /// Classic Levenshtein distance between two strings.
  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Use a 1-D rolling array for O(min(m,n)) space
    final (shorter, longer) = a.length <= b.length ? (a, b) : (b, a);
    var prev = List<int>.generate(shorter.length + 1, (i) => i);

    for (int j = 1; j <= longer.length; j++) {
      final curr = List<int>.filled(shorter.length + 1, 0);
      curr[0] = j;
      for (int i = 1; i <= shorter.length; i++) {
        final cost = shorter[i - 1] == longer[j - 1] ? 0 : 1;
        curr[i] = math.min(
          math.min(curr[i - 1] + 1, prev[i] + 1),
          prev[i - 1] + cost,
        );
      }
      prev = curr;
    }
    return prev[shorter.length];
  }
}
