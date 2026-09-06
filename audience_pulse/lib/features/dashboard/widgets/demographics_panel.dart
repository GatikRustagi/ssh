import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../models/demographic_summary.dart';
import '../providers/dashboard_providers.dart';
import 'panel_card.dart';

/// Full-width demographic panel that renders a Heatmap (Age vs Region).
class DemographicsPanel extends ConsumerWidget {
  const DemographicsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(demographicsProvider);

    return PanelCard(
      backgroundColor: AppTheme.background,
      title: 'Demographic Heatmap',
      tooltipMessage: 'Visualizes audience distribution. Darker/brighter cells indicate higher user counts in that Age/Region intersection.',
      icon: Icons.map_outlined,
      panelKey: 'demographics_heatmap',
      child: async.when(
        loading: () => const SizedBox(
          height: 300,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 300,
          child: Center(
            child: Text('Error: $e', style: const TextStyle(color: Color(0xFFEF4444))),
          ),
        ),
        data: (summaries) => _DemographicsHeatmapView(summaries: summaries),
      ),
    );
  }
}

class _DemographicsHeatmapView extends StatelessWidget {
  final List<DemographicSummary> summaries;
  const _DemographicsHeatmapView({required this.summaries});

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const Center(child: Text('No demographic data yet.'));

    // Step 1: Find all unique Age Brackets (columns) and aggregate total counts per region (for sorting)
    final ageBrackets = {'18-24', '25-34', '35-44', '45+'}.toList();
    final regionTotals = <String, int>{};
    final matrix = <String, Map<String, int>>{}; // Region -> Age -> Count

    for (final s in summaries) {
      regionTotals[s.region] = (regionTotals[s.region] ?? 0) + s.aggregateCount;
      matrix.putIfAbsent(s.region, () => {});
      matrix[s.region]![s.ageBracket] = (matrix[s.region]![s.ageBracket] ?? 0) + s.aggregateCount;
    }

    // Step 2: Get top 6 regions
    final sortedRegions = regionTotals.keys.toList()
      ..sort((a, b) => regionTotals[b]!.compareTo(regionTotals[a]!));
    final topRegions = sortedRegions.take(6).toList();

    // Step 3: Find max count across all cells for color intensity scaling
    int maxCount = 0;
    for (final region in topRegions) {
      for (final age in ageBrackets) {
        final count = matrix[region]?[age] ?? 0;
        maxCount = max(maxCount, count);
      }
    }
    if (maxCount == 0) maxCount = 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row (Age Brackets)
          Row(
            children: [
              const SizedBox(width: 120), // Spacer for Region labels
              ...ageBrackets.map((age) => Expanded(
                child: Center(
                  child: Text(age, style: Theme.of(context).textTheme.labelSmall),
                ),
              )),
            ],
          ),
          const SizedBox(height: 12),
          // Heatmap Rows (Regions)
          ...topRegions.map((region) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      region,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...ageBrackets.map((age) {
                    final count = matrix[region]?[age] ?? 0;
                    // Calculate opacity from 0.05 to 1.0
                    final intensity = (count / maxCount).clamp(0.05, 1.0);
                    final isEmpty = count == 0;

                    return Expanded(
                      child: Tooltip(
                        message: '$region / $age\n${AppUtils.compactNumber(count)} users',
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceHigh,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.border),
                        ),
                        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.0),
                          height: 36,
                          decoration: BoxDecoration(
                            color: isEmpty 
                                ? AppTheme.surfaceHigh 
                                : AppTheme.accent.withValues(alpha: intensity),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
                          ),
                          child: Center(
                            child: Text(
                              isEmpty ? '-' : AppUtils.compactNumber(count),
                              style: TextStyle(
                                fontSize: 11,
                                color: isEmpty 
                                    ? AppTheme.textMuted 
                                    : (intensity > 0.5 ? Colors.white : AppTheme.textPrimary),
                                fontWeight: intensity > 0.5 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
