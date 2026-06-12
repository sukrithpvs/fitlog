// lib/features/settings/utils/data_import.dart
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';

class DataImporter {
  DataImporter._();

  /// Import workout history from CSV
  static Future<ImportResult> importCSV(AppDatabase db) async {
    try {
      // Pick CSV file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(success: false, message: 'No file selected');
      }

      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      final lines = content.split('\n');

      if (lines.isEmpty || !lines.first.contains('Date,Workout,Exercise')) {
        return ImportResult(
          success: false,
          message: 'Invalid CSV format. Please use exported format.',
        );
      }

      int workoutsImported = 0;
      int setsImported = 0;
      final uuid = const Uuid();

      // Parse CSV (skip header)
      final workoutMap = <String, int>{}; // date+title -> workoutId
      final exerciseMap = <String, int>{}; // exercise name -> exerciseId

      // Pre-load exercises
      final exercises = await db.getAllExercises();
      for (final ex in exercises) {
        exerciseMap[ex.name] = ex.id;
      }

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = _parseCSVLine(line);
        if (parts.length < 8) continue;

        final dateStr = parts[0];
        final workoutTitle = parts[1];
        final exerciseName = parts[2];
        // parts[3] is set number (ignored, will auto-increment)
        final weightStr = parts[4];
        final repsStr = parts[5];
        final setType = parts[6];
        final completedStr = parts[7];

        // Get or create workout
        final workoutKey = '$dateStr-$workoutTitle';
        int workoutId;
        
        if (!workoutMap.containsKey(workoutKey)) {
          final startTime = DateTime.tryParse(dateStr) ?? DateTime.now();
          workoutId = await db.insertWorkout(
            WorkoutsCompanion.insert(
              uuid: uuid.v4(),
              title: workoutTitle,
              startTime: startTime,
              endTime: Value(startTime.add(const Duration(hours: 1))),
              isTemplate: const Value(false),
            ),
          );
          workoutMap[workoutKey] = workoutId;
          workoutsImported++;
        } else {
          workoutId = workoutMap[workoutKey]!;
        }

        // Get exercise ID
        final exerciseId = exerciseMap[exerciseName];
        if (exerciseId == null) continue; // Skip if exercise doesn't exist

        // Parse set data
        final weight = weightStr.isEmpty ? null : double.tryParse(weightStr);
        final reps = repsStr.isEmpty ? null : int.tryParse(repsStr);
        final isCompleted = completedStr.toLowerCase() == 'true';

        // Insert set
        await db.insertWorkoutSet(
          WorkoutSetsCompanion.insert(
            uuid: uuid.v4(),
            workoutId: workoutId,
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            setOrder: setsImported,
            weight: Value(weight),
            reps: Value(reps),
            setType: Value(setType),
            isCompleted: Value(isCompleted),
            completedAt: Value(isCompleted ? DateTime.parse(dateStr) : null),
          ),
        );
        setsImported++;
      }

      return ImportResult(
        success: true,
        message: 'Imported $workoutsImported workouts, $setsImported sets',
        workoutsCount: workoutsImported,
        setsCount: setsImported,
      );
    } catch (e) {
      return ImportResult(success: false, message: 'Import failed: $e');
    }
  }

  /// Import full backup from JSON
  static Future<ImportResult> importJSON(AppDatabase db) async {
    try {
      // Pick JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(success: false, message: 'No file selected');
      }

      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      if (!data.containsKey('version') || !data.containsKey('exercises')) {
        return ImportResult(
          success: false,
          message: 'Invalid backup format',
        );
      }

      int exercisesImported = 0;
      int workoutsImported = 0;
      int setsImported = 0;
      final uuid = const Uuid();

      // Import exercises
      if (data['exercises'] is List) {
        final exercises = data['exercises'] as List;
        for (final exData in exercises) {
          if (exData is! Map) continue;
          
          // Check if custom exercise
          if (exData['isCustom'] == true) {
            // Check if already exists
            final existing = await (db.select(db.exercises)
                  ..where((e) => e.name.equals(exData['name'])))
                .getSingleOrNull();
            
            if (existing == null) {
              await db.insertExercise(
                ExercisesCompanion.insert(
                  uuid: uuid.v4(),
                  name: exData['name'],
                  primaryMuscle: exData['primaryMuscle'],
                  secondaryMuscles: Value(exData['secondaryMuscles'] ?? ''),
                  equipment: exData['equipment'],
                  trackingType: Value(exData['trackingType'] ?? 'weight_reps'),
                  isCustom: const Value(true),
                  notes: Value(exData['notes']),
                ),
              );
              exercisesImported++;
            }
          }
        }
      }

      // Import workouts
      if (data['workouts'] is List) {
        final workouts = data['workouts'] as List;
        final workoutIdMap = <int, int>{}; // old ID -> new ID
        final workoutUuidMap = <String, int>{}; // fallback old UUID -> new ID

        for (final wData in workouts) {
          if (wData is! Map) continue;
          
          final workoutId = await db.insertWorkout(
            WorkoutsCompanion.insert(
              uuid: uuid.v4(),
              title: wData['title'],
              startTime: DateTime.parse(wData['startTime']),
              endTime: Value(wData['endTime'] != null ? DateTime.parse(wData['endTime']) : null),
              isTemplate: Value(wData['isTemplate'] ?? false),
              notes: Value(wData['notes']),
            ),
          );
          if (wData['id'] != null) {
            workoutIdMap[wData['id']] = workoutId;
          }
          if (wData['uuid'] != null) {
            workoutUuidMap[wData['uuid']] = workoutId;
          }
          workoutsImported++;
        }

        // Import sets
        if (data['sets'] is List) {
          final sets = data['sets'] as List;
          final allExercises = await db.getAllExercises();
          final exerciseMap = <String, int>{};
          for (final ex in allExercises) {
            exerciseMap[ex.name] = ex.id;
          }

          for (final sData in sets) {
            if (sData is! Map) continue;
            
            // Find workout ID
            int? workoutId;
            if (sData['workoutId'] != null && workoutIdMap.containsKey(sData['workoutId'])) {
              workoutId = workoutIdMap[sData['workoutId']];
            } else {
              // Fallback for old backups without 'id'
              for (final oldWorkout in (data['workouts'] as List)) {
                if (oldWorkout is Map && workoutUuidMap.containsKey(oldWorkout['uuid'])) {
                  // This fallback is flawed but kept for backwards compatibility
                  workoutId = workoutUuidMap[oldWorkout['uuid']];
                  break;
                }
              }
            }

            if (workoutId == null) continue;

            final exerciseId = exerciseMap[sData['exerciseName']];
            if (exerciseId == null) continue;

            await db.insertWorkoutSet(
              WorkoutSetsCompanion.insert(
                uuid: uuid.v4(),
                workoutId: workoutId,
                exerciseId: exerciseId,
                exerciseName: sData['exerciseName'],
                setOrder: sData['setOrder'],
                weight: Value(sData['weight']),
                reps: Value(sData['reps']),
                durationSeconds: Value(sData['durationSeconds']),
                distanceMeters: Value(sData['distanceMeters']),
                setType: Value(sData['setType'] ?? 'normal'),
                rpe: Value(sData['rpe']),
                supersetId: Value(sData['supersetId']),
                isCompleted: Value(sData['isCompleted'] ?? false),
                completedAt: Value(sData['completedAt'] != null ? DateTime.parse(sData['completedAt']) : null),
              ),
            );
            setsImported++;
          }
        }
      }

      return ImportResult(
        success: true,
        message: 'Imported $exercisesImported exercises, $workoutsImported workouts, $setsImported sets',
        exercisesCount: exercisesImported,
        workoutsCount: workoutsImported,
        setsCount: setsImported,
      );
    } catch (e) {
      return ImportResult(success: false, message: 'Import failed: $e');
    }
  }

  /// Parse CSV line handling quoted values
  static List<String> _parseCSVLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    final buffer = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    
    result.add(buffer.toString().trim());
    return result;
  }
}

class ImportResult {
  final bool success;
  final String message;
  final int? exercisesCount;
  final int? workoutsCount;
  final int? setsCount;

  ImportResult({
    required this.success,
    required this.message,
    this.exercisesCount,
    this.workoutsCount,
    this.setsCount,
  });
}
