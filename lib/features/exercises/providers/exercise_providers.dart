// lib/features/exercises/providers/exercise_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/exercise_repository.dart';

// Repository provider
final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository(ref.watch(databaseProvider));
});

// All exercises stream
final exerciseListProvider = StreamProvider<List<Exercise>>((ref) {
  return ref.watch(exerciseRepositoryProvider).watchAllExercises();
});

// Search query state - using NotifierProvider for Riverpod 3.x
final exerciseSearchQueryProvider = NotifierProvider<ExerciseSearchNotifier, String>(
  ExerciseSearchNotifier.new,
);

class ExerciseSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

// Selected muscle filter
final selectedMuscleFilterProvider = NotifierProvider<MuscleFilterNotifier, String?>(
  MuscleFilterNotifier.new,
);

class MuscleFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? muscle) => state = muscle;
  void clear() => state = null;
}

// Selected equipment filter
final selectedEquipmentFilterProvider = NotifierProvider<EquipmentFilterNotifier, String?>(
  EquipmentFilterNotifier.new,
);

class EquipmentFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? equipment) => state = equipment;
  void clear() => state = null;
}

// Filtered exercises
final filteredExercisesProvider = Provider<AsyncValue<List<Exercise>>>((ref) {
  final exercisesAsync = ref.watch(exerciseListProvider);
  final searchQuery = ref.watch(exerciseSearchQueryProvider).toLowerCase();
  final muscleFilter = ref.watch(selectedMuscleFilterProvider);
  final equipmentFilter = ref.watch(selectedEquipmentFilterProvider);

  return exercisesAsync.whenData((exercises) {
    var filtered = exercises;

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((e) => 
        e.name.toLowerCase().contains(searchQuery)
      ).toList();
    }

    if (muscleFilter != null) {
      filtered = filtered.where((e) => e.primaryMuscle == muscleFilter).toList();
    }

    if (equipmentFilter != null) {
      filtered = filtered.where((e) => e.equipment == equipmentFilter).toList();
    }

    return filtered;
  });
});
