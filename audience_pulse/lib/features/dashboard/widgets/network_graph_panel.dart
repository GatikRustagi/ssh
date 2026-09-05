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

// ── Force-directed layout engine ───────────────────────────────────────────────

class _NodePos {
  final m.NetworkNode node;
  double x, y;
  double vx = 0, vy = 0;
  _NodePos({required this.node, required this.x, required this.y});
}

List<_NodePos> _computeLayout(List<m.NetworkNode> nodes, List<m.NetworkEdge> edges, Size size) {
  final rng = math.Random(42);
  final positions = {
    for (final n in nodes)
      n.id: _NodePos(
        node: n,
        x: 40 + rng.nextDouble() * (size.width - 80),
        y: 40 + rng.nextDouble() * (size.height - 80),
      ),
  };

  const iterations = 150;
  const k = 120.0; // spring length — larger = more spread
  const repulsion = 8000.0;
  const damping = 0.85;

  for (int i = 0; i < iterations; i++) {
    final cooling = 1.0 - i / iterations;
    final maxDisp = 12.0 * cooling + 1;

    // Repulsion
    final posList = positions.values.toList();
    for (int a = 0; a < posList.length; a++) {
      for (int b = a + 1; b < posList.length; b++) {
        final pa = posList[a], pb = posList[b];
        final dx = pa.x - pb.x;
        final dy = pa.y - pb.y;
        final dist = math.sqrt(dx * dx + dy * dy) + 0.01;
        final force = repulsion / (dist * dist);
        pa.vx += force * dx / dist;
        pa.vy += force * dy / dist;
        pb.vx -= force * dx / dist;
        pb.vy -= force * dy / dist;
      }
    }

    // Attraction (edges)
    for (final e in edges) {
      final pa = positions[e.sourceAuthorId];
      final pb = positions[e.targetAuthorId];
      if (pa == null || pb == null) continue;
      final dx = pb.x - pa.x;
      final dy = pb.y - pa.y;
      final dist = math.sqrt(dx * dx + dy * dy) + 0.01;
      final force = (dist * dist) / k;
      pa.vx += force * dx / dist;
      pa.vy += force * dy / dist;
      pb.vx -= force * dx / dist;
      pb.vy -= force * dy / dist;
    }

    // Apply velocity + damping + clamp
    for (final p in posList) {
      final speed = math.sqrt(p.vx * p.vx + p.vy * p.vy) + 0.01;
      final disp = math.min(speed, maxDisp);
      p.x += p.vx / speed * disp;
      p.y += p.vy / speed * disp;
      p.x = p.x.clamp(30.0, size.width - 30);
      p.y = p.y.clamp(30.0, size.height - 30);
      p.vx *= damping;
      p.vy *= damping;
    }
  }

  return positions.values.toList();
}

// ── View widget ────────────────────────────────────────────────────────────────

class _NetworkGraphView extends StatefulWidget {
  final m.NetworkGraph graph;
  const _NetworkGraphView({required this.graph});

  @override
  State<_NetworkGraphView> createState() => _NetworkGraphViewState();
}

class _NetworkGraphViewState extends State<_NetworkGraphView> {
  m.NetworkNode? _selectedNode;
  final _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.graph.nodes.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(child: Text('No network data available.')),
      );
    }

    final kolIds = widget.graph.topKols(3).map((n) => n.id).toSet();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKolLegend(context, widget.graph.topKols(3)),
        const SizedBox(height: 10),
        // Fixed-height canvas — CustomPaint handles all rendering
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const height = 300.0;
            final size = Size(width, height);
            final positions = _computeLayout(
              widget.graph.nodes,
              widget.graph.edges,
              size,
            );
            final posMap = {for (final p in positions) p.node.id: p};

            return SizedBox(
              width: width,
              height: height,
              child: InteractiveViewer(
                transformationController: _transformController,
                constrained: true,
                minScale: 0.4,
                maxScale: 4.0,
                child: GestureDetector(
                  onTapDown: (details) {
                    // Convert screen tap → scene coordinates accounting for zoom/pan
                    final scene = _transformController.toScene(details.localPosition);
                    m.NetworkNode? hit;
                    for (final p in positions) {
                      final nodeR = _nodeRadius(p.node);
                      final dx = scene.dx - p.x;
                      final dy = scene.dy - p.y;
                      if (dx * dx + dy * dy <= nodeR * nodeR * 2.5) {
                        hit = p.node;
                        break;
                      }
                    }
                    setState(() {
                      _selectedNode = (_selectedNode?.id == hit?.id) ? null : hit;
                    });
                  },
                  child: CustomPaint(
                  size: size,
                  painter: _GraphPainter(
                    positions: positions,
                    posMap: posMap,
                    edges: widget.graph.edges,
                    kolIds: kolIds,
                    selectedId: _selectedNode?.id,
                  ),
                  child: Stack(
                    children: positions.map((p) {
                      final isKol = kolIds.contains(p.node.id);
                      final isSelected = _selectedNode?.id == p.node.id;
                      final r = _nodeRadius(p.node);
                      // Show label for KOLs and selected node only
                      final showLabel = isKol || isSelected;
                      return Positioned(
                        left: p.x - r,
                        top: p.y - r,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedNode = isSelected ? null : p.node;
                          }),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: r * 2,
                                height: r * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isKol
                                      ? AppTheme.accent
                                      : isSelected
                                          ? const Color(0xFF60A5FA)
                                          : const Color(0xFF818CF8),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: isSelected ? 1.5 : 0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isKol
                                              ? AppTheme.accent
                                              : const Color(0xFF818CF8))
                                          .withValues(alpha: isSelected ? 0.9 : 0.5),
                                      blurRadius: isKol ? 10 : 6,
                                      spreadRadius: isSelected ? 2 : 0,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: isKol && r > 4
                                    ? Icon(Icons.star_rounded,
                                        size: r * 0.9, color: Colors.white)
                                    : null,
                              ),
                              if (showLabel) ...[  
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.surfaceHigh.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.accent
                                          : AppTheme.border
                                              .withValues(alpha: 0.5),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    p.node.handle,
                                    style: TextStyle(
                                      color: isKol
                                          ? AppTheme.accentLight
                                          : AppTheme.textSecondary,
                                      fontSize: 8,
                                      fontWeight: isKol
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  ),
                ),
              ),
            );
          },
        ),

        // Zoom hint
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pinch_outlined, size: 12, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                'Pinch or scroll to zoom · Drag to pan',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),

        // Selected node info card
        if (_selectedNode != null) _buildNodeInfo(context, _selectedNode!),
      ],
    );
  }

  double _nodeRadius(m.NetworkNode node) =>
      3.0 + (node.followerCount / 30000).clamp(0.0, 4.0);

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, size: 10, color: AppTheme.accentLight),
              const SizedBox(width: 3),
              Text(
                n.handle,
                style: const TextStyle(
                  color: AppTheme.accentLight, fontSize: 11, fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildNodeInfo(BuildContext context, m.NetworkNode node) {
    final isKol = widget.graph.topKols(3).any((n) => n.id == node.id);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isKol ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.border),
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

// ── CustomPainter — draws edges only (nodes are Stack widgets above) ───────────

class _GraphPainter extends CustomPainter {
  final List<_NodePos> positions;
  final Map<String, _NodePos> posMap;
  final List<m.NetworkEdge> edges;
  final Set<String> kolIds;
  final String? selectedId;

  const _GraphPainter({
    required this.positions,
    required this.posMap,
    required this.edges,
    required this.kolIds,
    required this.selectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final src = posMap[edge.sourceAuthorId];
      final tgt = posMap[edge.targetAuthorId];
      if (src == null || tgt == null) continue;

      final isHighlighted =
          src.node.id == selectedId || tgt.node.id == selectedId;
      final paint = Paint()
        ..color = isHighlighted
            ? AppTheme.accent.withValues(alpha: 0.85)
            : const Color(0xFF818CF8).withValues(alpha: 0.22)
        ..strokeWidth = isHighlighted
            ? (edge.weight * 1.2).clamp(1.5, 3.0).toDouble()
            : (edge.weight * 0.6).clamp(0.5, 1.5).toDouble()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(src.x, src.y), Offset(tgt.x, tgt.y), paint);
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.selectedId != selectedId || old.edges != edges;
}
