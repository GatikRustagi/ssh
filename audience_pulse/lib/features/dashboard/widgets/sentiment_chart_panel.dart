import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/sentiment_score.dart';
import '../../../models/analysis_models.dart';
import '../providers/dashboard_providers.dart';
import 'panel_card.dart';

/// Top-left dashboard panel: sentiment-over-time line chart.
/// Color-coded per sentiment label; uses FL Chart LineChart.
class SentimentChartPanel extends ConsumerWidget {
  const SentimentChartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sentimentTimelineProvider);

    final explainer = ref.watch(sentimentExplainerProvider);

    return PanelCard(
      title: 'Sentiment Timeline',
      icon: Icons.show_chart_rounded,
      panelKey: 'sentiment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(message: e.toString()),
              data: (scores) => _SentimentChart(scores: scores),
            ),
          ),
          // ── Because chip ─────────────────────────────────────────────────
          explainer.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (result) => result != null && result.isConfident
                ? _BecauseChip(result: result)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SentimentChart extends StatefulWidget {
  final List<SentimentScore> scores;
  const _SentimentChart({required this.scores});

  @override
  State<_SentimentChart> createState() => _SentimentChartState();
}

class _SentimentChartState extends State<_SentimentChart> {
  String? _touchedLabel;

  // All possible sentiment labels
  static const _labels = [
    'positive', 'negative', 'neutral', 'sarcastic',
    'anxious', 'supportive', 'against',
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.scores.isEmpty) {
      return const Center(child: Text('No sentiment data yet.'));
    }

    // Group scores by hour bucket, then by label
    final grouped = _groupByHourAndLabel(widget.scores);
    if (grouped.isEmpty) return const Center(child: Text('No data to chart.'));

    final sortedHours = grouped.keys.toList()..sort();
    final bool isSinglePoint = sortedHours.length == 1;
    if (isSinglePoint) {
      sortedHours.add('now'); // Dummy X-axis label so we have 2 points to draw a line
    }

    // Build one line per sentiment label
    final lines = <LineChartBarData>[];
    for (final label in _labels) {
      final points = sortedHours.asMap().entries.map((e) {
        // If it's the dummy second point, copy the value from the first point
        final bucketKey = (isSinglePoint && e.key == 1) ? sortedHours[0] : e.value;
        final count = (grouped[bucketKey]?[label] ?? 0).toDouble();
        return FlSpot(e.key.toDouble(), count);
      }).toList();

      if (points.every((p) => p.y == 0)) continue; // skip empty lines

      final color = AppConstants.sentimentColors[label] ?? AppTheme.textMuted;
      lines.add(LineChartBarData(
        spots: points,
        color: color,
        isCurved: !isSinglePoint,
        curveSmoothness: 0.3,
        barWidth: _touchedLabel == label ? 3 : 2,
        isStrokeCapRound: true,
        dotData: FlDotData(show: true),
        belowBarData: BarAreaData(
          show: _touchedLabel == label,
          color: color.withValues(alpha: 0.12),
        ),
      ));
    }

    return Column(
      children: [
        // Legend
        _buildLegend(context),
        const SizedBox(height: 12),
        // Chart
        Expanded(
          child: LineChart(
            LineChartData(
              backgroundColor: Colors.transparent,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppTheme.border,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (val, _) => Text(
                      val.toInt().toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 6,
                    getTitlesWidget: (val, _) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= sortedHours.length) return const SizedBox();
                      return Text(
                        sortedHours[idx],
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: lines,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppTheme.surfaceHigh,
                  getTooltipItems: (spots) => spots.map((spot) {
                    return LineTooltipItem(
                      '${spot.y.toInt()} posts',
                      const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Groups scores into hour-label buckets: { "Sep4 14h": { "positive": 3 } }
  Map<String, Map<String, int>> _groupByHourAndLabel(List<SentimentScore> scores) {
    final result = <String, Map<String, int>>{};
    for (final score in scores) {
      final dt = score.postedAt ?? score.scoredAt;
      final bucket = '${dt.month}/${dt.day} ${dt.hour}h';
      result.putIfAbsent(bucket, () => {});
      result[bucket]![score.sentimentLabel] =
          (result[bucket]![score.sentimentLabel] ?? 0) + 1;
    }
    return result;
  }

  Widget _buildLegend(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: _labels.map((label) {
        final color = AppConstants.sentimentColors[label] ?? AppTheme.textMuted;
        final emoji = AppConstants.sentimentEmoji[label] ?? '';
        return GestureDetector(
          onTap: () => setState(() {
            _touchedLabel = _touchedLabel == label ? null : label;
          }),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$emoji $label',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _touchedLabel == null || _touchedLabel == label
                      ? AppTheme.textSecondary
                      : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Text('Error: $message', style: const TextStyle(color: Color(0xFFEF4444))),
  );
}

/// Displays the dominant-label evidence string from [AnalysisEngine]
/// as a small chip beneath the sentiment timeline.
///
/// Example: "because: matched: excited(+0.9), breakthrough(+0.8)"
class _BecauseChip extends StatelessWidget {
  final SentimentResult result;
  const _BecauseChip({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = AppConstants.sentimentColors[result.label] ?? AppTheme.textMuted;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppConstants.sentimentEmoji[result.label] ?? '',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 5),
            Text(
              '${result.label}  ·  ',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            Flexible(
              child: Text(
                result.because,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

