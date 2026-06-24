// lib/main.dart
// FitLog entry point — initializes database, seeds data, launches app.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database/database_provider.dart';
import 'core/database/seed_data.dart';
import 'core/database/seed_routines.dart';
import 'core/utils/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Global Error: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async Global Error: $error');
    return true;
  };

  // Initialize the database
  final db = getDatabase();
  
  // Seed default exercises and routines only on first launch
  final prefs = await SharedPreferences.getInstance();
  final isSeeded = prefs.getBool('isDataSeeded') ?? false;
  if (!isSeeded) {
    await seedDefaultExercises(db);
    await seedDefaultRoutines(db);
    await prefs.setBool('isDataSeeded', true);
  }

  final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  runApp(
    ProviderScope(
      child: FitLogApp(hasSeenOnboarding: hasSeenOnboarding),
    ),
  );
}
