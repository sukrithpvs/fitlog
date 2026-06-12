// lib/features/exercises/data/exercise_repository.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';

class ExerciseRepository {
  final AppDatabase _db;
  const ExerciseRepository(this._db);

  Stream<List<Exercise>> watchAllExercises() => _db.watchAllExercises();

  Stream<List<Exercise>> watchExercisesByMuscle(String muscle) {
    return _db.watchExercisesByMuscle(muscle);
  }

  Future<Exercise> getExerciseById(int id) => _db.getExerciseById(id);

  Future<int> createExercise({
    required String name,
    required String primaryMuscle,
    String secondaryMuscles = '',
    required String equipment,
    String trackingType = 'weight_reps',
    String? notes,
  }) {
    return _db.insertExercise(
      ExercisesCompanion.insert(
        uuid: const Uuid().v4(),
        name: name,
        primaryMuscle: primaryMuscle,
        secondaryMuscles: Value(secondaryMuscles),
        equipment: equipment,
        trackingType: Value(trackingType),
        isCustom: const Value(true),
        notes: Value(notes),
      ),
    );
  }

  Future<void> updateExercise(Exercise exercise) {
    return _db.updateExercise(
      ExercisesCompanion(
        id: Value(exercise.id),
        uuid: Value(exercise.uuid),
        name: Value(exercise.name),
        primaryMuscle: Value(exercise.primaryMuscle),
        secondaryMuscles: Value(exercise.secondaryMuscles),
        equipment: Value(exercise.equipment),
        trackingType: Value(exercise.trackingType),
        isCustom: Value(exercise.isCustom),
        notes: Value(exercise.notes),
      ),
    );
  }

  Future<void> deleteExercise(int id) => _db.deleteExercise(id);

  Future<List<WorkoutSet>> getExerciseHistory(int exerciseId) {
    return _db.getSetsForExercise(exerciseId);
  }
}
