// lib/features/routines/data/routine_repository.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';

class RoutineRepository {
  final AppDatabase _db;
  const RoutineRepository(this._db);

  Stream<List<Workout>> watchRoutines() => _db.watchRoutines();

  Future<Workout> getRoutine(int id) async {
    return await (_db.select(_db.workouts)..where((w) => w.id.equals(id))).getSingle();
  }

  Future<int> createRoutine({
    required String title,
    int? folderId,
    String? notes,
  }) {
    return _db.insertWorkout(
      WorkoutsCompanion.insert(
        uuid: const Uuid().v4(),
        title: title,
        startTime: DateTime.now(),
        isTemplate: const Value(true),
        folderId: Value(folderId),
        notes: Value(notes),
      ),
    );
  }

  Future<void> updateRoutine(Workout routine) {
    return _db.updateWorkout(
      WorkoutsCompanion(
        id: Value(routine.id),
        uuid: Value(routine.uuid),
        title: Value(routine.title),
        startTime: Value(routine.startTime),
        isTemplate: Value(routine.isTemplate),
        folderId: Value(routine.folderId),
        notes: Value(routine.notes),
      ),
    );
  }

  Future<void> deleteRoutine(int id) async {
    await _db.deleteSetsForWorkout(id);
    await _db.deleteWorkout(id);
  }

  Future<int> duplicateRoutine(int routineId, String newTitle) async {
    final routine = await getRoutine(routineId);
    final sets = await _db.getSetsForWorkout(routineId);

    final newRoutineId = await createRoutine(
      title: newTitle,
      folderId: routine.folderId,
      notes: routine.notes,
    );

    final newSets = sets.map((set) => WorkoutSetsCompanion.insert(
      uuid: const Uuid().v4(),
      workoutId: newRoutineId,
      exerciseId: set.exerciseId,
      exerciseName: set.exerciseName,
      setOrder: set.setOrder,
      weight: Value(set.weight),
      reps: Value(set.reps),
      setType: Value(set.setType),
    )).toList();

    await _db.insertMultipleSets(newSets);
    return newRoutineId;
  }

  Future<int> startWorkoutFromRoutine(int routineId) async {
    final routine = await getRoutine(routineId);
    final sets = await _db.getSetsForWorkout(routineId);

    final workoutId = await _db.insertWorkout(
      WorkoutsCompanion.insert(
        uuid: const Uuid().v4(),
        title: routine.title,
        startTime: DateTime.now(),
        isTemplate: const Value(false),
        notes: Value(routine.notes),
      ),
    );

    final newSets = sets.map((set) => WorkoutSetsCompanion.insert(
      uuid: const Uuid().v4(),
      workoutId: workoutId,
      exerciseId: set.exerciseId,
      exerciseName: set.exerciseName,
      setOrder: set.setOrder,
      weight: Value(set.weight),
      reps: Value(set.reps),
      setType: Value(set.setType),
      isCompleted: const Value(false),
    )).toList();

    await _db.insertMultipleSets(newSets);
    return workoutId;
  }
}
