import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../models/demographic_summary.dart';
import '../providers/dashboard_providers.dart';
import 'panel_card.dart';

/// Bottom-right dashboard panel: demographic breakdown charts.
/// Shows age bracket bars, top languages, and top regions.
class DemographicsPanel extends ConsumerWidget {
  const DemographicsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(demographicsProvider);

    return PanelCard(
      title: 'Audience Demographics',
      icon: Icons.people_outline_rounded,
      panelKey: 'demographics',
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: Color(0xFFEF4444)))),
        data: (summaries) => _DemographicsView(summaries: summaries),
      ),
    );
  }
}

class _DemographicsView extends StatelessWidget {
  final List<DemographicSummary> summaries;
  const _DemographicsView({required this.summaries});

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const Center(child: Text('No demographic data yet.'));

    // Aggregate by age bracket
    final ageCounts = <String, int>{};
    final langCounts = <String, int>{};
    final regionCounts = <String, int>{};

    for (final s in summaries) {
      ageCounts[s.ageBracket]   = (ageCounts[s.ageBracket]   ?? 0) + s.aggregateCount;
      langCounts[s.language]    = (langCounts[s.language]    ?? 0) + s.aggregateCount;
      regionCounts[s.region]    = (regionCounts[s.region]    ?? 0) + s.aggregateCount;
    }

    // Sort descending
    final sortedLangs   = langCounts.entries.toList()  ..sort((a, b) => b.value.compareTo(a.value));
    final sortedRegions = regionCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Age Bracket Pie/Bar
          _SectionHeader(title: 'Age Distribution'),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: _AgeBarChart(ageCounts: ageCounts),
          ),
          const SizedBox(height: 20),

          // Languages
          _SectionHeader(title: 'Top Languages'),
          const SizedBox(height: 8),
          ...sortedLangs.map((e) => _HorizontalBar(
            label: e.key,
            count: e.value,
            total: langCounts.values.fold(0, (a, b) => a + b),
            color: AppTheme.sentimentSupportive,
          )),
          const SizedBox(height: 16),

          // Regions
          _SectionHeader(title: 'Top Regions'),
          const SizedBox(height: 8),
          ...sortedRegions.map((e) => _HorizontalBar(
            label: e.key,
            count: e.value,
            total: regionCounts.values.fold(0, (a, b) => a + b),
            color: AppTheme.accent,
          )),
        ],
      ),
    );
  }
}

class _AgeBarChart extends StatelessWidget {
  final Map<String, int> ageCounts;
  const _AgeBarChart({required this.ageCounts});

  @override
  Widget build(BuildContext context) {
    final brackets = ['18-24', '25-34', '35-44', '45+'];
    final maxVal = ageCounts.values.isEmpty ? 1 : ageCounts.values.reduce((a, b) => a > b ? a : b);

    final colors = [
      AppTheme.accent,
      AppTheme.sentimentSupportive,
      AppTheme.sentimentPositive,
      AppTheme.sentimentSarcastic,
    ];

    final barGroups = brackets.asMap().entries.map((e) {
      final val = (ageCounts[e.value] ?? 0).toDouble();
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: val,
            color: colors[e.key % colors.length],
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        maxY: maxVal.toDouble() * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (val, meta) {
                final index = val.toInt();
                if (index < 0 || index >= brackets.length || val != index.toDouble()) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    brackets[index],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (val, meta) => SideTitleWidget(
                meta: meta,
                space: 4,
                child: Text(
                  AppUtils.compactNumber(val.toInt()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false, reservedSize: 16)),
        ),
        barGroups: barGroups,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppTheme.surfaceHigh,
            getTooltipItem: (group, _, rod, __) {
              return BarTooltipItem(
                AppUtils.compactNumber(rod.toY.toInt()),
                const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HorizontalBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _HorizontalBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${AppUtils.compactNumber(count)} (${(pct * 100).toStringAsFixed(0)}%)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppTheme.textSecondary,
      letterSpacing: 0.5,
    ),
  );
}
