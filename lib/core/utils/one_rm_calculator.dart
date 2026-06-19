// lib/core/utils/one_rm_calculator.dart
// Estimated 1 Rep Max calculator using the Epley formula.
// Used in analytics charts for progression tracking.

class OneRmCalculator {
  OneRmCalculator._();

  /// Epley formula: 1RM = weight × (1 + reps / 30)
  /// Returns null if either value is missing, reps = 0, or reps > 12 (inaccurate for high reps)
  static double? epley(double? weight, int? reps) {
    if (weight == null || reps == null || reps <= 0 || reps > 12 || weight <= 0) return null;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30);
  }

  /// Brzycki formula (alternative): 1RM = weight × (36 / (37 - reps))
  /// Returns null if either value is missing, reps = 0, or reps > 12
  static double? brzycki(double? weight, int? reps) {
    if (weight == null || reps == null || reps <= 0 || reps > 12 || weight <= 0) return null;
    if (reps == 1) return weight;
    return weight * (36 / (37 - reps));
  }

  /// Calculate total volume for a set (weight × reps)
  static double? volume(double? weight, int? reps) {
    if (weight == null || reps == null) return null;
    return weight * reps;
  }
}
