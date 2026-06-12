// lib/features/analytics/presentation/analytics_tab_screen.dart
// Analytics dashboard — all data from real DB, zero mock data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/custom_charts.dart';
import 'body_metrics_screen.dart';
import 'muscle_progress_screen.dart';

// ─── Stats Provider (real DB data) ───
final workoutStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseProvider);
  final workouts = await (db.select(db.workouts)
        ..where((w) => w.isTemplate.equals(false))
        ..orderBy([(w) => OrderingTerm.desc(w.startTime)]))
      .get();

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

// ─── Volume Chart Data Provider ───
final volumeChartProvider = FutureProvider<List<ChartDataPoint>>((ref) async {
  final db = ref.watch(databaseProvider);
  final workouts = await (db.select(db.workouts)
        ..where((w) => w.isTemplate.equals(false))
        ..where((w) => w.endTime.isNotNull())
        ..orderBy([(w) => OrderingTerm.asc(w.startTime)]))
      .get();

  // Take last 10 workouts
  final recent = workouts.length > 10 ? workouts.sublist(workouts.length - 10) : workouts;

  final points = <ChartDataPoint>[];
  for (final workout in recent) {
    final sets = await db.getSetsForWorkout(workout.id);
    final volume = sets
        .where((s) => s.isCompleted && s.weight != null && s.reps != null)
        .fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));
    points.add(ChartDataPoint(
      label: DateFormatter.shortDate(workout.startTime),
      value: volume,
    ));
  }

  return points;
});

// ─── Weekly Frequency Provider ───
final weeklyFrequencyProvider = FutureProvider<List<ChartDataPoint>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final points = <ChartDataPoint>[];

  // Last 8 weeks
  for (int i = 7; i >= 0; i--) {
    final weekStart = now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
    final weekEnd = weekStart.add(const Duration(days: 7));
    
    final workouts = await (db.select(db.workouts)
          ..where((w) => w.isTemplate.equals(false))
          ..where((w) => w.startTime.isBiggerOrEqualValue(weekStart))
          ..where((w) => w.startTime.isSmallerThanValue(weekEnd)))
        .get();

    final label = i == 0 ? 'This' : i == 1 ? 'Last' : '${i}w ago';
    points.add(ChartDataPoint(
      label: label,
      value: workouts.length.toDouble(),
    ));
  }

  return points;
});

// ─── Muscle Distribution Provider ───
final muscleDistributionProvider = FutureProvider<Map<String, int>>((ref) async {
  final db = ref.watch(databaseProvider);
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

  final workouts = await (db.select(db.workouts)
        ..where((w) => w.isTemplate.equals(false))
        ..where((w) => w.startTime.isBiggerOrEqualValue(thirtyDaysAgo)))
      .get();

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

// ─── Analytics Screen ───
class AnalyticsTabScreen extends ConsumerWidget {
  const AnalyticsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statsAsync = ref.watch(workoutStatsProvider);
    final volumeAsync = ref.watch(volumeChartProvider);
    final weeklyAsync = ref.watch(weeklyFrequencyProvider);
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
              ref.invalidate(volumeChartProvider);
              ref.invalidate(weeklyFrequencyProvider);
              ref.invalidate(muscleDistributionProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) {

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Stats Cards ───
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

                const SizedBox(height: 28),

                // ─── Volume Over Time Chart ───
                Text(
                  'VOLUME PER WORKOUT',
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
                  child: volumeAsync.when(
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
                                Text('Complete workouts to see volume trends',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        );
                      }
                      return VolumeLineChart(data: data, height: 220);
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
                ),

                const SizedBox(height: 28),

                // ─── Weekly Frequency Chart ───
                Text(
                  'WORKOUTS PER WEEK',
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
                  child: weeklyAsync.when(
                    data: (data) {
                      if (data.every((d) => d.value == 0)) {
                        return SizedBox(
                          height: 180,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bar_chart, size: 40, color: theme.colorScheme.outline),
                                const SizedBox(height: 8),
                                Text('Start working out to track frequency',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        );
                      }
                      return WeeklyBarChart(data: data, height: 200);
                    },
                    loading: () => const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, _) => SizedBox(
                      height: 180,
                      child: Center(child: Text('Error: $err')),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ─── Muscle Distribution ───
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
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Column(
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

                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
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
