// lib/core/constants/muscle_groups.dart

enum MuscleGroup {
  chest('Chest'),
  back('Back'),
  legs('Legs (Quads/Glutes)'),
  hamstrings('Legs (Hamstrings)'),
  shoulders('Shoulders'),
  biceps('Arms (Biceps)'),
  triceps('Arms (Triceps)'),
  core('Core'),
  cardio('Cardio');

  final String displayName;
  const MuscleGroup(this.displayName);

  static MuscleGroup fromString(String value) {
    return MuscleGroup.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MuscleGroup.chest,
    );
  }
}
