import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../models/trend.dart';
import '../providers/dashboard_providers.dart';
import 'panel_card.dart';

/// Top-right dashboard panel: ranked trending keywords/topics.
class TrendsPanel extends ConsumerWidget {
  const TrendsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topTrendsProvider);

    return PanelCard(
        backgroundColor: AppTheme.background,
        title: 'Top Trends',
      icon: Icons.trending_up_rounded,
      panelKey: 'trends',
      expandedHeight: 380,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e',
            style: const TextStyle(color: Color(0xFFEF4444)))),
        data: (trends) => _TrendsList(trends: trends),
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

class _TrendTile extends StatelessWidget {
  final Trend trend;
  final int rank;
  const _TrendTile({required this.trend, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isRising = trend.growthRate > 0;
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

          // Growth rate indicator
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRising ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 14,
                    color: growthColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    AppUtils.formatGrowthRate(trend.growthRate),
                    style: TextStyle(
                      color: growthColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // Mini bar showing relative growth
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (trend.growthRate.abs() / 500).clamp(0.05, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: growthColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
