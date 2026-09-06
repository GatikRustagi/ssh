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
      backgroundColor: AppTheme.background,
      title: 'Sentiment Timeline',
      tooltipMessage: 'Tracks how positive or negative the conversation is over time.',
      icon: Icons.show_chart_rounded,
      panelKey: 'sentiment',
      expandedHeight: 380,
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
  String _selectedEmotion = 'All'; // 'All' or specific emotion
  String _selectedTimeRange = '1D';

  // 5 main emotions
  static const _emotions = [
    'positive', 'negative', 'neutral', 'supportive', 'anxious'
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.scores.isEmpty) {
      return const Center(child: Text('No sentiment data yet.'));
    }

    final now = DateTime.now();
    Duration timeLimit;
    switch (_selectedTimeRange) {
      case '1H': timeLimit = const Duration(hours: 1); break;
      case '1D': timeLimit = const Duration(days: 1); break;
      case '1W': timeLimit = const Duration(days: 7); break;
      case '1M': timeLimit = const Duration(days: 30); break;
      case '1Y': timeLimit = const Duration(days: 365); break;
      case 'ALL': timeLimit = const Duration(days: 3650); break;
      default: timeLimit = const Duration(days: 1); break;
    }

    // Filter ONLY by time (not by emotion, to preserve the timeline axis)
    final timeFilteredScores = widget.scores.where((s) {
      final dt = s.postedAt ?? s.scoredAt;
      if (now.difference(dt) > timeLimit) return false;
      return true;
    }).toList();

    // Group the time-filtered scores
    final grouped = _groupByHourAndLabel(timeFilteredScores);
    if (grouped.isEmpty) return const Center(child: Text('No data to chart.'));

    final sortedHours = grouped.keys.toList()..sort();
    final bool isSinglePoint = sortedHours.length == 1;
    if (isSinglePoint) {
      sortedHours.add('now'); // Dummy X-axis label
    }

    final labelsToDraw = _selectedEmotion == 'All' ? _emotions : [_selectedEmotion];

    final lines = <LineChartBarData>[];
    for (final label in labelsToDraw) {
      final points = sortedHours.asMap().entries.map((e) {
        final bucketKey = (isSinglePoint && e.key == 1) ? sortedHours[0] : e.value;
        final count = (grouped[bucketKey]?[label] ?? 0).toDouble();
        return FlSpot(e.key.toDouble(), count);
      }).toList();

      if (points.every((p) => p.y == 0)) continue;

      final color = AppConstants.sentimentColors[label] ?? AppTheme.textMuted;
      lines.add(LineChartBarData(
        spots: points,
        color: color,
        isCurved: true,
        curveSmoothness: 0.2,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false), // Hide dots by default like CoinDCX
        belowBarData: BarAreaData(
          show: _selectedEmotion != 'All', // Only show fill if single emotion
          color: color.withValues(alpha: 0.1),
        ),
      ));
    }

    return Column(
      children: [
        // Emotion Legend/Filter
        _buildEmotionFilters(context),
        const SizedBox(height: 16),
        // Chart
        Expanded(
          child: lines.isEmpty 
              ? const Center(child: Text('No data for this emotion in the current view.', style: TextStyle(color: AppTheme.textMuted)))
              : LineChart(
                  LineChartData(
                    backgroundColor: Colors.transparent,
                    gridData: const FlGridData(show: false), // Remove grid lines for cleaner look
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(show: false), // Hide axis labels; rely on hover tooltip
                    lineBarsData: lines,
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                        return spotIndexes.map((spotIndex) {
                          return TouchedSpotIndicatorData(
                            FlLine(color: AppTheme.border, strokeWidth: 1, dashArray: [4, 4]),
                            FlDotData(
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: barData.color ?? AppTheme.accent,
                                  strokeWidth: 2,
                                  strokeColor: AppTheme.surfaceHigh,
                                );
                              },
                            ),
                          );
                        }).toList();
                      },
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => AppTheme.surfaceHigh,
                        tooltipRoundedRadius: 8,
                        getTooltipItems: (spots) => spots.map((spot) {
                          final time = sortedHours[spot.x.toInt()];
                          return LineTooltipItem(
                            '${spot.y.toInt()} posts\n',
                            const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: time,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.normal),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        // Time Filters
        _buildTimeFilters(context),
      ],
    );
  }

  Map<String, Map<String, int>> _groupByHourAndLabel(List<SentimentScore> scores) {
    final result = <String, Map<String, int>>{};
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    for (final score in scores) {
      final dt = score.postedAt ?? score.scoredAt;
      final amPm = dt.hour < 12 ? 'AM' : 'PM';
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final monthStr = months[dt.month - 1];
      
      final bucket = '$monthStr ${dt.day}, $h $amPm';
      result.putIfAbsent(bucket, () => {});
      result[bucket]![score.sentimentLabel] =
          (result[bucket]![score.sentimentLabel] ?? 0) + 1;
    }
    return result;
  }

  Widget _buildEmotionFilters(BuildContext context) {
    final List<String> options = ['All', ..._emotions];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((label) {
        final isSelected = _selectedEmotion == label;
        final color = label == 'All' 
            ? AppTheme.textPrimary 
            : (AppConstants.sentimentColors[label] ?? AppTheme.textMuted);
            
        return GestureDetector(
          onTap: () => setState(() => _selectedEmotion = label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color.withValues(alpha: 0.5) : AppTheme.border,
              ),
            ),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: isSelected ? color : AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeFilters(BuildContext context) {
    final ranges = ['1H', '1D', '1W', '1M', '1Y', 'ALL'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ranges.map((range) {
        final isSelected = _selectedTimeRange == range;
        return GestureDetector(
          onTap: () => setState(() => _selectedTimeRange = range),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              range,
              style: TextStyle(
                color: isSelected ? AppTheme.accentLight : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
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

