// lib/features/exercises/presentation/exercises_tab_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/equipment_types.dart';
import '../../../core/constants/muscle_groups.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/exercise_providers.dart';
import 'exercise_detail_screen.dart';
import 'widgets/exercise_card.dart';
import 'widgets/create_exercise_sheet.dart';

class ExercisesTabScreen extends ConsumerStatefulWidget {
  const ExercisesTabScreen({super.key});

  @override
  ConsumerState<ExercisesTabScreen> createState() => _ExercisesTabScreenState();
}

class _ExercisesTabScreenState extends ConsumerState<ExercisesTabScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredExercises = ref.watch(filteredExercisesProvider);
    final selectedMuscle = ref.watch(selectedMuscleFilterProvider);
    final selectedEquipment = ref.watch(selectedEquipmentFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateExercise(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(exerciseSearchQueryProvider.notifier).clear();
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(exerciseSearchQueryProvider.notifier).setQuery(value);
              },
            ),
          ),

          // Filter Chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Muscle filter
                ...MuscleGroup.values.map((muscle) {
                  final isSelected = selectedMuscle == muscle.name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(muscle.displayName.split(' ')[0]),
                      selected: isSelected,
                      onSelected: (selected) {
                        ref.read(selectedMuscleFilterProvider.notifier).setFilter(
                            selected ? muscle.name : null);
                      },
                      selectedColor: AppColors.accent.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.accent,
                    ),
                  );
                }),

                // Equipment filter
                ...EquipmentType.values.map((equipment) {
                  final isSelected = selectedEquipment == equipment.name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(equipment.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        ref.read(selectedEquipmentFilterProvider.notifier).setFilter(
                            selected ? equipment.name : null);
                      },
                      selectedColor: AppColors.accent.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.accent,
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Exercise List
          Expanded(
            child: filteredExercises.when(
              data: (exercises) {
                if (exercises.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fitness_center_outlined,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No exercises found',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    return ExerciseCard(
                      exercise: exercise,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExerciseDetailScreen(exercise: exercise),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('Error: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateExercise(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreateExerciseSheet(),
    );
  }
}
