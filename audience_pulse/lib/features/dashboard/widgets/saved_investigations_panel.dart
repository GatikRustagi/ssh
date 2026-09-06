import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../models/trend.dart';
import '../../../services/analysis_engine.dart';
import '../providers/dashboard_providers.dart';
import 'panel_card.dart';

class SavedInvestigationsPanel extends ConsumerWidget {
  const SavedInvestigationsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedTrends = ref.watch(savedTrendsProvider);

    return PanelCard(
      title: 'Saved Trends',
      icon: Icons.bookmark_outline,
      panelKey: 'saved_investigations',
      child: savedTrends.isEmpty
          ? _EmptyState()
          : _SavedList(trends: savedTrends),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.bookmark_border_rounded, size: 32, color: AppTheme.border),
          const SizedBox(height: 12),
          Text(
            'No saved trends yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Click the bookmark icon on any top trend to save it here for later review.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SavedList extends ConsumerWidget {
  final List<Trend> trends;
  const _SavedList({required this.trends});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: trends.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final trend = trends[i];
        final sentiment = AnalysisEngine.instance.classifySentiment(trend.keywordOrTopic);
        final isNegative = sentiment.label == 'negative' || sentiment.label == 'anxious' || sentiment.label == 'against';
        final isRising = !isNegative;
        final color = isRising ? AppTheme.sentimentPositive : AppTheme.sentimentNegative;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trend.keywordOrTopic,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppUtils.compactNumber(trend.mentionCount)} mentions',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_remove_rounded, size: 18),
                color: AppTheme.textSecondary,
                tooltip: 'Remove from saved',
                onPressed: () {
                  ref.read(savedTrendsProvider.notifier).removeTrend(trend.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
