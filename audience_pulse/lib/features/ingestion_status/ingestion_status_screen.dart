import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/platform_model.dart';
import '../dashboard/providers/dashboard_providers.dart';

/// Shows the ingestion pipeline status per platform.
/// Live platforms show last-synced time; coming-soon platforms show a roadmap badge.
class IngestionStatusScreen extends ConsumerWidget {
  const IngestionStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ingestionStatusProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Data Pipeline Status'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppConstants.routeDashboard),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: AppTheme.border, height: 1),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text('Platform Connections', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 4),
                Text(
                  'Real-time status of each social media data source.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Platform list
                async.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e',
                      style: const TextStyle(color: Color(0xFFEF4444))),
                  data: (platforms) => Column(
                    children: (platforms as List).map((p) => _PlatformRow(platform: p)).toList(),
                  ),
                ),

                const SizedBox(height: 32),

                // Coming soon note
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Coming-soon platforms are on the roadmap. Supabase Edge Functions '
                          'will handle ingestion once API keys are configured.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformRow extends StatelessWidget {
  final PlatformModel platform;
  const _PlatformRow({required this.platform});

  @override
  Widget build(BuildContext context) {
    final icon = AppConstants.platformIcons[platform.name] ?? '🌐';
    final isLive = platform.isLive;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLive ? AppTheme.statusLive.withValues(alpha: 0.3) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          // Platform icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 16),

          // Name + last synced
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(platform.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  isLive
                      ? platform.lastSyncedAt != null
                          ? 'Last synced ${AppUtils.timeAgo(platform.lastSyncedAt!)}'
                          : 'Connected — awaiting first sync'
                      : 'Not yet integrated',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Status pill
          _StatusPill(isLive: isLive),

          if (!isLive) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Roadmap Q2 2025',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isLive;
  const _StatusPill({required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isLive
            ? AppTheme.statusLive.withValues(alpha: 0.15)
            : AppTheme.statusComingSoon.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLive
              ? AppTheme.statusLive.withValues(alpha: 0.4)
              : AppTheme.statusComingSoon.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: isLive ? AppTheme.statusLive : AppTheme.statusComingSoon,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isLive ? 'LIVE' : 'COMING SOON',
            style: TextStyle(
              color: isLive ? AppTheme.statusLive : AppTheme.statusComingSoon,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
