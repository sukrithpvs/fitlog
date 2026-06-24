// lib/features/workout/presentation/widgets/exercise_card_widget.dart

import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';

class ExerciseCardWidget extends StatelessWidget {
  final String exerciseName;
  final List<WorkoutSet> sets;
  final Widget setsTable;
  final Function(List<WorkoutSet> sets) onDeleteExercise;
  final Function(WorkoutSet sourceSet) onCreateSuperset;
  final Function(List<WorkoutSet> sets) onGenerateWarmup;
  final Function(WorkoutSet templateSet) onAddSet;
  final Function(int exerciseId, String exerciseName) onAddNote;

  const ExerciseCardWidget({
    Key? key,
    required this.exerciseName,
    required this.sets,
    required this.setsTable,
    required this.onDeleteExercise,
    required this.onCreateSuperset,
    required this.onGenerateWarmup,
    required this.onAddSet,
    required this.onAddNote,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exerciseName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'superset',
                      child: Text('Create Superset'),
                    ),
                    const PopupMenuItem(
                      value: 'warmup',
                      child: Text('Generate Warm-ups'),
                    ),
                    const PopupMenuItem(
                      value: 'note',
                      child: Text('Add/Edit Note'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Remove Exercise', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDeleteExercise(sets);
                    } else if (value == 'superset') {
                      onCreateSuperset(sets.first);
                    } else if (value == 'warmup') {
                      onGenerateWarmup(sets);
                    } else if (value == 'note') {
                      onAddNote(sets.first.exerciseId, exerciseName);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => onAddSet(sets.first),
                ),
              ],
            ),
            const SizedBox(height: 4),
            setsTable,
          ],
        ),
      ),
    );
  }
}

class SupersetCardWidget extends StatelessWidget {
  final List<WorkoutSet> sets;
  final List<String> exercises;
  final Widget Function(String exName, List<WorkoutSet> exSets) setsTableBuilder;
  final Function(List<WorkoutSet> sets) onDeleteExercise;
  final Function(String supersetId) onAddExerciseToSuperset;
  final Function(List<WorkoutSet> sets) onUnlinkSuperset;
  final Function(WorkoutSet templateSet) onAddSet;
  final Function(int exerciseId, String exerciseName) onAddNote;

  const SupersetCardWidget({
    Key? key,
    required this.sets,
    required this.exercises,
    required this.setsTableBuilder,
    required this.onDeleteExercise,
    required this.onAddExerciseToSuperset,
    required this.onUnlinkSuperset,
    required this.onAddSet,
    required this.onAddNote,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SUPERSET',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDeleteExercise(sets);
                    } else if (value == 'add_exercise') {
                      onAddExerciseToSuperset(sets.first.supersetId!);
                    } else if (value == 'unlink') {
                      onUnlinkSuperset(sets);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'add_exercise',
                      child: Text('Add Exercise'),
                    ),
                    const PopupMenuItem(
                      value: 'unlink',
                      child: Text('Unlink Superset'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Remove All', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...exercises.map((exName) {
              final exSets = sets.where((s) => s.exerciseName == exName).toList();
              final letter = String.fromCharCode(65 + exercises.indexOf(exName)); // A, B, C...
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(letter, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(exName, style: theme.textTheme.titleSmall)),
                      IconButton(
                        icon: const Icon(Icons.note_add_outlined, size: 20),
                        tooltip: 'Add Note',
                        onPressed: () => onAddNote(exSets.first.exerciseId, exName),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () => onAddSet(exSets.first),
                      ),
                    ],
                  ),
                  setsTableBuilder(exName, exSets),
                  const SizedBox(height: 16),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
