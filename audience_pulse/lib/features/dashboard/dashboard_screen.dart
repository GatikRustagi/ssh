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
  final GlobalKey _alertsKey = GlobalKey();

  void _scrollToAlerts() {
    final ctx = _alertsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ).catchError((_) {}); // Ignore if no Scrollable is found
    }
  }

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
        _AlertBadge(onTap: _scrollToAlerts),
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _UserGreetingBanner(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SentimentChartPanel()),
              const SizedBox(width: 16),
              SizedBox(width: 360, child: TrendsPanel()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: NetworkGraphPanel()),
              const SizedBox(width: 16),
              SizedBox(width: 360, child: DemographicsPanel()),
            ],
          ),
          const SizedBox(height: 16),
          // Full-width Coordination Risk Alerts panel
          Container(
            key: _alertsKey,
            child: const CoordinationAlertPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return ListView(
      children: [
        const _UserGreetingBanner(),
        const SentimentChartPanel(),
        const SizedBox(height: 16),
        const TrendsPanel(),
        const SizedBox(height: 16),
        const NetworkGraphPanel(),
        const SizedBox(height: 16),
        const DemographicsPanel(),
        const SizedBox(height: 16),
        // Coordination Risk Alerts — full-width at bottom
        Container(key: _alertsKey, child: const CoordinationAlertPanel()),
      ],
    );
  }
}

// ── Glowing User Greeting Banner ──────────────────────────────────────────────

class _UserGreetingBanner extends StatelessWidget {
  const _UserGreetingBanner();

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.instance.currentUser;
    String name = 'Analyst';
    if (user != null && user.email != null && user.email!.isNotEmpty) {
      final parts = user.email!.split('@');
      if (parts.isNotEmpty && parts.first.isNotEmpty) {
        name = parts.first[0].toUpperCase() + parts.first.substring(1);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentGlow.withValues(alpha: 0.25),
            AppTheme.surfaceHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGlow.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accent, Color(0xFF7C3AED)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentGlow,
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.waving_hand_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $name 👋',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: AppTheme.accent.withValues(alpha: 0.8),
                        blurRadius: 16,
                      ),
                      Shadow(
                        color: AppTheme.accentLight.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Welcome back to AudiencePulse. Here is your live intelligence overview.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Alert badge shown in the AppBar ──────────────────────────────────────────

/// Watches [coordinationAlertsProvider] and shows a badge with the count
/// of high-risk alerts. Tapping it scrolls the user to the alerts panel
class _AlertBadge extends ConsumerWidget {
  final VoidCallback onTap;
  const _AlertBadge({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coordinationAlertsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (alerts) {
        final highCount = alerts.where((a) => a.isHighRisk).length;
        if (highCount == 0) return const SizedBox.shrink();
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
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
          ),
        );
      },
    );
  }
}
