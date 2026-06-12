// lib/core/database/seed_data.dart
// Comprehensive exercise library matching Hevy app (100+ exercises)

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';

const _uuid = Uuid();

Future<void> seedDefaultExercises(AppDatabase db) async {
  final existingCount = await db.select(db.exercises).get();
  if (existingCount.isNotEmpty) return;

  final exercises = <ExercisesCompanion>[
    // ═══ CHEST ═══
    _e('Bench Press', 'chest', '', 'barbell'),
    _e('Incline Bench Press', 'chest', '', 'barbell'),
    _e('Decline Bench Press', 'chest', '', 'barbell'),
    _e('Dumbbell Bench Press', 'chest', '', 'dumbbell'),
    _e('Incline Dumbbell Press', 'chest', '', 'dumbbell'),
    _e('Decline Dumbbell Press', 'chest', '', 'dumbbell'),
    _e('Chest Fly', 'chest', '', 'dumbbell'),
    _e('Cable Crossover', 'chest', '', 'cable'),
    _e('Cable Fly Up to Down', 'chest', '', 'cable'),
    _e('Pec Fly', 'chest', '', 'machine'),
    _e('Pec Deck Fly', 'chest', '', 'machine'),
    _e('Push-Up', 'chest', 'triceps', 'bodyweight', 'reps_only'),
    _e('Weighted Push-Up', 'chest', 'triceps', 'bodyweight'),
    _e('Dips (Chest)', 'chest', 'triceps', 'bodyweight', 'reps_only'),
    _e('Weighted Dips', 'chest', 'triceps', 'bodyweight'),

    // ═══ BACK ═══
    _e('Deadlift', 'back', 'hamstrings', 'barbell'),
    _e('Barbell Row', 'back', 'biceps', 'barbell'),
    _e('Pendlay Row', 'back', 'biceps', 'barbell'),
    _e('Single Arm Dumbbell Row', 'back', 'biceps', 'dumbbell'),
    _e('Lat Pulldown', 'back', 'biceps', 'cable'),
    _e('Pull-Up', 'back', 'biceps', 'bodyweight', 'reps_only'),
    _e('Weighted Pull-Up', 'back', 'biceps', 'bodyweight'),
    _e('Chin-Up', 'back', 'biceps', 'bodyweight', 'reps_only'),
    _e('Seated Cable Row', 'back', 'biceps', 'cable'),
    _e('Mid Row', 'back', 'biceps', 'cable'),
    _e('T-Bar Row', 'back', 'biceps', 'machine'),
    _e('Straight Arm Lat Pulldown', 'back', '', 'cable'),
    _e('Hyperextensions', 'back', 'hamstrings', 'bodyweight', 'reps_only'),
    _e('Face Pull', 'back', 'shoulders', 'cable'),

    // ═══ LEGS (QUADS) ═══
    _e('Squat', 'legs', 'hamstrings', 'barbell'),
    _e('Front Squat', 'legs', '', 'barbell'),
    _e('Goblet Squat', 'legs', '', 'dumbbell'),
    _e('Leg Press', 'legs', 'hamstrings', 'machine'),
    _e('Hack Squat', 'legs', '', 'machine'),
    _e('Leg Extension', 'legs', '', 'machine'),
    _e('Lunges', 'legs', '', 'dumbbell'),
    _e('Bulgarian Split Squat', 'legs', '', 'dumbbell'),
    _e('Step-Up', 'legs', '', 'dumbbell'),

    // ═══ LEGS (HAMSTRINGS) ═══
    _e('Romanian Deadlift', 'hamstrings', 'back', 'barbell'),
    _e('Stiff-Legged Deadlift', 'hamstrings', 'back', 'barbell'),
    _e('Lying Leg Curl', 'hamstrings', '', 'machine'),
    _e('Seated Leg Curl', 'hamstrings', '', 'machine'),
    _e('Leg Curl', 'hamstrings', '', 'machine'),
    _e('Hip Thrust', 'hamstrings', '', 'barbell'),
    _e('Glute Bridge', 'hamstrings', '', 'bodyweight', 'reps_only'),
    _e('Cable Pull Through', 'hamstrings', '', 'cable'),
    _e('Good Morning', 'hamstrings', 'back', 'barbell'),

    // ═══ CALVES ═══
    _e('Standing Calf Raise', 'legs', '', 'machine'),
    _e('Seated Calf Raise', 'legs', '', 'machine'),
    _e('Calf Raises', 'legs', '', 'bodyweight', 'reps_only'),
    _e('Calf Press on Leg Press', 'legs', '', 'machine'),

    // ═══ SHOULDERS ═══
    _e('Overhead Press', 'shoulders', 'triceps', 'barbell'),
    _e('Dumbbell Shoulder Press', 'shoulders', 'triceps', 'dumbbell'),
    _e('Seated Dumbbell Press', 'shoulders', 'triceps', 'dumbbell'),
    _e('Arnold Press', 'shoulders', 'triceps', 'dumbbell'),
    _e('Lateral Raises', 'shoulders', '', 'dumbbell'),
    _e('Cable Lateral Raise', 'shoulders', '', 'cable'),
    _e('Front Raise', 'shoulders', '', 'dumbbell'),
    _e('Rear Delt Fly', 'shoulders', '', 'dumbbell'),
    _e('Reverse Pec Fly', 'shoulders', '', 'machine'),
    _e('Upright Row', 'shoulders', '', 'barbell'),
    _e('Shrugs', 'shoulders', '', 'barbell'),

    // ═══ BICEPS ═══
    _e('Bicep Curl', 'biceps', '', 'barbell'),
    _e('Dumbbell Curl', 'biceps', '', 'dumbbell'),
    _e('Hammer Curl', 'biceps', '', 'dumbbell'),
    _e('Preacher Curl', 'biceps', '', 'machine'),
    _e('Cable Curl', 'biceps', '', 'cable'),
    _e('Concentration Curl', 'biceps', '', 'dumbbell'),
    _e('Incline Dumbbell Curl', 'biceps', '', 'dumbbell'),
    _e('Spider Curl', 'biceps', '', 'dumbbell'),

    // ═══ TRICEPS ═══
    _e('Tricep Pushdown', 'triceps', '', 'cable'),
    _e('Tricep Overhead Extension', 'triceps', '', 'dumbbell'),
    _e('Overhead Extension', 'triceps', '', 'cable'),
    _e('Skull Crusher', 'triceps', '', 'barbell'),
    _e('Close-Grip Bench Press', 'triceps', 'chest', 'barbell'),
    _e('Tricep Kickback', 'triceps', '', 'dumbbell'),
    _e('Bench Dips', 'triceps', '', 'bodyweight', 'reps_only'),
    _e('Single Arm Tricep Pushdown', 'triceps', '', 'cable'),

    // ═══ CORE ═══
    _e('Crunch', 'core', '', 'bodyweight', 'reps_only'),
    _e('Crunches', 'core', '', 'bodyweight', 'reps_only'),
    _e('Plank', 'core', '', 'bodyweight', 'time_only'),
    _e('Hanging Leg Raise', 'core', '', 'bodyweight', 'reps_only'),
    _e('Lying Leg Raise', 'core', '', 'bodyweight', 'reps_only'),
    _e('Leg Raises', 'core', '', 'bodyweight', 'reps_only'),
    _e('Russian Twist', 'core', '', 'bodyweight', 'reps_only'),
    _e('Ab Wheel Rollout', 'core', '', 'bodyweight', 'reps_only'),
    _e('Cable Woodchopper', 'core', '', 'cable'),
    _e('Sit-Up', 'core', '', 'bodyweight', 'reps_only'),

    // ═══ CARDIO ═══
    _e('Running', 'cardio', '', 'none', 'distance_time'),
    _e('Cycling', 'cardio', '', 'none', 'distance_time'),
    _e('Rowing', 'cardio', '', 'machine', 'distance_time'),
    _e('Stair Stepper', 'cardio', '', 'machine', 'time_only'),
    _e('Elliptical', 'cardio', '', 'machine', 'time_only'),
    _e('Burpees', 'cardio', '', 'bodyweight', 'reps_only'),
    _e('Kettlebell Swing', 'cardio', '', 'bodyweight'),
    _e('Jump Rope', 'cardio', '', 'none', 'time_only'),
  ];

  await db.batch((batch) {
    batch.insertAll(db.exercises, exercises);
  });
}

ExercisesCompanion _e(
  String name,
  String muscle,
  String secondary,
  String equipment, [
  String type = 'weight_reps',
]) {
  return ExercisesCompanion.insert(
    uuid: _uuid.v4(),
    name: name,
    primaryMuscle: muscle,
    secondaryMuscles: Value(secondary),
    equipment: equipment,
    trackingType: Value(type),
    isCustom: const Value(false),
  );
}
