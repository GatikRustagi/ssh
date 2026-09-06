import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/analysis_models.dart';
import '../providers/dashboard_providers.dart';
import 'panel_card.dart';

/// Full-width dashboard panel that shows coordination-risk alerts
/// produced by the deterministic [AnalysisEngine].
///
/// Each alert row shows:
///   • Risk badge (🔴 High / 🟡 Medium / 🟢 Low)
///   • Narrative label (dominant hashtag / keyword)
///   • Evidence bullets listing every fired rule
///   • Detection window timestamp
///   • Expandable detail for each [CoordinationSignal]
class CoordinationAlertPanel extends ConsumerWidget {
  const CoordinationAlertPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coordinationAlertsProvider);

    return PanelCard(
      title: 'Community Warnings',
      icon: Icons.shield_outlined,
      panelKey: 'coordination',
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Color(0xFFEF4444))),
        ),
        data: (alerts) => _AlertList(alerts: alerts),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AlertList extends StatelessWidget {
  final List<CoordinationRiskResult> alerts;
  const _AlertList({required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppTheme.sentimentPositive, size: 18),
          const SizedBox(width: 8),
          Text(
            'No unusual activity detected recently.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: alerts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => _AlertTile(alert: alerts[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AlertTile extends ConsumerStatefulWidget {
  final CoordinationRiskResult alert;
  const _AlertTile({required this.alert});

  @override
  ConsumerState<_AlertTile> createState() => _AlertTileState();
}

class _AlertTileState extends ConsumerState<_AlertTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final (badgeColor, badgeIcon, badgeLabel) = _badgeProps(a.riskLevel);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _expanded ? AppTheme.surfaceHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Alert header row ────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  // Risk badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(badgeIcon, style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Narrative label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.narrativeLabel,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.shortSummary,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Signal count chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${a.signals.length} signal${a.signals.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Expand chevron
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded evidence ───────────────────────────────────────────────
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Window timestamp
                  Text(
                    'Window: ${_formatTime(a.windowStart)} – ${_formatTime(a.windowEnd)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),

                  // Evidence bullets
                  ...a.signals.map((signal) => _EvidenceBullet(signal: signal)),

                  // Honesty note
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGlow,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Our system scans for bot-like behavior, spam, and artificial trends '
                      'to help you see authentic community sentiment.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.accentLight,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, String, String) _badgeProps(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return (AppTheme.sentimentNegative, '🔴', 'HIGH RISK');
      case RiskLevel.medium:
        return (AppTheme.sentimentSarcastic, '🟡', 'MEDIUM RISK');
      case RiskLevel.low:
        return (AppTheme.sentimentPositive, '🟢', 'LOW RISK');
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EvidenceBullet extends StatelessWidget {
  final CoordinationSignal signal;
  const _EvidenceBullet({required this.signal});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconForRule(signal.ruleId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              signal.evidence,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color, height: 1.4),
            ),
          ),
          // Weight pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+${(signal.weight * 100).toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _iconForRule(String ruleId) {
    switch (ruleId) {
      case 'duplicate_burst':
        return ('📋', AppTheme.sentimentNegative);
      case 'shared_url':
        return ('🔗', AppTheme.sentimentAnxious);
      case 'shared_hashtag':
        return ('#️⃣', AppTheme.sentimentAnxious);
      case 'growth_anomaly':
        return ('📈', AppTheme.sentimentSarcastic);
      case 'cross_account_velocity':
        return ('⚡', AppTheme.sentimentNegative);
      default:
        return ('•', AppTheme.textSecondary);
    }
  }
}
