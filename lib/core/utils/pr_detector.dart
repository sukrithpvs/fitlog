// lib/core/utils/pr_detector.dart
// Automatic Personal Record (PR) detection
// Detects when user achieves new max weight, volume, or 1RM for an exercise

import '../database/app_database.dart';
import 'one_rm_calculator.dart';

enum PRType {
  maxWeight,
  maxVolume,
  max1RM,
}

class PersonalRecord {
  final PRType type;
  final double value;
  final DateTime achievedAt;
  final WorkoutSet set;

  PersonalRecord({
    required this.type,
    required this.value,
    required this.achievedAt,
    required this.set,
  });
}

class PRDetector {
  PRDetector._();

  /// Check if a set is a new personal record
  static Future<List<PersonalRecord>> detectPRs(
    WorkoutSet newSet,
    List<WorkoutSet> previousSets,
  ) async {
    final prs = <PersonalRecord>[];

    if (!newSet.isCompleted || newSet.weight == null || newSet.reps == null) {
      return prs;
    }

    final completedPreviousSets = previousSets
        .where((s) => s.isCompleted && s.weight != null && s.reps != null)
        .toList();

    if (completedPreviousSets.isEmpty) {
      // First time doing this exercise - everything is a PR!
      return prs;
    }

    // Check max weight
    final maxPreviousWeight = completedPreviousSets
        .map((s) => s.weight!)
        .reduce((a, b) => a > b ? a : b);
    
    if (newSet.weight! > maxPreviousWeight) {
      prs.add(PersonalRecord(
        type: PRType.maxWeight,
        value: newSet.weight!,
        achievedAt: newSet.completedAt ?? DateTime.now(),
        set: newSet,
      ));
    }

    // Check max volume (weight × reps)
    final newVolume = newSet.weight! * newSet.reps!;
    final maxPreviousVolume = completedPreviousSets
        .map((s) => s.weight! * s.reps!)
        .reduce((a, b) => a > b ? a : b);
    
    if (newVolume > maxPreviousVolume) {
      prs.add(PersonalRecord(
        type: PRType.maxVolume,
        value: newVolume,
        achievedAt: newSet.completedAt ?? DateTime.now(),
        set: newSet,
      ));
    }

    // Check max 1RM
    final new1RM = OneRmCalculator.epley(newSet.weight, newSet.reps);
    if (new1RM != null) {
      final previous1RMs = completedPreviousSets
          .map((s) => OneRmCalculator.epley(s.weight, s.reps))
          .where((rm) => rm != null)
          .map((rm) => rm!)
          .toList();
      
      if (previous1RMs.isNotEmpty) {
        final maxPrevious1RM = previous1RMs.reduce((a, b) => a > b ? a : b);
        if (new1RM > maxPrevious1RM) {
          prs.add(PersonalRecord(
            type: PRType.max1RM,
            value: new1RM,
            achievedAt: newSet.completedAt ?? DateTime.now(),
            set: newSet,
          ));
        }
      }
    }

    return prs;
  }

  /// Get all PRs for an exercise
  static Map<PRType, double> getExercisePRs(List<WorkoutSet> sets) {
    final completed = sets
        .where((s) => s.isCompleted && s.weight != null && s.reps != null)
        .toList();

    if (completed.isEmpty) {
      return {};
    }

    final prs = <PRType, double>{};

    // Max weight
    prs[PRType.maxWeight] = completed
        .map((s) => s.weight!)
        .reduce((a, b) => a > b ? a : b);

    // Max volume
    prs[PRType.maxVolume] = completed
        .map((s) => s.weight! * s.reps!)
        .reduce((a, b) => a > b ? a : b);

    // Max 1RM
    final oneRMs = completed
        .map((s) => OneRmCalculator.epley(s.weight, s.reps))
        .where((rm) => rm != null)
        .map((rm) => rm!)
        .toList();
    
    if (oneRMs.isNotEmpty) {
      prs[PRType.max1RM] = oneRMs.reduce((a, b) => a > b ? a : b);
    }

    return prs;
  }

  /// Check if a specific set is a PR
  static bool isPR(WorkoutSet set, List<WorkoutSet> previousSets, PRType type) {
    if (!set.isCompleted || set.weight == null || set.reps == null) {
      return false;
    }

    final completed = previousSets
        .where((s) => 
          s.isCompleted && 
          s.weight != null && 
          s.reps != null &&
          s.id != set.id &&
          (s.completedAt?.isBefore(set.completedAt ?? DateTime.now()) ?? false)
        )
        .toList();

    if (completed.isEmpty) return false;

    switch (type) {
      case PRType.maxWeight:
        final maxPrevious = completed
            .map((s) => s.weight!)
            .reduce((a, b) => a > b ? a : b);
        return set.weight! > maxPrevious;

      case PRType.maxVolume:
        final setVolume = set.weight! * set.reps!;
        final maxPrevious = completed
            .map((s) => s.weight! * s.reps!)
            .reduce((a, b) => a > b ? a : b);
        return setVolume > maxPrevious;

      case PRType.max1RM:
        final set1RM = OneRmCalculator.epley(set.weight, set.reps);
        if (set1RM == null) return false;
        
        final previous1RMs = completed
            .map((s) => OneRmCalculator.epley(s.weight, s.reps))
            .where((rm) => rm != null)
            .map((rm) => rm!)
            .toList();
        
        if (previous1RMs.isEmpty) return false;
        final maxPrevious = previous1RMs.reduce((a, b) => a > b ? a : b);
        return set1RM > maxPrevious;
    }
  }
}
