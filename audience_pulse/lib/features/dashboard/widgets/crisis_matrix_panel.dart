import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';
import 'panel_card.dart';

class CrisisMatrixPanel extends ConsumerWidget {
  const CrisisMatrixPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(crisisMatrixProvider);

    return PanelCard(
      title: 'Crisis Matrix',
      tooltipMessage: 'Plots virality against sentiment. The bottom-right (Red Zone) indicates a viral crisis.',
      icon: Icons.radar_rounded,
      panelKey: 'crisis_matrix',
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Color(0xFFEF4444))),
        ),
        data: (points) => _MatrixView(points: points),
      ),
    );
  }
}

class _MatrixView extends StatelessWidget {
  final List<CrisisPoint> points;
  const _MatrixView({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('Gathering post metrics...'));
    }

    double maxVirality = points.map((p) => p.virality).reduce(max).toDouble();
    if (maxVirality == 0) maxVirality = 100;
    
    // Add padding to max x
    final maxX = maxVirality * 1.1;

    return ScatterChart(
      ScatterChartData(
        scatterSpots: points.asMap().entries.map((e) {
          final p = e.value;
          final isCrisis = p.sentimentScore < 0 && p.virality > (maxVirality * 0.3);
          return ScatterSpot(
            p.virality.toDouble(),
            p.sentimentScore,
            dotPainter: FlDotCirclePainter(
              radius: isCrisis ? 8 : 5,
              color: isCrisis ? Colors.redAccent : (p.sentimentScore > 0 ? Colors.greenAccent : AppTheme.textMuted),
            ),
          );
        }).toList(),
        minX: - (maxX * 0.05),
        maxX: maxX,
        minY: -1.2,
        maxY: 1.2,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) {
            if (value == 0) {
              return FlLine(color: AppTheme.border, strokeWidth: 2);
            }
            return FlLine(color: Colors.transparent, strokeWidth: 0);
          },
          getDrawingVerticalLine: (value) {
            if (value == 0) return FlLine(color: Colors.transparent, strokeWidth: 0);
            return FlLine(color: AppTheme.border, strokeWidth: 0.5, dashArray: [5, 5]);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Virality (Engagement)'),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value <= 0) return const SizedBox();
                return Text(value.toInt().toString(), style: Theme.of(context).textTheme.bodySmall);
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('Sentiment'),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                if (value == 1.0) return const Text('Positive', style: TextStyle(fontSize: 10, color: Colors.greenAccent));
                if (value == -1.0) return const Text('Negative', style: TextStyle(fontSize: 10, color: Colors.redAccent));
                return const SizedBox();
              },
            ),
          ),
        ),
        scatterTouchData: ScatterTouchData(
          enabled: true,
          touchTooltipData: ScatterTouchTooltipData(
            getTooltipColor: (_) => AppTheme.surfaceHigh,
            getTooltipItems: (touchedSpot) {
              final p = points.firstWhere((p) => p.virality.toDouble() == touchedSpot.x && p.sentimentScore == touchedSpot.y, orElse: () => points.first);
              return ScatterTooltipItem(
                'User: ${p.author}\n',
                textStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                children: [
                  TextSpan(
                    text: '${p.content.length > 60 ? p.content.substring(0, 60) + "..." : p.content}\n',
                    style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  TextSpan(
                    text: 'Virality: ${p.virality}',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
