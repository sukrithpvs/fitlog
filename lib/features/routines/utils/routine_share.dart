// lib/features/routines/utils/routine_share.dart
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';

class RoutineSharer {
  RoutineSharer._();

  /// Export a routine as JSON for sharing
  static Future<void> shareRoutine(
    AppDatabase db,
    Workout routine,
  ) async {
    try {
      // Get routine sets
      final sets = await db.getSetsForWorkout(routine.id);
      
      // Group by exercise
      final exercises = <Map<String, dynamic>>[];
      final exerciseMap = <String, List<WorkoutSet>>{};
      
      for (final set in sets) {
        exerciseMap.putIfAbsent(set.exerciseName, () => []).add(set);
      }
      
      for (final entry in exerciseMap.entries) {
        exercises.add({
          'name': entry.key,
          'sets': entry.value.length,
          'exerciseId': entry.value.first.exerciseId,
        });
      }
      
      // Create shareable JSON
      final routineData = {
        'version': 1,
        'type': 'routine',
        'name': routine.title,
        'notes': routine.notes,
        'exercises': exercises,
        'createdAt': DateTime.now().toIso8601String(),
        'appName': 'FitLog',
      };
      
      final json = JsonEncoder.withIndent('  ').convert(routineData);
      
      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = '${routine.title.replaceAll(' ', '_')}_$timestamp.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(json);
      
      // Share
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Check out my "${routine.title}" workout routine!',
      );
    } catch (e) {
      throw Exception('Failed to share routine: $e');
    }
  }

  /// Import a routine from JSON
  static Future<ImportResult> importRoutine(
    AppDatabase db,
    String jsonContent,
  ) async {
    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      
      // Validate format
      if (data['type'] != 'routine' || data['exercises'] == null) {
        return ImportResult(
          success: false,
          message: 'Invalid routine format',
        );
      }
      
      final routineName = data['name'] as String;
      final notes = data['notes'] as String?;
      final exercises = data['exercises'] as List;
      
      // Get available exercises
      final allExercises = await db.getAllExercises();
      final exerciseMap = <String, int>{};
      for (final ex in allExercises) {
        exerciseMap[ex.name] = ex.id;
      }
      
      // Create routine
      final uuid = const Uuid();
      final workoutId = await db.insertWorkout(
        WorkoutsCompanion.insert(
          uuid: uuid.v4(),
          title: routineName,
          startTime: DateTime.now(),
          isTemplate: const Value(true),
          notes: Value(notes),
        ),
      );
      
      // Add exercises
      int setOrder = 0;
      int exercisesAdded = 0;
      
      for (final exData in exercises) {
        if (exData is! Map) continue;
        
        final exName = exData['name'] as String;
        final setsCount = exData['sets'] as int? ?? 3;
        
        // Find exercise ID
        final exerciseId = exerciseMap[exName];
        if (exerciseId == null) continue; // Skip if exercise doesn't exist
        
        // Add sets for this exercise
        for (int i = 0; i < setsCount; i++) {
          await db.insertWorkoutSet(
            WorkoutSetsCompanion.insert(
              uuid: uuid.v4(),
              workoutId: workoutId,
              exerciseId: exerciseId,
              exerciseName: exName,
              setOrder: setOrder++,
            ),
          );
        }
        exercisesAdded++;
      }
      
      return ImportResult(
        success: true,
        message: 'Imported routine "$routineName" with $exercisesAdded exercises',
        routineName: routineName,
        exercisesCount: exercisesAdded,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Failed to import routine: $e',
      );
    }
  }
}

class ImportResult {
  final bool success;
  final String message;
  final String? routineName;
  final int? exercisesCount;

  ImportResult({
    required this.success,
    required this.message,
    this.routineName,
    this.exercisesCount,
  });
}
