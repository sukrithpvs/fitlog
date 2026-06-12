// lib/main.dart
// FitLog entry point — initializes database, seeds data, launches app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/database_provider.dart';
import 'core/database/seed_data.dart';
import 'core/database/seed_routines.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the database and seed default exercises and routines
  final db = getDatabase();
  await seedDefaultExercises(db);
  await seedDefaultRoutines(db);

  runApp(
    const ProviderScope(
      child: FitLogApp(),
    ),
  );
}
