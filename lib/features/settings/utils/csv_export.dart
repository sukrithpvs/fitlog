// lib/features/settings/utils/csv_export.dart
import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/app_database.dart';

class CsvExporter {
  static Future<void> exportWorkoutHistory(AppDatabase db) async {
    final workouts = await (db.select(db.workouts)
          ..where((w) => w.isTemplate.equals(false))
          ..orderBy([(w) => OrderingTerm.desc(w.startTime)]))
        .get();

    if (workouts.isEmpty) {
      throw Exception('No workouts to export');
    }

    final csv = StringBuffer();
    csv.writeln('Date,Workout,Exercise,Set,Weight(kg),Reps,Set Type,Completed');

    for (final workout in workouts) {
      final sets = await db.getSetsForWorkout(workout.id);
      for (final set in sets) {
        csv.writeln(
          '${workout.startTime.toIso8601String()},'
          '"${workout.title}",'
          '"${set.exerciseName}",'
          '${set.setOrder + 1},'
          '${set.weight ?? ""},'
          '${set.reps ?? ""},'
          '${set.setType},'
          '${set.isCompleted}',
        );
      }
    }

    // Save to temporary file and share
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final file = File('${directory.path}/fitlog_workouts_$timestamp.csv');
    await file.writeAsString(csv.toString());
    
    await Share.shareXFiles([XFile(file.path)], text: 'FitLog Workout History');
  }

  static Future<void> exportFullBackup(AppDatabase db) async {
    final data = await db.exportAll();
    final json = JsonEncoder.withIndent('  ').convert(data);
    
    // Save to temporary file and share
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final file = File('${directory.path}/fitlog_backup_$timestamp.json');
    await file.writeAsString(json);
    
    await Share.shareXFiles([XFile(file.path)], text: 'FitLog Full Backup');
  }
}
