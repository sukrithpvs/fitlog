import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../workout/presentation/active_workout_screen.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  final int workoutId;

  const WorkoutDetailScreen({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActiveWorkoutScreen(
                    workoutId: workoutId,
                    isEditing: true,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, db),
          ),
        ],
      ),
      body: FutureBuilder<Workout>(
        future: db.getWorkoutById(workoutId),
        builder: (context, workoutSnapshot) {
          if (workoutSnapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('Could not load workout', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('${workoutSnapshot.error}', style: theme.textTheme.bodySmall),
                ],
              ),
            );
          }

          if (!workoutSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final workout = workoutSnapshot.data!;
          final duration = workout.endTime?.difference(workout.startTime);

          return FutureBuilder<List<WorkoutSet>>(
            future: db.getSetsForWorkout(workoutId),
            builder: (context, setsSnapshot) {
              if (!setsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final sets = setsSnapshot.data!;

              if (sets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center_outlined, size: 48, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('No exercises recorded', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('This workout has no set data', style: theme.textTheme.bodySmall),
                    ],
                  ),
                );
              }

              // Group by supersetId or exerciseId
              final groups = <String, List<WorkoutSet>>{};
              for (final set in sets) {
                final key = set.supersetId ?? set.exerciseId.toString();
                groups.putIfAbsent(key, () => []).add(set);
              }

              // Calculate totals
              final totalVolume = sets
                  .where((s) => s.isCompleted && s.weight != null && s.reps != null)
                  .fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));
              final completedSets = sets.where((s) => s.isCompleted).length;
              final totalSets = sets.length;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Workout Summary Card ───
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.accent.withValues(alpha: 0.15),
                            AppColors.accent.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workout.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormatter.fullDate(workout.startTime),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Stats Row
                          Row(
                            children: [
                              _StatBadge(
                                icon: Icons.timer_outlined,
                                label: duration != null ? DateFormatter.duration(duration) : '-',
                                sublabel: 'Duration',
                              ),
                              const SizedBox(width: 16),
                              _StatBadge(
                                icon: Icons.check_circle_outline,
                                label: '$completedSets/$totalSets',
                                sublabel: 'Sets',
                              ),
                              const SizedBox(width: 16),
                              _StatBadge(
                                icon: Icons.trending_up,
                                label: '${totalVolume.toStringAsFixed(0)} kg',
                                sublabel: 'Volume',
                              ),
                            ],
                          ),

                          // Intensity Rating
                          if (workout.intensityRating != null) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Text(
                                  'Intensity: ',
                                  style: theme.textTheme.bodySmall,
                                ),
                                ...List.generate(5, (index) {
                                  return Icon(
                                    index < workout.intensityRating! ? Icons.star : Icons.star_border,
                                    color: AppColors.warning,
                                    size: 16,
                                  );
                                }),
                              ],
                            ),
                          ],

                          // Notes
                          if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.notes, size: 16, color: theme.colorScheme.outline),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      workout.notes!,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ─── Section Header ───
                    Text(
                      'EXERCISES (${groups.length})',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Exercise Cards ───
                    ...groups.values.map((groupSets) {
                      final isSuperset = groupSets.first.supersetId != null;

                      if (isSuperset) {
                        return _buildSupersetCard(context, groupSets);
                      } else {
                        return _buildExerciseCard(context, groupSets);
                      }
                    }),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, List<WorkoutSet> sets) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final exerciseName = sets.first.exerciseName;
    final exerciseVolume = sets
        .where((s) => s.isCompleted && s.weight != null && s.reps != null)
        .fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));
    final bestSet = _getBestSet(sets);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exerciseName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${exerciseVolume.toStringAsFixed(0)} kg',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (bestSet != null) ...[
            const SizedBox(height: 6),
            Text(
              '🏆 Best: ${bestSet.weight?.toStringAsFixed(1)} kg × ${bestSet.reps}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildSetsTable(context, sets),
        ],
      ),
    );
  }

  Widget _buildSupersetCard(BuildContext context, List<WorkoutSet> sets) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final exercises = sets.map((s) => s.exerciseName).toSet().toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SUPERSET (${exercises.length} Exercises)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...exercises.map((exName) {
            final exSets = sets.where((s) => s.exerciseName == exName).toList();
            final letter = String.fromCharCode(65 + exercises.indexOf(exName));

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
                  ],
                ),
                const SizedBox(height: 8),
                _buildSetsTable(context, exSets),
                const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSetsTable(BuildContext context, List<WorkoutSet> sets) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 40,
              child: Text('SET', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
            ),
            Expanded(
              child: Text('WEIGHT', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
            ),
            Expanded(
              child: Text('REPS', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
            ),
            const SizedBox(width: 32),
          ],
        ),
        const SizedBox(height: 4),
        Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ...sets.asMap().entries.map((setEntry) {
          final setIndex = setEntry.key + 1;
          final set = setEntry.value;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: set.isCompleted
                          ? AppColors.success.withValues(alpha: 0.1)
                          : theme.colorScheme.outline.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$setIndex',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: set.isCompleted ? AppColors.success : null,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    set.weight != null ? '${set.weight!.toStringAsFixed(1)} kg' : '—',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        set.reps != null ? '${set.reps} reps' : '—',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      if (set.isPersonalRecord) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.emoji_events, color: AppColors.warning, size: 16),
                      ],
                    ],
                  ),
                ),
                Icon(
                  set.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: set.isCompleted ? AppColors.success : theme.colorScheme.outline,
                  size: 20,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  WorkoutSet? _getBestSet(List<WorkoutSet> sets) {
    WorkoutSet? best;
    double bestVolume = 0;
    for (final set in sets) {
      if (set.isCompleted && set.weight != null && set.reps != null) {
        final vol = set.weight! * set.reps!;
        if (vol > bestVolume) {
          bestVolume = vol;
          best = set;
        }
      }
    }
    return best;
  }

  Future<void> _confirmDelete(BuildContext context, AppDatabase db) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workout'),
        content: const Text('This will permanently delete this workout and all its sets. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await db.deleteSetsForWorkout(workoutId);
      await db.deleteWorkout(workoutId);
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Workout deleted')),
      );
    }
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            sublabel,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
