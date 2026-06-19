// lib/features/exercises/presentation/widgets/exercise_picker_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/exercise_providers.dart';

class ExercisePickerModal extends ConsumerStatefulWidget {
  const ExercisePickerModal({super.key});

  @override
  ConsumerState<ExercisePickerModal> createState() => _ExercisePickerModalState();
}

class _ExercisePickerModalState extends ConsumerState<ExercisePickerModal> {
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

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add Exercise',
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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

              const SizedBox(height: 8),

              // Equipment Filter Chips
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    'barbell',
                    'dumbbell',
                    'machine',
                    'cable',
                    'bodyweight',
                    'kettlebell',
                    'band',
                    'other'
                  ].map((equipment) {
                    final isSelected = ref.watch(selectedEquipmentFilterProvider) == equipment;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          equipment[0].toUpperCase() + equipment.substring(1),
                          style: theme.textTheme.labelSmall,
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            ref.read(selectedEquipmentFilterProvider.notifier).setFilter(equipment);
                          } else {
                            ref.read(selectedEquipmentFilterProvider.notifier).clear();
                          }
                        },
                        selectedColor: AppColors.accent.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.accent,
                      ),
                    );
                  }).toList(),
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
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: exercises.length,
                      itemBuilder: (context, index) {
                        final exercise = exercises[index];
                        final muscleColor = AppColors.muscleColors[exercise.primaryMuscle] ?? AppColors.accent;

                        return ListTile(
                          leading: Container(
                            width: 4,
                            height: 48,
                            decoration: BoxDecoration(
                              color: muscleColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          title: Text(exercise.name),
                          subtitle: Text(
                            exercise.primaryMuscle.toUpperCase(),
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              exercise.equipment.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          onTap: () => Navigator.pop(context, exercise),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
