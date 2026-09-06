import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';

/// A simple text summary panel that generates an easy-to-read sentence
/// based on the current dashboard data, designed for general users.
class SmartSummaryPanel extends ConsumerWidget {
  const SmartSummaryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(topTrendsProvider);
    final sentimentAsync = ref.watch(sentimentTimelineProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome,
            color: AppTheme.accentLight,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Smart Summary',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.accentLight,
                      ),
                ),
                const SizedBox(height: 4),
                trendsAsync.when(
                  loading: () => const Text('Analyzing current data...', style: TextStyle(color: AppTheme.textSecondary)),
                  error: (_, __) => const Text('Could not generate summary.', style: TextStyle(color: AppTheme.textSecondary)),
                  data: (trends) {
                    return sentimentAsync.when(
                      loading: () => const Text('Analyzing current data...', style: TextStyle(color: AppTheme.textSecondary)),
                      error: (_, __) => const Text('Could not generate summary.', style: TextStyle(color: AppTheme.textSecondary)),
                      data: (scores) {
                        if (trends.isEmpty) {
                          return const Text('Not enough data to generate a summary right now.', style: TextStyle(color: AppTheme.textPrimary, height: 1.4));
                        }
                        
                        final topTrend = trends.first;
                        
                        return Text(
                          'Right now, "${topTrend.keywordOrTopic}" is trending fast with over ${topTrend.mentionCount} recent mentions. Overall sentiment remains steady.',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            height: 1.4,
                            fontSize: 14,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
