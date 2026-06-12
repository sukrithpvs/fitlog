// lib/core/database/database_provider.dart
// Initializes the Drift database with native SQLite on Android.

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

// Singleton database instance — created once, lives forever
AppDatabase? _dbInstance;

AppDatabase getDatabase() {
  _dbInstance ??= AppDatabase(
    driftDatabase(name: 'fitlog'),
  );
  return _dbInstance!;
}

// Riverpod provider so any widget/provider can access the database
final databaseProvider = Provider<AppDatabase>((ref) {
  return getDatabase();
});
