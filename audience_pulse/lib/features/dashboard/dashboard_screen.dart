import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../services/supabase_service.dart';
import '../dashboard/providers/dashboard_providers.dart';
import 'widgets/sentiment_chart_panel.dart';
import 'widgets/trends_panel.dart';
import 'widgets/network_graph_panel.dart';
import 'widgets/demographics_panel.dart';
import 'widgets/coordination_alert_panel.dart';

/// Main dashboard — 4-panel responsive analytics view.
///
/// Layout:
///   [Sentiment Timeline] | [Top Trends]
///   [Network Graph]      | [Demographics]
///
/// All panels share a platform filter dropdown.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Platforms for dropdown — keyed by display name
  static const Map<String, String?> _platformOptions = {
    'All Platforms': null,
    'X (Twitter)': '11111111-0000-0000-0000-000000000001',
    'Telegram':    '11111111-0000-0000-0000-000000000002',
  };

  String _selectedPlatformLabel = 'All Platforms';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive: single column on narrow screens, 2-column grid on wide
            final isWide = constraints.maxWidth >= 900;
            if (isWide) {
              return _buildWideLayout();
            } else {
              return _buildNarrowLayout();
            }
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accent, Color(0xFF5B21B6)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text('AudiencePulse', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accentGlow,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
            ),
            child: const Text('BETA', style: TextStyle(
              color: AppTheme.accentLight, fontSize: 10, fontWeight: FontWeight.w700,
            )),
          ),
        ],
      ),
      actions: [
        // Platform filter dropdown
        _buildPlatformFilter(),
        const SizedBox(width: 12),
        // Ingestion status button
        TextButton.icon(
          key: const Key('ingestion_status_btn'),
          onPressed: () => context.go(AppConstants.routeIngestion),
          icon: const Icon(Icons.cable_outlined, size: 16),
          label: const Text('Pipeline'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
        ),
        const SizedBox(width: 8),
        // Live coordination-risk alert badge
        _AlertBadge(),
        const SizedBox(width: 8),
        // Sign out
        IconButton(
          key: const Key('signout_btn'),
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout_rounded, size: 18),
          onPressed: () async {
            await SupabaseService.instance.signOut();
            if (context.mounted) context.go(AppConstants.routeLogin);
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(color: AppTheme.border, height: 1),
      ),
    );
  }

  Widget _buildPlatformFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButton<String>(
        key: const Key('platform_filter_dropdown'),
        value: _selectedPlatformLabel,
        underline: const SizedBox(),
        dropdownColor: AppTheme.surfaceHigh,
        style: Theme.of(context).textTheme.labelLarge,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.textSecondary),
        items: _platformOptions.keys.map((label) {
          return DropdownMenuItem<String>(
            value: label,
            child: Text(label),
          );
        }).toList(),
        onChanged: (label) {
          if (label == null) return;
          setState(() => _selectedPlatformLabel = label);
          // Update the global platform filter provider
          ref.read(platformFilterProvider.notifier).state = _platformOptions[label];
        },
      ),
    );
  }

  Widget _buildWideLayout() {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: SentimentChartPanel()),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: TrendsPanel()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: NetworkGraphPanel()),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: DemographicsPanel()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Full-width Coordination Risk Alerts panel
        SizedBox(
          height: 280,
          child: CoordinationAlertPanel(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return ListView(
      children: [
        SizedBox(height: 340, child: SentimentChartPanel()),
        const SizedBox(height: 16),
        SizedBox(height: 340, child: TrendsPanel()),
        const SizedBox(height: 16),
        SizedBox(height: 380, child: NetworkGraphPanel()),
        const SizedBox(height: 16),
        SizedBox(height: 340, child: DemographicsPanel()),
        const SizedBox(height: 16),
        // Coordination Risk Alerts — full-width at bottom
        SizedBox(height: 320, child: CoordinationAlertPanel()),
      ],
    );
  }
}

// ── Alert badge shown in the AppBar ──────────────────────────────────────────

/// Watches [coordinationAlertsProvider] and shows a badge with the count
/// of high-risk alerts. Tapping it scrolls the user to the alerts panel
/// (currently a visual indicator only; extend with a scroll controller if needed).
class _AlertBadge extends ConsumerWidget {
  const _AlertBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coordinationAlertsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (alerts) {
        final highCount = alerts.where((a) => a.isHighRisk).length;
        if (highCount == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.sentimentNegative.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.sentimentNegative.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔴', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(
                '$highCount High-Risk Alert${highCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppTheme.sentimentNegative,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
