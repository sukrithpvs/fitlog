// lib/core/utils/weight_converter.dart
// Converts between kg and lbs for display purposes.
// Internal storage is always in kg.

class WeightConverter {
  WeightConverter._();

  static const double _kgToLbs = 2.20462;

  /// Convert kg to lbs
  static double toLbs(double kg) => kg * _kgToLbs;

  /// Convert lbs to kg
  static double toKg(double lbs) => lbs / _kgToLbs;

  /// Display weight in the user's preferred unit
  static String display(double? weightKg, String unit, {int decimals = 1}) {
    if (weightKg == null) return '-';
    final value = unit == 'lbs' ? toLbs(weightKg) : weightKg;
    return '${value.toStringAsFixed(decimals)} $unit';
  }

  /// Convert from display unit back to kg for storage
  static double toStorageKg(double displayValue, String unit) {
    return unit == 'lbs' ? toKg(displayValue) : displayValue;
  }

  /// Convert from kg to display unit value
  static double toDisplayValue(double kg, String unit) {
    return unit == 'lbs' ? toLbs(kg) : kg;
  }
}
