// lib/core/utils/date_formatter.dart
// Human-friendly date/time formatting for workout logs and history.

import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final _timeFormat = DateFormat('h:mm a');
  static final _shortDateFormat = DateFormat('MMM d');
  static final _fullDateFormat = DateFormat('EEEE, MMM d, y');
  static final _monthYearFormat = DateFormat('MMMM y');

  /// "9:30 AM"
  static String time(DateTime dt) => _timeFormat.format(dt);

  /// "Jun 12"
  static String shortDate(DateTime dt) => _shortDateFormat.format(dt);

  /// "Wednesday, Jun 12, 2026"
  static String fullDate(DateTime dt) => _fullDateFormat.format(dt);

  /// "June 2026"
  static String monthYear(DateTime dt) => _monthYearFormat.format(dt);

  /// "Today", "Yesterday", or "Jun 12"
  static String relative(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    return shortDate(dt);
  }

  /// "1h 23m" or "45m" or "2m"
  static String duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Format seconds to "1:30" for rest timer display
  static String timerSeconds(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}
