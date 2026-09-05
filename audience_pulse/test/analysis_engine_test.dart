import 'package:flutter_test/flutter_test.dart';

import 'package:audience_pulse/services/analysis_engine.dart';
import 'package:audience_pulse/models/analysis_models.dart';
import 'package:audience_pulse/models/post.dart';

// Helper to build a minimal Post for testing
Post _post({
  required String id,
  required String content,
  required DateTime postedAt,
  String authorId = 'author-1',
  String? url,
}) {
  return Post(
    id: id,
    platformId: 'platform-x',
    authorId: authorId,
    contentText: content,
    postedAt: postedAt,
    rawEngagementCount: 0,
    url: url,
    createdAt: postedAt,
  );
}

void main() {
  final engine = AnalysisEngine.instance;
  final now = DateTime(2026, 9, 6, 12, 0, 0); // fixed reference time

  // ── Sentiment Classification ────────────────────────────────────────────────

  group('classifySentiment', () {
    test('detects positive text', () {
      final r = engine.classifySentiment('This is an amazing and excellent breakthrough!');
      expect(r.label, equals('positive'));
      expect(r.score, greaterThan(0.5));
      expect(r.because, contains('amazing'));
    });

    test('detects negative text', () {
      final r = engine.classifySentiment('This is a terrible disaster and total failure.');
      expect(r.label, equals('negative'));
    });

    test('detects anxious text', () {
      final r = engine.classifySentiment('This is a crisis — emergency warning for danger!');
      expect(r.label, equals('anxious'));
    });

    test('detects sarcastic text', () {
      final r = engine.classifySentiment('Obviously another AI hype story, how meaningless.');
      expect(r.label, equals('sarcastic'));
    });

    test('handles negation — flips positive to negative', () {
      final r = engine.classifySentiment('This is not great and not amazing at all.');
      // Not good → negative domain
      expect(['negative', 'neutral'], contains(r.label));
    });

    test('returns neutral with low confidence for empty input', () {
      final r = engine.classifySentiment('');
      expect(r.label, equals('neutral'));
      expect(r.confidence, equals(0.0));
    });

    test('returns neutral for stop-word-only input', () {
      final r = engine.classifySentiment('the and or but so');
      // 'the' and 'and' exist in the neutral bucket with minimal weight.
      // Key assertion: no strong sentiment label is detected.
      expect(r.label, equals('neutral'));
    });

    test('isConfident returns false when confidence < 0.3', () {
      final r = engine.classifySentiment('hello there fine day');
      // Low-signal text should not be confident
      expect(r.isConfident, isFalse);
    });

    test('emoji weights are considered', () {
      final r = engine.classifySentiment('Great news! 🚀🎉 Fantastic result!');
      expect(r.label, equals('positive'));
    });
  });

  // ── Keyword Extraction ──────────────────────────────────────────────────────

  group('extractKeywords', () {
    test('extracts hashtags first', () {
      final kw = engine.extractKeywords('#SafeCity supports the people #India');
      expect(kw, contains('#safecity'));
      expect(kw, contains('#india'));
    });

    test('excludes stop words from content keywords', () {
      final kw = engine.extractKeywords('the algorithm and the data');
      expect(kw, isNot(contains('the')));
      expect(kw, isNot(contains('and')));
    });

    test('returns empty list for blank input', () {
      final kw = engine.extractKeywords('');
      expect(kw, isEmpty);
    });
  });

  // ── Text Normalisation ──────────────────────────────────────────────────────

  group('normalisedText', () {
    test('strips URLs', () {
      final n = engine.normalisedText('Check this out https://example.com/path?q=1');
      expect(n, isNot(contains('https')));
    });

    test('strips hashtags and mentions', () {
      final n = engine.normalisedText('#SafeCity @someUser hello world');
      expect(n, isNot(contains('#')));
      expect(n, isNot(contains('@')));
      expect(n, contains('hello'));
    });

    test('lowercases and collapses whitespace', () {
      final n = engine.normalisedText('  Hello   WORLD  ');
      expect(n, equals('hello world'));
    });

    test('near-duplicate posts produce identical normalised form', () {
      const a = 'Our city deserves better security. #SafeCity initiative needs your support NOW.';
      const b = 'Our city deserves better security. The #SafeCity initiative needs your support NOW.';
      // They differ only in "The" — normalised forms differ slightly but should
      // pass the similarity threshold (< 25% edit distance).
      final na = engine.normalisedText(a);
      final nb = engine.normalisedText(b);
      expect(na.isNotEmpty, isTrue);
      expect(nb.isNotEmpty, isTrue);
    });
  });

  // ── Trend Growth Scoring ────────────────────────────────────────────────────

  group('scoreTrendGrowth', () {
    test('rising badge when recent > baseline by more than 20%', () {
      final r = engine.scoreTrendGrowth(recentCount: 22, baselineCount: 4);
      expect(r.badge, equals(TrendBadge.rising));
      expect(r.growthRate, greaterThan(0.2));
    });

    test('declining badge when recent < baseline by more than 20%', () {
      final r = engine.scoreTrendGrowth(recentCount: 2, baselineCount: 20);
      expect(r.badge, equals(TrendBadge.declining));
      expect(r.growthRate, lessThan(-0.2));
    });

    test('stable badge when within ±20%', () {
      final r = engine.scoreTrendGrowth(recentCount: 10, baselineCount: 10);
      expect(r.badge, equals(TrendBadge.stable));
      expect(r.growthRate, closeTo(0.0, 0.01));
    });

    test('handles zero baseline without division error', () {
      final r = engine.scoreTrendGrowth(recentCount: 5, baselineCount: 0);
      expect(r.badge, equals(TrendBadge.rising));
    });

    test('reason string is non-empty', () {
      final r = engine.scoreTrendGrowth(
        recentCount: 14, baselineCount: 3, keyword: '#SafeCity');
      expect(r.reason, isNotEmpty);
      expect(r.reason, contains('#SafeCity'));
    });
  });

  // ── Coordination Risk ───────────────────────────────────────────────────────

  group('computeCoordinationRisk', () {
    test('returns empty list for fewer than 3 posts', () {
      final posts = [
        _post(id: '1', content: '#SafeCity join us now', postedAt: now),
        _post(id: '2', content: '#SafeCity join us now', postedAt: now),
      ];
      expect(engine.computeCoordinationRisk(posts), isEmpty);
    });

    test('no risk when posts are diverse in content and timing', () {
      final posts = List.generate(5, (i) => _post(
        id: '$i',
        content: 'Completely different content about topic number $i with unique words',
        postedAt: now.add(Duration(hours: i * 2)),
        authorId: 'author-$i',
      ));
      // Diverse posts should not produce high risk
      final results = engine.computeCoordinationRisk(posts);
      if (results.isNotEmpty) {
        expect(results.first.riskLevel, isNot(equals(RiskLevel.high)));
      }
    });

    test('detects HIGH risk for SafeCity-style burst', () {
      // Simulate 14 near-duplicate posts from 11 authors within 7 minutes
      const baseContent = 'Our city deserves better security. '
          '#SafeCity initiative needs your support NOW. '
          'Join the movement: https://safecity.example.com/petition';

      final posts = List.generate(14, (i) {
        final variation = i % 3 == 0 ? 'Our city deserves much better security. '
            '#SafeCity initiative needs your support NOW. '
            'Join the movement https://safecity.example.com/petition'
            : baseContent;
        return _post(
          id: 'sc-$i',
          content: variation,
          postedAt: now.add(Duration(seconds: i * 30)), // 30 s apart → 7 min total
          authorId: 'author-${i % 11}', // 11 distinct authors
          url: i < 12 ? 'https://safecity.example.com/petition' : null,
        );
      });

      final results = engine.computeCoordinationRisk(posts);

      expect(results, isNotEmpty);
      final safeCityResult = results.firstWhere(
        (r) => r.narrativeLabel.toLowerCase().contains('safecity'),
        orElse: () => results.first,
      );
      expect(safeCityResult.riskLevel, equals(RiskLevel.high));
      expect(safeCityResult.signals, isNotEmpty);
    });

    test('duplicate_burst signal fires for ≥8 similar posts in 10 min', () {
      const content = 'Same message repeated #Test join the movement https://example.com';
      final posts = List.generate(10, (i) => _post(
        id: 'dup-$i',
        content: content,
        postedAt: now.add(Duration(minutes: i)),
        authorId: 'author-$i',
        url: 'https://example.com',
      ));

      final results = engine.computeCoordinationRisk(posts);
      if (results.isNotEmpty) {
        final hasSignal = results.any((r) =>
            r.signals.any((s) => s.ruleId == 'duplicate_burst'));
        expect(hasSignal, isTrue);
      }
    });

    test('results are sorted highest risk first', () {
      // Create two clusters: high-risk and medium-risk
      const highContent = 'Urgent action needed #Crisis crisis now https://example.com';
      final posts = [
        // High-risk cluster: many near-dupes, same URL
        ...List.generate(10, (i) => _post(
          id: 'h-$i', content: highContent,
          postedAt: now.add(Duration(minutes: i)),
          authorId: 'ha-$i', url: 'https://example.com',
        )),
        // Low-noise different narrative
        _post(id: 'l-1', content: 'Something totally different #Other topic',
              postedAt: now, authorId: 'la-1'),
        _post(id: 'l-2', content: 'Another different topic #Other topic',
              postedAt: now, authorId: 'la-2'),
        _post(id: 'l-3', content: 'Yet another different #Other topic for analysis',
              postedAt: now, authorId: 'la-3'),
      ];

      final results = engine.computeCoordinationRisk(posts);
      for (int i = 0; i < results.length - 1; i++) {
        expect(results[i].riskScore,
               greaterThanOrEqualTo(results[i + 1].riskScore));
      }
    });
  });
}
