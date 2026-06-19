// lib/features/analytics/utils/streak_calculator.dart
import '../../../core/database/app_database.dart';

class StreakData {
  final int currentStreak;
  final int bestStreak;
  const StreakData({required this.currentStreak, required this.bestStreak});
}

class StreakCalculator {
  static StreakData calculateWeeklyStreak(List<Workout> workouts) {
    if (workouts.isEmpty) return const StreakData(currentStreak: 0, bestStreak: 0);

    final weeksWithWorkouts = <int>{};
    for (final w in workouts) {
      if (w.endTime == null) continue; // Only count completed
      weeksWithWorkouts.add(_getWeekNumber(w.startTime));
    }

    if (weeksWithWorkouts.isEmpty) return const StreakData(currentStreak: 0, bestStreak: 0);

    final sortedWeeks = weeksWithWorkouts.toList()..sort((a, b) => b.compareTo(a)); // Descending

    int currentStreak = 0;
    int bestStreak = 0;
    int tempStreak = 0;

    final currentWeek = _getWeekNumber(DateTime.now());
    
    for (int i = 0; i < sortedWeeks.length; i++) {
      if (i == 0) {
        tempStreak = 1;
      } else {
        if (sortedWeeks[i] == sortedWeeks[i - 1] - 1) {
          tempStreak++;
        } else {
          if (tempStreak > bestStreak) bestStreak = tempStreak;
          if (currentStreak == 0) {
            // Check if the broken streak was the current one
            if (sortedWeeks[0] == currentWeek || sortedWeeks[0] == currentWeek - 1) {
              currentStreak = tempStreak;
            } else {
              currentStreak = 0;
            }
          }
          tempStreak = 1;
        }
      }
    }
    
    if (tempStreak > bestStreak) bestStreak = tempStreak;
    if (currentStreak == 0) {
      if (sortedWeeks[0] == currentWeek || sortedWeeks[0] == currentWeek - 1) {
        currentStreak = tempStreak;
      }
    }

    return StreakData(currentStreak: currentStreak, bestStreak: bestStreak);
  }

  static int _getWeekNumber(DateTime date) {
    // Days since epoch
    final daysSinceEpoch = date.millisecondsSinceEpoch ~/ 86400000;
    // Jan 1 1970 was a Thursday. Add 3 to shift week start to Monday.
    return (daysSinceEpoch + 3) ~/ 7;
  }
}
