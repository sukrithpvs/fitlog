import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'dart:math';

import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/custom_charts.dart';
import '../../../core/utils/one_rm_calculator.dart';

// ─── Performed Exercises Provider ───
// Only returns exercises the user has completed at least one set of.
final performedExercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.workoutSets).watch().asyncMap((allSets) async {
    final completedSetIds = allSets.where((s) => s.isCompleted).map((s) => s.exerciseId).toSet();
    
    if (completedSetIds.isEmpty) return [];

    return (db.select(db.exercises)
          ..where((e) => e.id.isIn(completedSetIds)))
        .get();
  });
});

// ─── Exercise Stats Provider ───
class ExerciseStats {
  final List<ChartDataPoint> volumeHistory;
  final List<ChartDataPoint> maxWeightHistory;
  final List<ChartDataPoint> oneRmHistory;
  final double allTimeMaxWeight;
  final double allTimeMaxVolume;
  final double allTimeMax1RM;

  ExerciseStats({
    required this.volumeHistory,
    required this.maxWeightHistory,
    required this.oneRmHistory,
    required this.allTimeMaxWeight,
    required this.allTimeMaxVolume,
    required this.allTimeMax1RM,
  });
}

final exerciseStatsProvider = StreamProvider.family<ExerciseStats?, int>((ref, exerciseId) {
  final db = ref.watch(databaseProvider);

  return (db.select(db.workouts)
        ..where((w) => w.isTemplate.equals(false))
        ..orderBy([(w) => OrderingTerm.asc(w.startTime)]))
      .watch()
      .asyncMap((workouts) async {
    
    final volumeHistory = <ChartDataPoint>[];
    final maxWeightHistory = <ChartDataPoint>[];
    final oneRmHistory = <ChartDataPoint>[];

    double allTimeMaxWeight = 0;
    double allTimeMaxVolume = 0;
    double allTimeMax1RM = 0;

    for (final workout in workouts) {
      final sets = await db.getSetsForWorkout(workout.id);
      final exerciseSets = sets.where((s) => s.isCompleted && s.exerciseId == exerciseId && s.weight != null && s.reps != null);

      if (exerciseSets.isEmpty) continue;

      double workoutVolume = 0;
      double maxWeight = 0;
      double max1RM = 0;

      for (final s in exerciseSets) {
        final weight = s.weight!;
        final reps = s.reps!;
        
        workoutVolume += (weight * reps);
        
        if (weight > maxWeight) maxWeight = weight;
        
        // Calculate 1RM using OneRmCalculator
        final oneRm = OneRmCalculator.epley(weight, reps);
        if (oneRm != null && oneRm > max1RM) {
          max1RM = oneRm;
        }
      }

      // Update All-time PRs
      if (workoutVolume > allTimeMaxVolume) allTimeMaxVolume = workoutVolume;
      if (maxWeight > allTimeMaxWeight) allTimeMaxWeight = maxWeight;
      if (max1RM > allTimeMax1RM) allTimeMax1RM = max1RM;

      final label = DateFormatter.shortDate(workout.startTime);
      volumeHistory.add(ChartDataPoint(label: label, value: workoutVolume));
      maxWeightHistory.add(ChartDataPoint(label: label, value: maxWeight));
      oneRmHistory.add(ChartDataPoint(label: label, value: max1RM));
    }

    if (volumeHistory.isEmpty) return null;

    return ExerciseStats(
      volumeHistory: _trimHistory(volumeHistory),
      maxWeightHistory: _trimHistory(maxWeightHistory),
      oneRmHistory: _trimHistory(oneRmHistory),
      allTimeMaxWeight: allTimeMaxWeight,
      allTimeMaxVolume: allTimeMaxVolume,
      allTimeMax1RM: allTimeMax1RM,
    );
  });
});

List<ChartDataPoint> _trimHistory(List<ChartDataPoint> history) {
  if (history.length > 20) {
    return history.sublist(history.length - 20);
  }
  return history;
}

// ─── Selected Exercise Notifier ───
class SelectedExerciseNotifier extends Notifier<Exercise?> {
  @override
  Exercise? build() => null;
  void setExercise(Exercise exercise) => state = exercise;
}
final selectedExerciseProvider = NotifierProvider<SelectedExerciseNotifier, Exercise?>(SelectedExerciseNotifier.new);


// ─── Screen ───
class ExerciseProgressScreen extends ConsumerWidget {
  const ExerciseProgressScreen({super.key});

  void _showExercisePicker(BuildContext context, WidgetRef ref, List<Exercise> exercises) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExerciseSearchBottomSheet(
        exercises: exercises,
        onSelected: (ex) {
          ref.read(selectedExerciseProvider.notifier).setExercise(ex);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final exercisesAsync = ref.watch(performedExercisesProvider);
    final selectedExercise = ref.watch(selectedExerciseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Progress'),
      ),
      body: exercisesAsync.when(
        data: (exercises) {
          if (exercises.isEmpty) {
            return const Center(
              child: Text('Complete some exercises to see their progress!'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Exercise Selector Button
              GestureDetector(
                onTap: () => _showExercisePicker(context, ref, exercises),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.fitness_center, color: theme.colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          selectedExercise?.name ?? 'Select an Exercise',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: selectedExercise != null ? FontWeight.bold : FontWeight.normal,
                            color: selectedExercise != null ? theme.colorScheme.onSurface : theme.colorScheme.outline,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: theme.colorScheme.outline),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              if (selectedExercise != null)
                _ExerciseStatsView(exercise: selectedExercise),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _ExerciseStatsView extends ConsumerWidget {
  final Exercise exercise;

  const _ExerciseStatsView({required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statsAsync = ref.watch(exerciseStatsProvider(exercise.id));

    return statsAsync.when(
      data: (stats) {
        if (stats == null) {
          return const Center(child: Text('Not enough data to calculate stats.'));
        }

        // Calculate Insights
        String insightText = 'Keep pushing! Building a new baseline.';
        if (stats.volumeHistory.length >= 2) {
          final firstVol = stats.volumeHistory.first.value;
          final lastVol = stats.volumeHistory.last.value;
          if (firstVol > 0) {
            final pct = ((lastVol - firstVol) / firstVol * 100);
            if (pct > 0) {
              insightText = '🔥 Great progress! Your volume has increased by ${pct.toStringAsFixed(1)}% since your first tracked session.';
            } else if (pct < 0) {
              insightText = '📉 Volume is down by ${pct.abs().toStringAsFixed(1)}%. Make sure you are recovering properly!';
            } else {
              insightText = '⚖️ Volume is stable. Consider adding a rep or a kg to force adaptation.';
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key Insights
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      insightText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // PR Highlights
            Row(
              children: [
                Expanded(child: _PRCard(title: 'Max 1RM', value: '${stats.allTimeMax1RM.toStringAsFixed(1)} kg', icon: Icons.emoji_events, color: AppColors.accent)),
                const SizedBox(width: 8),
                Expanded(child: _PRCard(title: 'Max Weight', value: '${stats.allTimeMaxWeight.toStringAsFixed(1)} kg', icon: Icons.fitness_center, color: theme.colorScheme.primary)),
                const SizedBox(width: 8),
                Expanded(child: _PRCard(title: 'Max Volume', value: '${stats.allTimeMaxVolume.toStringAsFixed(0)} kg', icon: Icons.trending_up, color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 24),

            // Charts
            _ChartSection(title: '1RM ESTIMATION', data: stats.oneRmHistory, color: const Color(0xFFD946EF)), // Neon Purple
            const SizedBox(height: 24),
            _ChartSection(title: 'MAX WEIGHT', data: stats.maxWeightHistory, color: const Color(0xFF10B981)), // Emerald Green
            const SizedBox(height: 24),
            _ChartSection(title: 'VOLUME', data: stats.volumeHistory, color: const Color(0xFF0EA5E9)), // Electric Blue
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

class _PRCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _PRCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  final String title;
  final List<ChartDataPoint> data;
  final Color color;

  const _ChartSection({required this.title, required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.outline, letterSpacing: 1.1),
          ),
          const SizedBox(height: 16),
          if (data.isEmpty)
            const SizedBox(height: 150, child: Center(child: Text('No data.')))
          else
            SmoothLineChart(data: data, height: 180, color: color),
        ],
      ),
    );
  }
}

// ─── Searchable Bottom Sheet ───
class _ExerciseSearchBottomSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final Function(Exercise) onSelected;

  const _ExerciseSearchBottomSheet({required this.exercises, required this.onSelected});

  @override
  State<_ExerciseSearchBottomSheet> createState() => _ExerciseSearchBottomSheetState();
}

class _ExerciseSearchBottomSheetState extends State<_ExerciseSearchBottomSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = widget.exercises.where((e) => e.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search performed exercises...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final ex = filtered[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.fitness_center, color: theme.colorScheme.primary, size: 20),
                  ),
                  title: Text(ex.name),
                  subtitle: Text(ex.primaryMuscle, style: TextStyle(color: theme.colorScheme.outline)),
                  onTap: () => widget.onSelected(ex),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
