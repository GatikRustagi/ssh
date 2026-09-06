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
import 'widgets/smart_summary_panel.dart';


/// Main dashboard — 4-panel responsive analytics view with left platform nav.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const Map<String, String?> _platformOptions = {
    'All Platforms': null,
    'X (Twitter)': '11111111-0000-0000-0000-000000000001',
    'Telegram': '11111111-0000-0000-0000-000000000002',
    'YouTube': '11111111-0000-0000-0000-000000000006',
  };

  static const Map<String, IconData> _platformIcons = {
    'All Platforms': Icons.language_rounded,
    'X (Twitter)': Icons.close_rounded, // 𝕏 shape via icon
    'Telegram': Icons.send_rounded,
    'YouTube': Icons.play_arrow_rounded,
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
      ).catchError((_) {});
    }
  }

  void _selectPlatform(String label) {
    setState(() => _selectedPlatformLabel = label);
    ref.read(platformFilterProvider.notifier).state = _platformOptions[label];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left platform navigation sidebar ──────────────────────────
          _LeftPlatformNav(
            platformOptions: _platformOptions,
            platformIcons: _platformIcons,
            selected: _selectedPlatformLabel,
            onSelect: _selectPlatform,
          ),
          // Vertical divider
          Container(width: 1, color: AppTheme.border),
          // ── Main content ───────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 860;
                  return isWide
                      ? _buildWideLayout()
                      : _buildNarrowLayout();
                },
              ),
            ),
          ),
        ],
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
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Audie', style: Theme.of(context).textTheme.headlineMedium),
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

        // Live coordination-risk alert badge
        _AlertBadge(onTap: _scrollToAlerts),
        const SizedBox(width: 8),
        // Sign out
        IconButton(
          key: const Key('signout_btn'),
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout_rounded, size: 18),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.surface,
                title: const Text('Sign Out', style: TextStyle(color: AppTheme.textPrimary)),
                content: const Text('Are you sure you want to sign out?', style: TextStyle(color: AppTheme.textSecondary)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sign Out', style: TextStyle(color: AppTheme.sentimentNegative)),
                  ),
                ],
              ),
            );
            
            if (confirm == true) {
              await SupabaseService.instance.signOut();
              if (context.mounted) context.go(AppConstants.routeLogin);
            }
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

  Widget _buildWideLayout() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _UserGreetingBanner(),
          const SmartSummaryPanel(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SentimentChartPanel()),
              const SizedBox(width: 16),
              SizedBox(width: 340, child: TrendsPanel()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    const NetworkGraphPanel(),
                    const SizedBox(height: 16),
                    Container(
                      key: _alertsKey,
                      child: const CoordinationAlertPanel(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const SizedBox(
                width: 340,
                child: Column(
                  children: [
                    DemographicsPanel(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return ListView(
      children: [
        const _UserGreetingBanner(),
        const SmartSummaryPanel(),
        const SentimentChartPanel(),
        const SizedBox(height: 16),
        const TrendsPanel(),
        const SizedBox(height: 16),
        const NetworkGraphPanel(),
        const SizedBox(height: 16),
        const DemographicsPanel(),
        const SizedBox(height: 16),
        Container(key: _alertsKey, child: const CoordinationAlertPanel()),
      ],
    );
  }
}

// ── Left Platform Navigation Sidebar ─────────────────────────────────────────

class _LeftPlatformNav extends StatelessWidget {
  final Map<String, String?> platformOptions;
  final Map<String, IconData> platformIcons;
  final String selected;
  final void Function(String) onSelect;

  const _LeftPlatformNav({
    required this.platformOptions,
    required this.platformIcons,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 188,
      color: AppTheme.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text(
              'PLATFORM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ),
          // Nav items
          ...platformOptions.keys.map((label) {
            final isSelected = label == selected;
            final icon = platformIcons[label] ?? Icons.circle_outlined;
            return _NavItem(
              label: label,
              icon: icon,
              isSelected: isSelected,
              onTap: () => onSelect(label),
            );
          }),
          const Spacer(),
          // Bottom divider + version hint
          Divider(color: AppTheme.border, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Icon(Icons.wifi_tethering_rounded, size: 12, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Live · v1.0',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.accent
                : _hovered
                    ? AppTheme.accentGlow.withValues(alpha: 0.4)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Platform icon — use custom text for X
              widget.label == 'X (Twitter)'
                  ? Text(
                      '𝕏',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: widget.isSelected
                            ? Colors.white
                            : _hovered
                                ? AppTheme.accentLight
                                : AppTheme.textSecondary,
                      ),
                    )
                  : Icon(
                      widget.icon,
                      size: 16,
                      color: widget.isSelected
                          ? Colors.white
                          : _hovered
                              ? AppTheme.accentLight
                              : AppTheme.textSecondary,
                    ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isSelected
                      ? Colors.white
                      : _hovered
                          ? AppTheme.accentLight
                          : AppTheme.textSecondary,
                ),
              ),
              if (widget.isSelected) ...[
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
      margin: const EdgeInsets.only(bottom: 24, top: 8),
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Hi, $name 👋',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome back to Audie. Here is your live intelligence overview.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Alert badge shown in the AppBar ──────────────────────────────────────────

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
