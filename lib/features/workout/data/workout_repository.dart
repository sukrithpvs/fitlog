// lib/features/workout/data/workout_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(ref.read(databaseProvider));
});

class WorkoutRepository {
  final AppDatabase _db;

  WorkoutRepository(this._db);

  Future<int> createQuickWorkout() async {
    return await _db.insertWorkout(
      WorkoutsCompanion.insert(
        uuid: const Uuid().v4(),
        title: 'Quick Workout',
        startTime: DateTime.now(),
      ),
    );
  }

  Future<void> addSetToWorkout(int workoutId, WorkoutSet templateSet, {bool isDropSet = false}) async {
    final sets = await _db.getSetsForWorkout(workoutId);
    final exerciseSets = sets.where((s) => s.exerciseName == templateSet.exerciseName).toList();
    final maxOrder = exerciseSets.isEmpty ? -1 : exerciseSets.map((s) => s.setOrder).reduce((a, b) => a > b ? a : b);

    await _db.insertWorkoutSet(
      WorkoutSetsCompanion.insert(
        uuid: const Uuid().v4(),
        workoutId: workoutId,
        exerciseId: templateSet.exerciseId,
        exerciseName: templateSet.exerciseName,
        setOrder: maxOrder + 1,
        weight: Value(templateSet.weight),
        reps: Value(templateSet.reps),
        setType: Value(isDropSet ? 'drop' : 'normal'),
        supersetId: Value(templateSet.supersetId),
        exerciseSequenceIndex: Value(templateSet.exerciseSequenceIndex),
      ),
    );
  }

  Future<void> updateSet(int setId, {double? weight, int? reps, int? durationSeconds, double? distanceMeters}) async {
    final currentSet = await (_db.select(_db.workoutSets)..where((s) => s.id.equals(setId))).getSingleOrNull();
    
    if (currentSet != null) {
      await _db.update(_db.workoutSets).replace(
        currentSet.copyWith(
          weight: weight != null ? Value(weight) : (currentSet.weight != null ? Value(currentSet.weight) : const Value.absent()),
          reps: reps != null ? Value(reps) : (currentSet.reps != null ? Value(currentSet.reps) : const Value.absent()),
          durationSeconds: durationSeconds != null ? Value(durationSeconds) : (currentSet.durationSeconds != null ? Value(currentSet.durationSeconds) : const Value.absent()),
          distanceMeters: distanceMeters != null ? Value(distanceMeters) : (currentSet.distanceMeters != null ? Value(currentSet.distanceMeters) : const Value.absent()),
        ),
      );
    }
  }

  Future<void> deleteSets(List<WorkoutSet> sets) async {
    for (final set in sets) {
      await _db.deleteWorkoutSet(set.id);
    }
  }

  Future<void> finishWorkout(int workoutId, String notes, int intensityRating) async {
    await (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId))).write(
      WorkoutsCompanion(
        endTime: Value(DateTime.now()),
        notes: Value(notes.isEmpty ? null : notes),
        intensityRating: Value(intensityRating),
      ),
    );
  }
}
