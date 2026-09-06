import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../models/trend.dart';
import '../../../services/analysis_engine.dart';
import '../providers/dashboard_providers.dart';
import 'panel_card.dart';

/// Top-right dashboard panel: ranked trending keywords/topics.
class TrendsPanel extends ConsumerWidget {
  const TrendsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topTrendsProvider);
    final filter = ref.watch(trendSentimentFilterProvider);

    return PanelCard(
      backgroundColor: AppTheme.background,
      title: 'Top Trends',
      icon: Icons.trending_up_rounded,
      panelKey: 'trends',
      expandedHeight: 380,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: filter,
                    dropdownColor: AppTheme.surfaceHigh,
                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 16),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.w600),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('ALL TRENDS')),
                      DropdownMenuItem(value: 'Positive', child: Text('POSITIVE')),
                      DropdownMenuItem(value: 'Negative', child: Text('NEGATIVE')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(trendSentimentFilterProvider.notifier).state = val;
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Color(0xFFEF4444)))),
              data: (trends) {
                final filtered = trends.where((t) {
                  if (filter == 'All') return true;
                  final result = AnalysisEngine.instance.classifySentiment(t.keywordOrTopic);
                  if (filter == 'Positive') return result.label == 'positive' || result.label == 'supportive';
                  if (filter == 'Negative') return result.label == 'negative' || result.label == 'anxious' || result.label == 'against';
                  return true;
                }).toList();
                return _TrendsList(trends: filtered);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendsList extends StatelessWidget {
  final List<Trend> trends;
  const _TrendsList({required this.trends});

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) {
      return const Center(child: Text('No trends detected yet.'));
    }

    return ListView.separated(
      itemCount: trends.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => _TrendTile(trend: trends[i], rank: i + 1),
    );
  }
}

class _TrendTile extends ConsumerWidget {
  final Trend trend;
  final int rank;
  const _TrendTile({required this.trend, required this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentiment = AnalysisEngine.instance.classifySentiment(trend.keywordOrTopic);
    final isNegative = sentiment.label == 'negative' || sentiment.label == 'anxious' || sentiment.label == 'against';
    final displayRate = trend.growthRate.abs();
    final isRising = !isNegative;
    final growthColor = isRising ? AppTheme.sentimentPositive : AppTheme.sentimentNegative;

    // Rank badge color: top 3 get accent, rest get muted
    final rankColor = rank <= 3 ? AppTheme.accent : AppTheme.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: rankColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Topic / keyword
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trend.keywordOrTopic,
                  style: Theme.of(context).textTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppUtils.compactNumber(trend.mentionCount)} mentions',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Save Button
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            color: AppTheme.textSecondary,
            tooltip: 'Save trend',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              ref.read(savedTrendsProvider.notifier).saveTrend(trend);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Saved "${trend.keywordOrTopic}" to investigations.'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: AppTheme.surfaceHigh,
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Growth rate indicator
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: growthColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: growthColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRising ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 14,
                      color: growthColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isRising ? '+' : '-'}${displayRate.toStringAsFixed(1)}% past 1 day',
                      style: TextStyle(
                        color: growthColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
