import 'package:intl/intl.dart';

/// Shared utility functions used across the app.
class AppUtils {
  AppUtils._();

  static final DateFormat _shortDate = DateFormat('MMM d, HH:mm');
  static final DateFormat _timeOnly  = DateFormat('HH:mm');

  /// Formats a DateTime as "Sep 4, 14:32"
  static String formatShort(DateTime dt) => _shortDate.format(dt.toLocal());

  /// Formats a DateTime as "14:32"
  static String formatTime(DateTime dt) => _timeOnly.format(dt.toLocal());

  /// Returns a human-readable "X minutes ago" / "X hours ago" string.
  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Formats large numbers: 128400 → "128.4K"
  static String compactNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  /// Formats a growth rate float: 127.4 → "+127.4%"
  static String formatGrowthRate(double rate) {
    final prefix = rate >= 0 ? '+' : '';
    return '$prefix${rate.toStringAsFixed(1)}%';
  }
}
