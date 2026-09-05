import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/trend.dart';
import 'providers/trend_providers.dart';

/// Full-page Twitter Trend Analysis Screen.
///
/// Three tabs:
///   1. Trending Now   — Horizontal bar chart of top hashtags by growth rate
///   2. Engagement     — Line chart of hourly engagement over the last 48 h
///   3. Top Authors    — Ranked list of authors by total engagement
class TrendAnalysisScreen extends ConsumerStatefulWidget {
  const TrendAnalysisScreen({super.key});

  @override
  ConsumerState<TrendAnalysisScreen> createState() => _TrendAnalysisScreenState();
}

class _TrendAnalysisScreenState extends ConsumerState<TrendAnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TrendingNowTab(),
          _EngagementTimelineTab(),
          _TopAuthorsTab(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'Twitter Trend Analysis',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(49),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.accentLight,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.accent,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.tag_rounded, size: 16), text: 'Trending Now'),
                Tab(icon: Icon(Icons.show_chart_rounded, size: 16), text: 'Engagement'),
                Tab(icon: Icon(Icons.people_rounded, size: 16), text: 'Top Authors'),
              ],
            ),
            Divider(color: AppTheme.border, height: 1),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Trending Now ────────────────────────────────────────────────────────

class _TrendingNowTab extends ConsumerWidget {
  const _TrendingNowTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trendingHashtagsProvider);

    return async.when(
      loading: () => const _LoadingState(),
      error:   (e, _) => _ErrorState(message: e.toString()),
      data:    (trends) => trends.isEmpty
          ? const _EmptyState(
              icon:    Icons.tag_rounded,
              message: 'No trends yet.\nRun: node twitter_scraper.js analyze "#SIH2026"',
            )
          : _TrendingNowContent(trends: trends),
    );
  }
}

class _TrendingNowContent extends StatelessWidget {
  final List<Trend> trends;
  const _TrendingNowContent({required this.trends});

  @override
  Widget build(BuildContext context) {
    // Only take top 10 for the chart
    final chartTrends = trends.take(10).toList();
    final maxGrowth   = chartTrends.map((t) => t.growthRate).reduce(math.max);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header chips ──
          _SectionHeader(
            title: 'Top Trending Hashtags',
            subtitle: 'Ranked by growth rate (mentions/hour)',
          ),
          const SizedBox(height: 16),

          // ── Growth-rate chip row (top 5) ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chartTrends.take(5).map((t) => _GrowthChip(trend: t)).toList(),
          ),
          const SizedBox(height: 24),

          // ── Horizontal bar chart ──
          _SectionHeader(title: 'Growth Rate (mentions/hr)', subtitle: 'Last scrape window'),
          const SizedBox(height: 16),
          Container(
            height: 320,
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: _TrendBarChart(trends: chartTrends, maxGrowth: maxGrowth),
          ),
          const SizedBox(height: 24),

          // ── Ranked list ──
          _SectionHeader(title: 'All Trending Topics', subtitle: 'Sorted by growth rate'),
          const SizedBox(height: 12),
          ...trends.asMap().entries.map(
            (e) => _TrendListTile(trend: e.value, rank: e.key + 1),
          ),
        ],
      ),
    );
  }
}

class _TrendBarChart extends StatelessWidget {
  final List<Trend> trends;
  final double maxGrowth;
  const _TrendBarChart({required this.trends, required this.maxGrowth});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxGrowth * 1.25,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final t = trends[groupIndex];
              return BarTooltipItem(
                '${t.keywordOrTopic}\n${rod.toY.toStringAsFixed(1)}/hr',
                GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= trends.length) return const SizedBox.shrink();
                final label = trends[i].keywordOrTopic.replaceFirst('#', '');
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label.length > 8 ? '${label.substring(0, 7)}…' : label,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppTheme.border, strokeWidth: 1),
        ),
        barGroups: trends.asMap().entries.map((e) {
          final pct = maxGrowth > 0 ? e.value.growthRate / maxGrowth : 0.0;
          final color = Color.lerp(const Color(0xFF6366F1), const Color(0xFF10B981), pct)!;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.growthRate,
                color: color,
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxGrowth * 1.25,
                  color: AppTheme.surfaceHigh,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _GrowthChip extends StatelessWidget {
  final Trend trend;
  const _GrowthChip({required this.trend});

  @override
  Widget build(BuildContext context) {
    final color = trend.isRising ? AppTheme.sentimentPositive : AppTheme.sentimentNegative;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trend.isRising ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            trend.keywordOrTopic,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TrendListTile extends StatelessWidget {
  final Trend trend;
  final int rank;
  const _TrendListTile({required this.trend, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isRising   = trend.isRising;
    final growthColor = isRising ? AppTheme.sentimentPositive : AppTheme.sentimentNegative;
    final rankColor   = rank <= 3 ? AppTheme.accent : AppTheme.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$rank',
              style: TextStyle(color: rankColor, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),

          // Keyword + mentions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trend.keywordOrTopic,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppUtils.compactNumber(trend.mentionCount)} mentions',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),

          // Growth rate
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRising ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 14,
                    color: growthColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${trend.growthRate.toStringAsFixed(1)}/hr',
                    style: TextStyle(color: growthColor, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Mini bar
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (trend.growthRate.abs() / 100).clamp(0.05, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: growthColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Engagement Timeline ────────────────────────────────────────────────

class _EngagementTimelineTab extends ConsumerWidget {
  const _EngagementTimelineTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hourlyEngagementProvider);

    return async.when(
      loading: () => const _LoadingState(),
      error:   (e, _) => _ErrorState(message: e.toString()),
      data:    (hourly) => hourly.isEmpty
          ? const _EmptyState(
              icon:    Icons.show_chart_rounded,
              message: 'No engagement data yet.\nRun the scraper to populate posts.',
            )
          : _EngagementContent(hourly: hourly),
    );
  }
}

class _EngagementContent extends StatelessWidget {
  final List<HourlyEngagement> hourly;
  const _EngagementContent({required this.hourly});

  @override
  Widget build(BuildContext context) {
    final maxY = hourly.map((h) => h.totalEngagement).reduce(math.max).toDouble();
    final totalEngagement = hourly.fold(0, (sum, h) => sum + h.totalEngagement);
    final avgPerHour = hourly.isEmpty ? 0 : totalEngagement ~/ hourly.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Hourly Engagement',
            subtitle: 'Likes + Retweets + Replies over last 48 hours',
          ),
          const SizedBox(height: 16),

          // ── Stat chips ──
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Total Engagement', value: AppUtils.compactNumber(totalEngagement))),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Avg / Hour', value: AppUtils.compactNumber(avgPerHour))),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Data Points', value: '${hourly.length}h')),
            ],
          ),
          const SizedBox(height: 24),

          // ── Line chart ──
          _SectionHeader(title: 'Engagement Timeline', subtitle: 'Hourly totals'),
          const SizedBox(height: 16),
          Container(
            height: 280,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: _cardDecoration(),
            child: _EngagementLineChart(hourly: hourly, maxY: maxY),
          ),
          const SizedBox(height: 24),

          // ── Hour-by-hour table ──
          _SectionHeader(title: 'Hourly Breakdown', subtitle: 'All data points'),
          const SizedBox(height: 12),
          ...hourly.reversed.take(24).map((h) => _HourRow(data: h)),
        ],
      ),
    );
  }
}

class _EngagementLineChart extends StatelessWidget {
  final List<HourlyEngagement> hourly;
  final double maxY;
  const _EngagementLineChart({required this.hourly, required this.maxY});

  @override
  Widget build(BuildContext context) {
    final spots = hourly.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.totalEngagement.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppTheme.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (v, _) => Text(
                AppUtils.compactNumber(v.toInt()),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: math.max(1, (hourly.length / 6).floorToDouble()),
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= hourly.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('HH:mm').format(hourly[i].hour),
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
                  ),
                );
              },
            ),
          ),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              final h = hourly[s.spotIndex];
              return LineTooltipItem(
                '${DateFormat('MMM d, HH:mm').format(h.hour)}\n${AppUtils.compactNumber(h.totalEngagement)} eng.',
                GoogleFonts.inter(color: Colors.white, fontSize: 12),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: const Color(0xFF6366F1),
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: const Color(0xFF6366F1),
                strokeColor: AppTheme.background,
                strokeWidth: 1.5,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.3),
                  const Color(0xFF6366F1).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  color: AppTheme.accentLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 22)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _HourRow extends StatelessWidget {
  final HourlyEngagement data;
  const _HourRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Text(
            DateFormat('MMM d · HH:mm').format(data.hour),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const Spacer(),
          Text(
            AppUtils.compactNumber(data.totalEngagement),
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(width: 4),
          const Text('eng', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Tab 3: Top Authors ─────────────────────────────────────────────────────────

class _TopAuthorsTab extends ConsumerWidget {
  const _TopAuthorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topAuthorsProvider);

    return async.when(
      loading: () => const _LoadingState(),
      error:   (e, _) => _ErrorState(message: e.toString()),
      data:    (authors) => authors.isEmpty
          ? const _EmptyState(
              icon:    Icons.people_rounded,
              message: 'No authors yet.\nRun the scraper to populate posts.',
            )
          : _AuthorsContent(authors: authors),
    );
  }
}

class _AuthorsContent extends StatelessWidget {
  final List<AuthorEngagement> authors;
  const _AuthorsContent({required this.authors});

  @override
  Widget build(BuildContext context) {
    final maxEng = authors.first.totalEngagement;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Top Authors by Engagement',
            subtitle: 'Total likes + retweets + replies',
          ),
          const SizedBox(height: 20),

          // ── Podium (top 3) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (authors.length > 1) _PodiumCard(author: authors[1], position: 2, height: 80),
              const SizedBox(width: 8),
              if (authors.isNotEmpty)  _PodiumCard(author: authors[0], position: 1, height: 110),
              const SizedBox(width: 8),
              if (authors.length > 2)  _PodiumCard(author: authors[2], position: 3, height: 60),
            ],
          ),
          const SizedBox(height: 28),

          // ── Ranked list 4–20 ──
          _SectionHeader(title: 'Full Rankings', subtitle: 'Authors 1–${authors.length}'),
          const SizedBox(height: 12),
          ...authors.asMap().entries.map(
            (e) => _AuthorListTile(author: e.value, rank: e.key + 1, maxEng: maxEng),
          ),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final AuthorEngagement author;
  final int position;
  final double height;
  const _PodiumCard({required this.author, required this.position, required this.height});

  static const _posColors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _posColors[position - 1];
    final initial = author.displayName.isNotEmpty ? author.displayName[0].toUpperCase() : '?';

    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: position == 1 ? 28 : 22,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Text(
              initial,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: position == 1 ? 20 : 16,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '@${author.handle}',
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 11),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            AppUtils.compactNumber(author.totalEngagement),
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$position',
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorListTile extends StatelessWidget {
  final AuthorEngagement author;
  final int rank;
  final int maxEng;
  const _AuthorListTile({required this.author, required this.rank, required this.maxEng});

  @override
  Widget build(BuildContext context) {
    final pct = maxEng > 0 ? author.totalEngagement / maxEng : 0.0;
    final barColor = Color.lerp(const Color(0xFF6366F1), const Color(0xFF10B981), 1 - pct)!;
    final initial  = author.displayName.isNotEmpty ? author.displayName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 28,
            child: Text('#$rank',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(width: 8),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: barColor.withValues(alpha: 0.2),
            child: Text(initial, style: TextStyle(color: barColor, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),

          // Name + handle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(author.displayName,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('@${author.handle}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),

          // Engagement + bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(AppUtils.compactNumber(author.totalEngagement),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                width: 80,
                height: 4,
                decoration:
                    BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: pct.clamp(0.05, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                        color: barColor, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Center(
      child: CircularProgressIndicator(color: AppTheme.accent));
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) => Center(
      child: Text('Error: $message',
          style: const TextStyle(color: AppTheme.sentimentNegative)));
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Shared decoration helper ──────────────────────────────────────────────────

BoxDecoration _cardDecoration() => BoxDecoration(
      color: AppTheme.surfaceHigh,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border),
    );
