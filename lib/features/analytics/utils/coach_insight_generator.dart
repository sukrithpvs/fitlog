// lib/features/analytics/utils/coach_insight_generator.dart

import '../../../core/database/app_database.dart';

class CoachInsightGenerator {
  /// Analyzes the user's recent training data and returns a personalized coach insight.
  static Future<String> generateMonthlyInsight(
    AppDatabase db,
    List<Workout> monthWorkouts,
    Map<String, double> muscleCounts,
    Map<int, int> exerciseCounts,
  ) async {
    if (monthWorkouts.isEmpty || muscleCounts.isEmpty) {
      return 'No workouts logged this month. Let\'s get to work!';
    }

    final totalSets = muscleCounts.values.fold<double>(0.0, (a, b) => a + b);
    final mostTrainedMuscle = muscleCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final musclePct = (muscleCounts[mostTrainedMuscle]! / totalSets) * 100;

    // 1. Deload Detection
    if (monthWorkouts.length >= 20 && totalSets > 400) {
      return "High volume detected! You've trained a lot this month. If you're feeling fatigued or progress has stalled, consider scheduling a Deload Week at 50-60% of your normal volume.";
    }

    // 2. Plateau / Exercise Substitution Suggestion
    if (exerciseCounts.isNotEmpty) {
      // Find the most frequent exercise this month
      final mostFrequentExId = exerciseCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      final ex = await (db.select(db.exercises)..where((e) => e.id.equals(mostFrequentExId))).getSingleOrNull();
      
      if (ex != null && exerciseCounts[mostFrequentExId]! > 8) {
        // If they did this exercise > 8 times this month, suggest a substitution to avoid staleness
        return "You've been doing a lot of ${ex.name} recently. If your progress on it is slowing down, consider substituting it with another ${ex.primaryMuscle} exercise next month to spur new adaptation.";
      }
    }

    // 3. Weekly Targets Missing
    final targets = await db.select(db.weeklyTargets).get();
    if (targets.isNotEmpty) {
      for (final target in targets) {
        final done = (muscleCounts[target.muscleGroup] ?? 0) / 4.0; // average per week
        if (done < target.targetSets * 0.5) {
          return "You're consistently missing your ${target.muscleGroup} target. Consider prioritizing it early in the week.";
        }
      }
    }

    // 4. Muscle Imbalance
    if (musclePct > 50) {
      return "You're heavily focusing on $mostTrainedMuscle (${musclePct.toStringAsFixed(0)}% of sets). Make sure you aren't neglecting other areas!";
    }

    // 5. Default Positive
    return "Great balance! Your most trained muscle was $mostTrainedMuscle, but your overall routine is well-rounded.";
  }
}
