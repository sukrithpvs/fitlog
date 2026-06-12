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
}

class RoutineFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
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

// ─── Database Class ───

@DriftDatabase(tables: [
  Exercises,
  Workouts,
  WorkoutSets,
  RoutineFolders,
  BodyMetrics,
  UserSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

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
      },
    );
  }

  // ─── Exercise Queries ───

  Future<List<Exercise>> getAllExercises() => select(exercises).get();

  Stream<List<Exercise>> watchAllExercises() => select(exercises).watch();

  Stream<List<Exercise>> watchExercisesByMuscle(String muscle) {
    return (select(exercises)..where((e) => e.primaryMuscle.equals(muscle))).watch();
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
    return (delete(exercises)..where((e) => e.id.equals(id))).go();
  }

  // ─── Workout Queries ───

  Future<List<Workout>> getAllWorkouts({bool templatesOnly = false}) {
    return (select(workouts)
          ..where((w) => w.isTemplate.equals(templatesOnly))
          ..orderBy([(w) => OrderingTerm.desc(w.startTime)]))
        .get();
  }

  Stream<List<Workout>> watchWorkoutHistory() {
    return (select(workouts)
          ..where((w) => w.isTemplate.equals(false))
          ..orderBy([(w) => OrderingTerm.desc(w.startTime)]))
        .watch();
  }

  Stream<List<Workout>> watchRoutines() {
    return (select(workouts)..where((w) => w.isTemplate.equals(true))).watch();
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
    return (delete(workouts)..where((w) => w.id.equals(id))).go();
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
    return (select(routineFolders)..orderBy([(f) => OrderingTerm.asc(f.sortOrder)])).watch();
  }

  Future<int> insertFolder(RoutineFoldersCompanion folder) {
    return into(routineFolders).insert(folder);
  }

  Future<int> deleteFolder(int id) {
    return (delete(routineFolders)..where((f) => f.id.equals(id))).go();
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
        // Delete in correct order to respect foreign key constraints
        // First delete sets (they reference workouts and exercises)
        await delete(workoutSets).go();
        
        // Then delete workouts (they reference routine folders)
        await delete(workouts).go();
        
        // Delete body metrics (independent table)
        await delete(bodyMetrics).go();
        
        // Delete routine folders (independent table)
        await delete(routineFolders).go();
        
        // Delete custom exercises only (preserve built-in 96 exercises)
        await (delete(exercises)..where((e) => e.isCustom.equals(true))).go();
      });
    } catch (e) {
      // Re-throw with more context
      throw Exception('Failed to clear data: $e');
    }
  }

  // ─── Backup: Export all data as maps ───

  Future<Map<String, dynamic>> exportAll() async {
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
        'weightUnit': (await getSettings()).weightUnit,
        'themeMode': (await getSettings()).themeMode,
        'defaultRestSeconds': (await getSettings()).defaultRestSeconds,
      },
    };
  }
}
