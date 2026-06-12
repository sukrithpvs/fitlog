// lib/core/database/seed_routines.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';

Future<void> seedDefaultRoutines(AppDatabase db) async {
  final existingRoutines = await db.getAllWorkouts(templatesOnly: true);
  if (existingRoutines.isNotEmpty) return;

  const uuid = Uuid();

  // Monday - Chest & Triceps
  final mondayId = await db.insertWorkout(
    WorkoutsCompanion.insert(
      uuid: uuid.v4(),
      title: 'Monday - Chest & Triceps',
      startTime: DateTime.now(),
      isTemplate: const Value(true),
      notes: const Value('Chest and triceps focus day'),
    ),
  );

  await _addExerciseSets(db, mondayId, [
    ('Incline Dumbbell Press', 3),
    ('Flat Dumbbell Press', 2),
    ('Cable Fly Up to Down', 3),
    ('Pec Fly', 3),
    ('Tricep Pushdown', 3),
    ('Tricep Overhead Extension', 3),
    ('Lateral Raises', 4),
  ]);

  // Tuesday - Back & Biceps
  final tuesdayId = await db.insertWorkout(
    WorkoutsCompanion.insert(
      uuid: uuid.v4(),
      title: 'Tuesday - Back & Biceps',
      startTime: DateTime.now(),
      isTemplate: const Value(true),
      notes: const Value('Back and biceps focus day'),
    ),
  );

  await _addExerciseSets(db, tuesdayId, [
    ('Lat Pulldown', 3),
    ('Barbell Row', 3),
    ('Mid Row', 3),
    ('Single Arm Dumbbell Row', 3),
    ('Hyperextensions', 3),
    ('Bicep Curl', 3),
    ('Hammer Curl', 3),
  ]);

  // Wednesday - Legs
  final wednesdayId = await db.insertWorkout(
    WorkoutsCompanion.insert(
      uuid: uuid.v4(),
      title: 'Wednesday - Legs',
      startTime: DateTime.now(),
      isTemplate: const Value(true),
      notes: const Value('Leg day'),
    ),
  );

  await _addExerciseSets(db, wednesdayId, [
    ('Squat', 3),
    ('Lunges', 2),
    ('Leg Extension', 3),
    ('Leg Curl', 3),
    ('Calf Raises', 3),
  ]);

  // Thursday - Shoulders & Abs
  final thursdayId = await db.insertWorkout(
    WorkoutsCompanion.insert(
      uuid: uuid.v4(),
      title: 'Thursday - Shoulders & Abs',
      startTime: DateTime.now(),
      isTemplate: const Value(true),
      notes: const Value('Shoulders and abs focus day'),
    ),
  );

  await _addExerciseSets(db, thursdayId, [
    ('Dumbbell Shoulder Press', 3),
    ('Lateral Raises', 4),
    ('Face Pull', 2),
    ('Reverse Pec Fly', 3),
    ('Shrugs', 3),
    ('Leg Raises', 3),
    ('Crunches', 3),
  ]);

  // Friday - Arms
  final fridayId = await db.insertWorkout(
    WorkoutsCompanion.insert(
      uuid: uuid.v4(),
      title: 'Friday - Arms',
      startTime: DateTime.now(),
      isTemplate: const Value(true),
      notes: const Value('Dedicated arm day'),
    ),
  );

  await _addExerciseSets(db, fridayId, [
    ('Incline Dumbbell Curl', 3),
    ('Preacher Curl', 3),
    ('Hammer Curl', 3),
    ('Tricep Pushdown', 3),
    ('Tricep Overhead Extension', 3),
    ('Single Arm Tricep Pushdown', 3),
  ]);

  // Saturday - Chest & Back (Optional)
  final saturdayId = await db.insertWorkout(
    WorkoutsCompanion.insert(
      uuid: uuid.v4(),
      title: 'Saturday - Chest & Back (Optional)',
      startTime: DateTime.now(),
      isTemplate: const Value(true),
      notes: const Value('Optional upper body pump day'),
    ),
  );

  await _addExerciseSets(db, saturdayId, [
    ('Incline Dumbbell Press', 2),
    ('Flat Dumbbell Press', 2),
    ('Cable Fly Up to Down', 3),
    ('Pec Fly', 2),
    ('Lat Pulldown', 3),
    ('Mid Row', 3),
    ('Single Arm Dumbbell Row', 3),
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
