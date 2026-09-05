import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphview/GraphView.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../models/network_graph.dart' as m;
import '../providers/dashboard_providers.dart';
import 'panel_card.dart';

/// Bottom-left dashboard panel: force-directed influence network graph.
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
      expandedHeight: 440,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Color(0xFFEF4444))),
        ),
        data: (graph) => _NetworkGraphView(graph: graph),
      ),
    );
  }
}

class _NetworkGraphView extends StatefulWidget {
  final m.NetworkGraph graph;
  const _NetworkGraphView({required this.graph});

  @override
  State<_NetworkGraphView> createState() => _NetworkGraphViewState();
}

class _NetworkGraphViewState extends State<_NetworkGraphView> {
  late final Graph _gvGraph;
  late final Algorithm _algorithm;
  m.NetworkNode? _selectedNode;

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  void _buildGraph() {
    _gvGraph = Graph()..isTree = false;

    // FruchtermanReingoldAlgorithm requires a FruchtermanReingoldConfiguration
    _algorithm = FruchtermanReingoldAlgorithm(
      FruchtermanReingoldConfiguration(
        iterations: 300,
        repulsionRate: 0.2,
        attractionRate: 0.15,
        repulsionPercentage: 0.4,
        attractionPercentage: 0.15,
        shuffleNodes: true,
      ),
    );

    // Map author id → graphview Node
    final nodeMap = <String, Node>{};
    for (final n in widget.graph.nodes) {
      final gNode = Node.Id(n.id);
      nodeMap[n.id] = gNode;
      _gvGraph.addNode(gNode);
    }

    // Add edges
    for (final edge in widget.graph.edges) {
      final src = nodeMap[edge.sourceAuthorId];
      final tgt = nodeMap[edge.targetAuthorId];
      if (src != null && tgt != null) {
        _gvGraph.addEdge(src, tgt,
          paint: Paint()
            ..color = const Color(0xFF818CF8).withValues(alpha: 0.45)
            ..strokeWidth = (edge.weight * 1.5).clamp(1.5, 4.5).toDouble()
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.graph.nodes.isEmpty) {
      return const Center(child: Text('No network data available.'));
    }

    final kolIds = widget.graph.topKols(3).map((n) => n.id).toSet();
    final nodeMap = <String, m.NetworkNode>{
      for (final n in widget.graph.nodes) n.id: n,
    };

    return Column(
      children: [
        // KOL legend
        _buildKolLegend(context, widget.graph.topKols(3)),
        const SizedBox(height: 8),
        // Graph viewport
        Expanded(
          child: InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.1,
            maxScale: 5.0,
            child: GraphView(
              graph: _gvGraph,
              algorithm: _algorithm,
              paint: Paint()
                ..color = AppTheme.border
                ..strokeWidth = 1.5
                ..style = PaintingStyle.stroke,
              builder: (Node node) {
                final id = node.key!.value as String;
                final networkNode = nodeMap[id];
                if (networkNode == null) {
                  return const SizedBox(width: 12, height: 12);
                }
                final isKol = kolIds.contains(id);
                return _buildNodeWidget(context, networkNode, isKol);
              },
            ),
          ),
        ),

        // Selected node info
        if (_selectedNode != null) _buildNodeInfo(context, _selectedNode!),
      ],
    );
  }

  Widget _buildNodeWidget(BuildContext context, m.NetworkNode node, bool isKol) {
    final nodeSize = (22.0 + (node.followerCount / 8000).clamp(0.0, 18.0));
    final primaryColor = isKol ? AppTheme.accent : const Color(0xFF3B82F6);
    final isSelected = _selectedNode?.id == node.id;
    final initial = node.handle.replaceAll('@', '').isNotEmpty
        ? node.handle.replaceAll('@', '').substring(0, 1).toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () => setState(() {
        _selectedNode = _selectedNode?.id == node.id ? null : node;
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: nodeSize,
            height: nodeSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isKol
                    ? [AppTheme.accent, const Color(0xFF9333EA)]
                    : [const Color(0xFF3B82F6), const Color(0xFF06B6D4)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isKol ? AppTheme.accentGlow : primaryColor).withValues(alpha: isSelected ? 0.8 : 0.4),
                  blurRadius: isKol ? 14 : 8,
                  spreadRadius: isSelected ? 3 : 1,
                ),
              ],
              border: Border.all(
                color: isSelected
                    ? Colors.white
                    : (isKol ? AppTheme.accentLight : primaryColor.withValues(alpha: 0.8)),
                width: isSelected ? 2.5 : 1.5,
              ),
            ),
            child: Center(
              child: isKol
                  ? const Icon(Icons.star_rounded, size: 13, color: Colors.white)
                  : Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accent
                    : AppTheme.border.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              node.handle,
              style: TextStyle(
                color: isKol ? AppTheme.accentLight : AppTheme.textSecondary,
                fontSize: 9.5,
                fontWeight: isKol ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKolLegend(BuildContext context, List<m.NetworkNode> kols) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Text('KOLs: ', style: Theme.of(context).textTheme.labelSmall),
        ...kols.map((n) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.accentGlow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
          ),
          child: Text(
            n.handle,
            style: const TextStyle(
              color: AppTheme.accentLight, fontSize: 11, fontWeight: FontWeight.w600,
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildNodeInfo(BuildContext context, m.NetworkNode node) {
    final isKol = widget.graph.topKols(3).any((n) => n.id == node.id);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          if (isKol) ...[
            const Icon(Icons.star_rounded, size: 14, color: AppTheme.accent),
            const SizedBox(width: 4),
          ],
          Text(node.handle, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${AppUtils.compactNumber(node.followerCount)} followers · ${node.degree} interactions',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _selectedNode = null),
            child: const Icon(Icons.close, size: 14, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
