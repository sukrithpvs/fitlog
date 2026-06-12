// lib/core/constants/set_types.dart

enum SetType {
  normal('N', 'Normal'),
  warmup('W', 'Warm-up'),
  drop('D', 'Drop Set'),
  failure('F', 'Failure');

  final String badge;
  final String displayName;
  const SetType(this.badge, this.displayName);

  static SetType fromString(String value) {
    return SetType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SetType.normal,
    );
  }
}

enum TrackingType {
  weightReps('weight_reps', 'Weight & Reps'),
  repsOnly('reps_only', 'Reps Only'),
  timeOnly('time_only', 'Time Only'),
  distanceTime('distance_time', 'Distance & Time');

  final String value;
  final String displayName;
  const TrackingType(this.value, this.displayName);

  static TrackingType fromString(String value) {
    return TrackingType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TrackingType.weightReps,
    );
  }
}
