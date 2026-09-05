import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../providers/dashboard_providers.dart';

/// Shared card wrapper for all dashboard panels.
/// Provides consistent header with icon, title, last-updated time, and refresh.
class PanelCard extends ConsumerWidget {
  final String title;
  final IconData icon;
  final String panelKey;
  final Widget child;
  final VoidCallback? onRefresh;

  const PanelCard({
    super.key,
    required this.title,
    required this.icon,
    required this.panelKey,
    required this.child,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastUpdated = ref.watch(lastUpdatedProvider)[panelKey];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Panel Header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                if (lastUpdated != null)
                  Text(
                    'Updated ${AppUtils.timeAgo(lastUpdated)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                const SizedBox(width: 4),
                // Refresh button
                InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.refresh_rounded, size: 14, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: AppTheme.border, height: 1),
          // ── Panel Content ──────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
