// lib/core/database/seed_routines.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';

Future<void> seedDefaultRoutines(AppDatabase db) async {
  final existingRoutines = await db.getAllWorkouts(templatesOnly: true);
  if (existingRoutines.isNotEmpty) return;

  const uuid = Uuid();

  // Demo Routine - Full Body
  final demoId = await db.insertWorkout(
    WorkoutsCompanion.insert(
      uuid: uuid.v4(),
      title: 'Demo Routine - Full Body',
      startTime: DateTime.now(),
      isTemplate: const Value(true),
      notes: const Value('A balanced full body workout'),
    ),
  );

  await _addExerciseSets(db, demoId, [
    ('Squat', 3),
    ('Bench Press', 3),
    ('Barbell Row', 3),
    ('Overhead Press', 3),
    ('Deadlift', 1),
    ('Bicep Curl', 2),
    ('Tricep Pushdown', 2),
  ]);
}

Future<void> _addExerciseSets(
  AppDatabase db,
  int workoutId,
  List<(String name, int sets)> exercises,
) async {
  const uuid = Uuid();
  int setOrder = 0;

  for (final (name, setCount) in exercises) {
    // Try to find matching exercise in DB
    final allExercises = await db.getAllExercises();
    final exercise = allExercises.where((e) => 
      e.name.toLowerCase().contains(name.toLowerCase().split(' ')[0])
    ).firstOrNull;

    final exerciseId = exercise?.id ?? 1;
    final exerciseName = exercise?.name ?? name;

    for (int i = 0; i < setCount; i++) {
      await db.insertWorkoutSet(
        WorkoutSetsCompanion.insert(
          uuid: uuid.v4(),
          workoutId: workoutId,
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          setOrder: setOrder++,
          weight: const Value(null),
          reps: const Value(null),
          setType: const Value('normal'),
        ),
      );
    }
  }
}
