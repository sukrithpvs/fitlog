// lib/features/analytics/presentation/analytics_tab_screen.dart
// Analytics dashboard — all data from real DB, granular filtering.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/custom_charts.dart';
import 'body_metrics_screen.dart';
import 'muscle_progress_screen.dart';
import 'exercise_progress_screen.dart';
import 'widgets/muscle_recovery_card.dart';

// ─── Stats Provider (Overview) ───
final workoutStatsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.workouts)
        ..where((w) => w.isTemplate.equals(false))
        ..orderBy([(w) => OrderingTerm.desc(w.startTime)]))
      .watch()
      .asyncMap((workouts) async {
    final now = DateTime.now();
    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisMonthStart = DateTime(now.year, now.month, 1);

    final thisWeek = workouts.where((w) => w.startTime.isAfter(thisWeekStart)).length;
    final thisMonth = workouts.where((w) => w.startTime.isAfter(thisMonthStart)).length;

    final allSets = await db.select(db.workoutSets).get();
    final completedSets = allSets.where((s) => s.isCompleted).toList();
    final totalVolume = completedSets
        .where((s) => s.weight != null && s.reps != null)
        .fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));

    return {
      'totalWorkouts': workouts.length,
      'thisWeek': thisWeek,
      'thisMonth': thisMonth,
      'totalVolume': totalVolume,
      'workouts': workouts,
    };
  });
});

// ─── Global Volume Chart Provider ───
final globalVolumeChartProvider = StreamProvider<List<ChartDataPoint>>((ref) {
  final db = ref.watch(databaseProvider);

  return (db.select(db.workouts)
        ..where((w) => w.isTemplate.equals(false))
        ..where((w) => w.endTime.isNotNull())
        ..orderBy([(w) => OrderingTerm.asc(w.startTime)]))
      .watch()
      .asyncMap((workouts) async {
    final points = <ChartDataPoint>[];

    for (final workout in workouts) {
      final sets = await db.getSetsForWorkout(workout.id);
      
      double workoutVolume = 0;

      for (final s in sets.where((s) => s.isCompleted && s.weight != null && s.reps != null)) {
         workoutVolume += (s.weight! * s.reps!);
      }

      if (workoutVolume > 0) {
        points.add(ChartDataPoint(
          label: DateFormatter.shortDate(workout.startTime),
          value: workoutVolume,
        ));
      }
    }

    if (points.length > 15) {
      return points.sublist(points.length - 15);
    }
    return points;
  });
});

// ─── Muscle Distribution Provider ───
final muscleDistributionProvider = StreamProvider<Map<String, int>>((ref) {
  final db = ref.watch(databaseProvider);
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

  return (db.select(db.workouts)
        ..where((w) => w.isTemplate.equals(false))
        ..where((w) => w.startTime.isBiggerOrEqualValue(thirtyDaysAgo)))
      .watch()
      .asyncMap((workouts) async {
    final distribution = <String, int>{};

    for (final workout in workouts) {
      final sets = await db.getSetsForWorkout(workout.id);
      final exerciseIds = sets.map((s) => s.exerciseId).toSet();

      for (final exerciseId in exerciseIds) {
        try {
          final exercise = await (db.select(db.exercises)
                ..where((e) => e.id.equals(exerciseId)))
              .getSingleOrNull();

          if (exercise != null) {
            distribution[exercise.primaryMuscle] =
                (distribution[exercise.primaryMuscle] ?? 0) + 1;
          }
        } catch (_) {}
      }
    }

    return distribution;
  });
});

// ─── Muscle Recovery Provider ───
final muscleRecoveryProvider = StreamProvider<Map<String, double>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.workouts)
        ..where((w) => w.isTemplate.equals(false))
        ..orderBy([(w) => OrderingTerm.desc(w.startTime)]))
      .watch()
      .asyncMap((workouts) async {
    final lastTrained = <String, DateTime>{};

    for (final workout in workouts) {
      final sets = await db.getSetsForWorkout(workout.id);
      final exerciseIds = sets.map((s) => s.exerciseId).toSet();

      for (final exerciseId in exerciseIds) {
        try {
          final exercise = await (db.select(db.exercises)
                ..where((e) => e.id.equals(exerciseId)))
              .getSingleOrNull();

          if (exercise != null) {
            final muscle = exercise.primaryMuscle;
            if (!lastTrained.containsKey(muscle)) {
              lastTrained[muscle] = workout.startTime;
            } else if (workout.startTime.isAfter(lastTrained[muscle]!)) {
              lastTrained[muscle] = workout.startTime;
            }
          }
        } catch (_) {}
      }
    }

    final recovery = <String, double>{};
    final now = DateTime.now();
    for (final entry in lastTrained.entries) {
      final hoursElapsed = now.difference(entry.value).inHours.toDouble();
      double percent = hoursElapsed / 72.0;
      if (percent > 1.0) percent = 1.0;
      recovery[entry.key] = percent;
    }

    return recovery;
  });
});

// ─── Analytics Screen ───
class AnalyticsTabScreen extends ConsumerStatefulWidget {
  const AnalyticsTabScreen({super.key});

  @override
  ConsumerState<AnalyticsTabScreen> createState() => _AnalyticsTabScreenState();
}

class _AnalyticsTabScreenState extends ConsumerState<AnalyticsTabScreen> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statsAsync = ref.watch(workoutStatsProvider);
    final muscleAsync = ref.watch(muscleDistributionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MuscleProgressScreen()),
              );
            },
            tooltip: 'Muscle Progress',
          ),
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExerciseProgressScreen()),
              );
            },
            tooltip: 'Exercise Progress',
          ),
          IconButton(
            icon: const Icon(Icons.monitor_weight),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BodyMetricsScreen()),
              );
            },
            tooltip: 'Body Metrics',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(workoutStatsProvider);
              ref.invalidate(globalVolumeChartProvider);
              ref.invalidate(muscleDistributionProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Stats Cards
            statsAsync.when(
              data: (stats) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Total Workouts',
                            value: '${stats['totalWorkouts']}',
                            icon: Icons.fitness_center,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'This Week',
                            value: '${stats['thisWeek']}',
                            icon: Icons.calendar_today,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'This Month',
                            value: '${stats['thisMonth']}',
                            icon: Icons.calendar_month,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Total Volume',
                            value: _formatVolume(stats['totalVolume'] as double),
                            icon: Icons.trending_up,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),

            const SizedBox(height: 28),

            // Volume Progress Header
            Text(
              'VOLUME PROGRESS',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            // Segmented Control & Selector
            Container(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'TOTAL VOLUME',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Volume Chart
                  ref.watch(globalVolumeChartProvider).when(
                    data: (data) {
                      if (data.isEmpty) {
                        return SizedBox(
                          height: 200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.show_chart, size: 40, color: theme.colorScheme.outline),
                                const SizedBox(height: 8),
                                Text('No volume data yet.',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        );
                      }
                      return SmoothLineChart(data: data, height: 220, color: AppColors.info);
                    },
                    loading: () => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, _) => SizedBox(
                      height: 200,
                      child: Center(child: Text('Error: $err')),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ─── Muscle Distribution Chart ───
            Text(
              'MUSCLE DISTRIBUTION (LAST 30 DAYS)',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
              child: muscleAsync.when(
                data: (distribution) {
                  if (distribution.isEmpty) {
                    return SizedBox(
                      height: 150,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pie_chart_outline, size: 40, color: theme.colorScheme.outline),
                            const SizedBox(height: 8),
                            Text('Complete workouts to see muscle distribution',
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    );
                  }

                  final total = distribution.values.fold<int>(0, (sum, count) => sum + count);
                  final sorted = distribution.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  return Column(
                    children: sorted.map((entry) {
                      final percentage = entry.value / total;
                      final muscleKey = entry.key.toLowerCase().replaceAll(' ', '');
                      final color = AppColors.muscleColors[muscleKey] ?? AppColors.accent;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key, style: theme.textTheme.bodyMedium),
                                Text(
                                  '${(percentage * 100).toInt()}% (${entry.value})',
                                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage,
                                minHeight: 8,
                                backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation(color),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),

            const SizedBox(height: 16),
            const MuscleRecoveryCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}k kg';
    }
    return '${volume.toStringAsFixed(0)} kg';
  }
}

// ─── Stat Card Widget ───
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Segmented Toggle Button ───
class _ToggleButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
