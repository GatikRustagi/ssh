import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../models/network_graph.dart' as m;
import '../providers/dashboard_providers.dart';
import 'panel_card.dart';

/// Bottom-left dashboard panel: force-directed influence network graph.
/// Draws entirely via CustomPaint — no third-party graphview dependency issues.
/// Nodes = authors (sized by follower count).
/// Top-3 degree nodes highlighted as Key Opinion Leaders (KOLs).
class NetworkGraphPanel extends ConsumerWidget {
  const NetworkGraphPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(networkGraphProvider);

    return PanelCard(
      title: 'Influence Network',
      icon: Icons.hub_outlined,
      panelKey: 'network',
      collapsible: false,
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
        data: (graph) => _NetworkGraphView(graph: graph),
      ),
    );
  }
}

// ── View widget ────────────────────────────────────────────────────────────────

class _NetworkGraphView extends StatelessWidget {
  final m.NetworkGraph graph;
  const _NetworkGraphView({required this.graph});

  @override
  Widget build(BuildContext context) {
    if (graph.nodes.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(child: Text('No network data available.')),
      );
    }

    // Get the top 5 KOLs by follower count/degree
    final kols = graph.topKols(5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Top Key Opinion Leaders',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 12),
        ...kols.asMap().entries.map((entry) {
          final index = entry.key;
          final node = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                // Avatar / Rank circle
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: index < 3 ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: index < 3 ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: index < 3 ? AppTheme.accentLight : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.handle,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${AppUtils.compactNumber(node.followerCount)} followers · ${node.degree} interactions',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                
                // Star for top 3
                if (index < 3)
                  const Icon(
                    Icons.star_rounded,
                    color: AppTheme.accent,
                    size: 16,
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
