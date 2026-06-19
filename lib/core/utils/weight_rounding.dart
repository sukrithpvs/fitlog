// lib/core/utils/weight_rounding.dart

class WeightRounding {
  WeightRounding._();

  /// Rounds a weight value to the nearest increment.
  /// Standard plate increments in gyms are often 2.5kg (1.25kg per side).
  /// For dumbbells, increments are usually 2.0kg or 2.5kg.
  static double roundToNearest(double weight, {double increment = 2.5}) {
    if (increment <= 0) return weight;
    return (weight / increment).round() * increment;
  }

  /// Floors a weight value to the nearest increment (conservative progression).
  static double floorToNearest(double weight, {double increment = 2.5}) {
    if (increment <= 0) return weight;
    return (weight / increment).floor() * increment;
  }
}
