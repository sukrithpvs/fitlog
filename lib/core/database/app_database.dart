// lib/core/database/app_database.dart
// Drift database definition — the single source of truth for all local data.
// Using Drift (typed SQLite) instead of Isar for guaranteed Dart 3.12 compatibility.

import 'package:drift/drift.dart';

part 'app_database.g.dart';

// ─── Table Definitions ───

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  TextColumn get primaryMuscle => text()();
  TextColumn get secondaryMuscles => text().withDefault(const Constant(''))(); // comma-separated
  TextColumn get equipment => text()();
  TextColumn get trackingType => text().withDefault(const Constant('weight_reps'))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get title => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  BoolColumn get isTemplate => boolean().withDefault(const Constant(false))();
  IntColumn get folderId => integer().nullable().references(RoutineFolders, #id)();
  TextColumn get notes => text().nullable()();
  IntColumn get intensityRating => integer().nullable()(); // 1-5 stars
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  IntColumn get workoutId => integer().references(Workouts, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  TextColumn get exerciseName => text()(); // denormalized for display speed
  IntColumn get setOrder => integer()();
  RealColumn get weight => real().nullable()();
  IntColumn get reps => integer().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get distanceMeters => real().nullable()();
  TextColumn get setType => text().withDefault(const Constant('normal'))();
  IntColumn get rpe => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get supersetId => text().nullable()();
  BoolColumn get isPersonalRecord => boolean().withDefault(const Constant(false))();
  IntColumn get exerciseSequenceIndex => integer().nullable()();
}

class RoutineFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class BodyMetrics extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get recordedAt => dateTime()();
  RealColumn get weightKg => real().nullable()();
  RealColumn get bodyFatPercent => real().nullable()();
  TextColumn get notes => text().nullable()();
}

class UserSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get weightUnit => text().withDefault(const Constant('kg'))();
  TextColumn get themeMode => text().withDefault(const Constant('dark'))();
  IntColumn get defaultRestSeconds => integer().withDefault(const Constant(90))();
  DateTimeColumn get lastBackupAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class WeeklyTargets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get muscleGroup => text()();
  IntColumn get targetSets => integer()();
}

class ScheduledWorkouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  IntColumn get routineId => integer().references(Workouts, #id)();
  DateTimeColumn get scheduledDate => dateTime()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
}

class UserBadges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get badgeType => text()();
  DateTimeColumn get earnedAt => dateTime().withDefault(currentDateAndTime)();
}

class WorkoutExerciseNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().references(Workouts, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  TextColumn get notes => text()();
}

// ─── Database Class ───

@DriftDatabase(tables: [
  Exercises,
  Workouts,
  WorkoutSets,
  RoutineFolders,
  BodyMetrics,
  UserSettings,
  WeeklyTargets,
  ScheduledWorkouts,
  UserBadges,
  WorkoutExerciseNotes,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Insert default user settings row
        await into(userSettings).insert(
          UserSettingsCompanion.insert(),
        );
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add intensity rating to workouts
          await m.addColumn(workouts, workouts.intensityRating);
        }
        if (from < 3) {
          await m.addColumn(workoutSets, workoutSets.supersetId);
        }
        if (from < 4) {
          await m.addColumn(workoutSets, workoutSets.isPersonalRecord);
        }
        if (from < 5) {
          await m.addColumn(exercises, exercises.isDeleted);
          await m.addColumn(workouts, workouts.isDeleted);
          await m.addColumn(routineFolders, routineFolders.isDeleted);
          await m.addColumn(workoutSets, workoutSets.exerciseSequenceIndex);
        }
        if (from < 6) {
          await m.createTable(weeklyTargets);
          await m.createTable(scheduledWorkouts);
          await m.createTable(userBadges);
        }
        if (from < 7) {
          await m.createTable(workoutExerciseNotes);
        }
      },
    );
  }

  // ─── Exercise Queries ───

  Future<List<Exercise>> getAllExercises() => (select(exercises)..where((e) => e.isDeleted.equals(false))).get();

  Stream<List<Exercise>> watchAllExercises() => (select(exercises)..where((e) => e.isDeleted.equals(false))).watch();

  Stream<List<Exercise>> watchExercisesByMuscle(String muscle) {
    return (select(exercises)..where((e) => e.primaryMuscle.equals(muscle) & e.isDeleted.equals(false))).watch();
  }

  Future<Exercise> getExerciseById(int id) {
    return (select(exercises)..where((e) => e.id.equals(id))).getSingle();
  }

  Future<int> insertExercise(ExercisesCompanion exercise) {
    return into(exercises).insert(exercise);
  }

  Future<bool> updateExercise(ExercisesCompanion exercise) {
    return update(exercises).replace(exercise);
  }

  Future<int> deleteExercise(int id) {
    return (update(exercises)..where((e) => e.id.equals(id))).write(const ExercisesCompanion(isDeleted: Value(true)));
  }

  // ─── Workout Queries ───

  Future<List<Workout>> getAllWorkouts({bool templatesOnly = false}) {
    return (select(workouts)
          ..where((w) => w.isTemplate.equals(templatesOnly) & w.isDeleted.equals(false))
          ..orderBy([(w) => OrderingTerm.desc(w.startTime)]))
        .get();
  }

  Stream<List<Workout>> watchWorkoutHistory() {
    return (select(workouts)
          ..where((w) => w.isTemplate.equals(false) & w.isDeleted.equals(false))
          ..orderBy([(w) => OrderingTerm.desc(w.startTime)]))
        .watch();
  }

  Stream<List<Workout>> watchRoutines() {
    return (select(workouts)..where((w) => w.isTemplate.equals(true) & w.isDeleted.equals(false))).watch();
  }

  Future<int> insertWorkout(WorkoutsCompanion workout) {
    return into(workouts).insert(workout);
  }

  Future<Workout> getWorkoutById(int id) {
    return (select(workouts)..where((w) => w.id.equals(id))).getSingle();
  }

  Future<bool> updateWorkout(WorkoutsCompanion workout) {
    return update(workouts).replace(workout);
  }

  Future<int> deleteWorkout(int id) {
    return (update(workouts)..where((w) => w.id.equals(id))).write(const WorkoutsCompanion(isDeleted: Value(true)));
  }

  // ─── WorkoutSet Queries ───

  Future<List<WorkoutSet>> getSetsForWorkout(int workoutId) {
    return (select(workoutSets)
          ..where((s) => s.workoutId.equals(workoutId))
          ..orderBy([(s) => OrderingTerm.asc(s.setOrder)]))
        .get();
  }

  Stream<List<WorkoutSet>> watchSetsForWorkout(int workoutId) {
    return (select(workoutSets)
          ..where((s) => s.workoutId.equals(workoutId))
          ..orderBy([(s) => OrderingTerm.asc(s.setOrder)]))
        .watch();
  }

  Future<List<WorkoutSet>> getSetsForExercise(int exerciseId) {
    return (select(workoutSets)
          ..where((s) => s.exerciseId.equals(exerciseId))
          ..orderBy([(s) => OrderingTerm.desc(s.completedAt)]))
        .get();
  }

  Future<WorkoutSet?> getPreviousSetPerformance(int exerciseId, int setIndex) async {
    // 1. Find the most recent workout where this exercise was performed
    final recentWorkoutSet = await (select(workoutSets)
          ..where((s) => s.exerciseId.equals(exerciseId) & s.isCompleted.equals(true))
          ..orderBy([(s) => OrderingTerm.desc(s.completedAt)])
          ..limit(1))
        .getSingleOrNull();
        
    if (recentWorkoutSet == null) return null;
    
    // 2. Get all sets for that exercise in that workout, ordered by setOrder
    final sets = await (select(workoutSets)
          ..where((s) => s.workoutId.equals(recentWorkoutSet.workoutId) & 
                         s.exerciseId.equals(exerciseId) & 
                         s.isCompleted.equals(true))
          ..orderBy([(s) => OrderingTerm.asc(s.setOrder)]))
        .get();
        
    if (setIndex < sets.length) {
      return sets[setIndex];
    }
    return null;
  }

  Future<int> insertWorkoutSet(WorkoutSetsCompanion set_) {
    return into(workoutSets).insert(set_);
  }

  Future<void> insertMultipleSets(List<WorkoutSetsCompanion> sets) async {
    await batch((b) {
      b.insertAll(workoutSets, sets);
    });
  }

  Future<int> deleteWorkoutSet(int id) {
    return (delete(workoutSets)..where((s) => s.id.equals(id))).go();
  }

  Future<void> deleteSetsForWorkout(int workoutId) {
    return (delete(workoutSets)..where((s) => s.workoutId.equals(workoutId))).go();
  }

  // ─── RoutineFolder Queries ───

  Stream<List<RoutineFolder>> watchAllFolders() {
    return (select(routineFolders)
          ..where((f) => f.isDeleted.equals(false))
          ..orderBy([(f) => OrderingTerm.asc(f.sortOrder)]))
        .watch();
  }

  Future<int> insertFolder(RoutineFoldersCompanion folder) {
    return into(routineFolders).insert(folder);
  }

  Future<int> deleteFolder(int id) {
    return (update(routineFolders)..where((f) => f.id.equals(id))).write(const RoutineFoldersCompanion(isDeleted: Value(true)));
  }

  // ─── BodyMetric Queries ───

  Stream<List<BodyMetric>> watchBodyMetrics() {
    return (select(bodyMetrics)..orderBy([(b) => OrderingTerm.desc(b.recordedAt)])).watch();
  }

  Future<int> insertBodyMetric(BodyMetricsCompanion metric) {
    return into(bodyMetrics).insert(metric);
  }

  // ─── UserSettings Queries ───

  Future<UserSetting> getSettings() {
    return (select(userSettings)..where((s) => s.id.equals(1))).getSingle();
  }

  Stream<UserSetting> watchSettings() {
    return (select(userSettings)..where((s) => s.id.equals(1))).watchSingle();
  }

  Future<void> updateSettings(UserSettingsCompanion settings) {
    return (update(userSettings)..where((s) => s.id.equals(1))).write(settings);
  }

  // ─── Clear All Data ───

  Future<void> clearAllData() async {
    try {
      await transaction(() async {
        // WorkoutSets does not have a soft-delete flag, so we hard delete.
        await delete(workoutSets).go();
        
        // Soft delete workouts and folders
        await update(workouts).write(const WorkoutsCompanion(isDeleted: Value(true)));
        await update(routineFolders).write(const RoutineFoldersCompanion(isDeleted: Value(true)));
        
        // Delete body metrics (independent table)
        await delete(bodyMetrics).go();
        
        // Soft delete custom exercises only (preserve built-in)
        await (update(exercises)..where((e) => e.isCustom.equals(true))).write(const ExercisesCompanion(isDeleted: Value(true)));
      });
    } catch (e) {
      // Re-throw with more context
      throw Exception('Failed to clear data: $e');
    }
  }

  // ─── Backup: Export all data as maps ───

  Future<Map<String, dynamic>> exportAll() async {
    final s = await getSettings();
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'exercises': (await select(exercises).get()).map((e) => {
            'uuid': e.uuid,
            'name': e.name,
            'primaryMuscle': e.primaryMuscle,
            'secondaryMuscles': e.secondaryMuscles,
            'equipment': e.equipment,
            'trackingType': e.trackingType,
            'isCustom': e.isCustom,
            'notes': e.notes,
            'createdAt': e.createdAt.toIso8601String(),
          }).toList(),
      'workouts': (await select(workouts).get()).map((w) => {
            'id': w.id,
            'uuid': w.uuid,
            'title': w.title,
            'startTime': w.startTime.toIso8601String(),
            'endTime': w.endTime?.toIso8601String(),
            'isTemplate': w.isTemplate,
            'folderId': w.folderId,
            'notes': w.notes,
          }).toList(),
      'sets': (await select(workoutSets).get()).map((s) => {
            'uuid': s.uuid,
            'workoutId': s.workoutId,
            'exerciseId': s.exerciseId,
            'exerciseName': s.exerciseName,
            'setOrder': s.setOrder,
            'weight': s.weight,
            'reps': s.reps,
            'durationSeconds': s.durationSeconds,
            'distanceMeters': s.distanceMeters,
            'setType': s.setType,
            'rpe': s.rpe,
            'supersetId': s.supersetId,
            'isCompleted': s.isCompleted,
            'completedAt': s.completedAt?.toIso8601String(),
          }).toList(),
      'folders': (await select(routineFolders).get()).map((f) => {
            'uuid': f.uuid,
            'name': f.name,
            'sortOrder': f.sortOrder,
          }).toList(),
      'bodyMetrics': (await select(bodyMetrics).get()).map((b) => {
            'recordedAt': b.recordedAt.toIso8601String(),
            'weightKg': b.weightKg,
            'bodyFatPercent': b.bodyFatPercent,
            'notes': b.notes,
          }).toList(),
      'settings': {
        'weightUnit': s.weightUnit,
        'themeMode': s.themeMode,
        'defaultRestSeconds': s.defaultRestSeconds,
      },
    };
  }

  // ─── Workout Exercise Notes ───

  Future<String?> getExerciseNoteForWorkout(int workoutId, int exerciseId) async {
    final noteRow = await (select(workoutExerciseNotes)
          ..where((n) => n.workoutId.equals(workoutId) & n.exerciseId.equals(exerciseId)))
        .getSingleOrNull();
    return noteRow?.notes;
  }

  Future<void> saveExerciseNoteForWorkout(int workoutId, int exerciseId, String notes) async {
    final existing = await (select(workoutExerciseNotes)
          ..where((n) => n.workoutId.equals(workoutId) & n.exerciseId.equals(exerciseId)))
        .getSingleOrNull();

    if (existing != null) {
      if (notes.trim().isEmpty) {
        await (delete(workoutExerciseNotes)..where((n) => n.id.equals(existing.id))).go();
      } else {
        await (update(workoutExerciseNotes)..where((n) => n.id.equals(existing.id)))
            .write(WorkoutExerciseNotesCompanion(notes: Value(notes)));
      }
    } else if (notes.trim().isNotEmpty) {
      await into(workoutExerciseNotes).insert(
        WorkoutExerciseNotesCompanion.insert(
          workoutId: workoutId,
          exerciseId: exerciseId,
          notes: notes,
        ),
      );
    }
  }
}
