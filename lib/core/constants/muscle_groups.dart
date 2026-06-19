// lib/core/constants/muscle_groups.dart

enum MuscleGroup {
  chest('Chest'),
  back('Back'),
  traps('Traps'),
  legs('Legs (Quads)'),
  glutes('Glutes'),
  hamstrings('Legs (Hamstrings)'),
  calves('Calves'),
  shoulders('Shoulders'),
  biceps('Arms (Biceps)'),
  triceps('Arms (Triceps)'),
  forearms('Forearms'),
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
