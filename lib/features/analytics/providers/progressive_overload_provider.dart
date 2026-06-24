// lib/features/analytics/providers/progressive_overload_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import 'package:drift/drift.dart';

class OverloadStats {
  final double recentVolume; // Last 14 days
  final double previousVolume; // Prior 14 days (15-28 days ago)
  final double percentageChange;

  OverloadStats({
    required this.recentVolume,
    required this.previousVolume,
  }) : percentageChange = previousVolume > 0 
          ? ((recentVolume - previousVolume) / previousVolume) * 100 
          : (recentVolume > 0 ? 100 : 0);
}

final progressiveOverloadProvider = FutureProvider<OverloadStats>((ref) async {
  final db = ref.watch(databaseProvider);
  
  final now = DateTime.now();
  final twoWeeksAgo = now.subtract(const Duration(days: 14));
  final fourWeeksAgo = now.subtract(const Duration(days: 28));

  // We only fetch completed sets in the last 28 days
  final recentSets = await (db.select(db.workoutSets)
        ..where((s) => s.isCompleted.equals(true))
        ..where((s) => s.completedAt.isBiggerOrEqualValue(fourWeeksAgo)))
      .get();

  double recentVolume = 0;
  double previousVolume = 0;

  for (final set in recentSets) {
    if (set.weight != null && set.reps != null && set.completedAt != null) {
      final volume = set.weight! * set.reps!;
      if (set.completedAt!.isAfter(twoWeeksAgo)) {
        recentVolume += volume;
      } else {
        previousVolume += volume;
      }
    }
  }

  return OverloadStats(
    recentVolume: recentVolume,
    previousVolume: previousVolume,
  );
});
