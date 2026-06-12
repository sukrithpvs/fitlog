// lib/features/routines/providers/routine_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/routine_repository.dart';

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  return RoutineRepository(ref.watch(databaseProvider));
});

final routineListProvider = StreamProvider<List<Workout>>((ref) {
  return ref.watch(routineRepositoryProvider).watchRoutines();
});

final routineSetsProvider = FutureProvider.family<List<WorkoutSet>, int>((ref, routineId) {
  return ref.watch(databaseProvider).getSetsForWorkout(routineId);
});
