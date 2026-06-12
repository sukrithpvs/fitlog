// lib/features/exercises/providers/exercise_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
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

// History grouped by workout for a specific exercise
class WorkoutHistoryGroup {
  final Workout workout;
  final List<WorkoutSet> sets;
  WorkoutHistoryGroup({required this.workout, required this.sets});
}

final exerciseHistoryGroupedProvider = StreamProvider.family<List<WorkoutHistoryGroup>, int>((ref, exerciseId) {
  final db = ref.watch(databaseProvider);
  
  return (db.select(db.workoutSets)
        ..where((s) => s.exerciseId.equals(exerciseId) & s.isCompleted.equals(true))
        ..orderBy([(s) => OrderingTerm.desc(s.completedAt)]))
      .watch()
      .asyncMap((sets) async {
    final Map<int, List<WorkoutSet>> groupedSets = {};
    for (final set in sets) {
      if (!groupedSets.containsKey(set.workoutId)) {
        groupedSets[set.workoutId] = [];
      }
      groupedSets[set.workoutId]!.add(set);
    }
    
    // Reverse the sets inside each workout so they appear in Set 1, Set 2 order
    for (final key in groupedSets.keys) {
      groupedSets[key]!.sort((a, b) => a.setOrder.compareTo(b.setOrder));
    }

    final List<WorkoutHistoryGroup> history = [];
    
    for (final entry in groupedSets.entries) {
      final workoutId = entry.key;
      final workoutSets = entry.value;
      
      try {
        final workout = await (db.select(db.workouts)
              ..where((w) => w.id.equals(workoutId)))
            .getSingle();
        
        history.add(WorkoutHistoryGroup(workout: workout, sets: workoutSets));
      } catch (_) {
        // Skip if workout not found
      }
    }
    
    // Sort descending by workout start time
    history.sort((a, b) => b.workout.startTime.compareTo(a.workout.startTime));
    
    return history;
  });
});
