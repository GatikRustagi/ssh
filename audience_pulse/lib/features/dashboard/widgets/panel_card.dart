import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../providers/dashboard_providers.dart';

/// Shared card wrapper for all dashboard panels.
/// Provides consistent header with icon, title, last-updated time, refresh,
/// and collapsible expansion toggle.
class PanelCard extends ConsumerStatefulWidget {
  final String title;
  final String? tooltipMessage;
  final IconData icon;
  final String panelKey;
  final Widget child;
  final VoidCallback? onRefresh;
  final double? expandedHeight;
  final bool collapsible;
  final bool defaultCollapsed;
  final Color? backgroundColor; // new optional background color
  const PanelCard({
    super.key,
    required this.title,
    this.tooltipMessage,
    required this.icon,
    required this.panelKey,
    required this.child,
    this.onRefresh,
    this.expandedHeight,
    this.collapsible = true,
    this.defaultCollapsed = false,
    this.backgroundColor,
  });

  @override
  ConsumerState<PanelCard> createState() => _PanelCardState();
}

class _PanelCardState extends ConsumerState<PanelCard> {
  late bool _isCollapsed;

  @override
  void initState() {
    super.initState();
    _isCollapsed = widget.defaultCollapsed;
  }

  @override
  Widget build(BuildContext context) {
    final lastUpdated = ref.watch(lastUpdatedProvider)[widget.panelKey];
    final double? height = widget.expandedHeight != null
        ? (_isCollapsed ? 52.0 : widget.expandedHeight)
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: widget.expandedHeight != null ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Panel Header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Icon(widget.icon, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
                if (widget.tooltipMessage != null) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: widget.tooltipMessage!,
                    child: const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.textMuted),
                  ),
                ],
                const Spacer(),
                if (lastUpdated != null && !_isCollapsed)
                  Text(
                    'Updated ${AppUtils.timeAgo(lastUpdated)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                const SizedBox(width: 4),
                // Refresh button
                if (widget.onRefresh != null && !_isCollapsed) ...[
                  InkWell(
                    onTap: widget.onRefresh,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.refresh_rounded, size: 14, color: AppTheme.textMuted),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // Collapsible toggle button
                if (widget.collapsible)
                  InkWell(
                    key: Key('collapse_btn_${widget.panelKey}'),
                    onTap: () => setState(() => _isCollapsed = !_isCollapsed),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: AnimatedRotation(
                        turns: _isCollapsed ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 18,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!_isCollapsed) ...[
            Divider(color: AppTheme.border, height: 1),
            // ── Panel Content ──────────────────────────────────────────────
            if (widget.expandedHeight != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: widget.child,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: widget.child,
              ),
          ],
        ],
      ),
    );
  }
}
