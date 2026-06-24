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
import 'monthly_report_screen.dart';
import 'widgets/muscle_recovery_card.dart';
import 'widgets/weekly_targets_widget.dart';
import 'widgets/progressive_overload_widget.dart';
import '../utils/streak_calculator.dart';

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

    final completedSets = await (db.select(db.workoutSets)..where((s) => s.isCompleted.equals(true))).get();
    final totalVolume = completedSets
        .where((s) => s.weight != null && s.reps != null)
        .fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));
        
    final streakData = StreakCalculator.calculateWeeklyStreak(workouts);

    return {
      'totalWorkouts': workouts.length,
      'thisWeek': thisWeek,
      'thisMonth': thisMonth,
      'totalVolume': totalVolume,
      'workouts': workouts,
      'currentStreak': streakData.currentStreak,
      'bestStreak': streakData.bestStreak,
    };
  });
});

// ─── Global Volume Time Range Provider ───
final volumeTimeRangeProvider = NotifierProvider<VolumeTimeRangeNotifier, String>(
  VolumeTimeRangeNotifier.new,
);

class VolumeTimeRangeNotifier extends Notifier<String> {
  @override
  String build() => '3m';

  void setRange(String range) => state = range;
}

// ─── Global Volume Chart Provider ───
final globalVolumeChartProvider = StreamProvider<List<ChartDataPoint>>((ref) {
  final db = ref.watch(databaseProvider);
  final timeRange = ref.watch(volumeTimeRangeProvider);

  DateTime? startDate;
  final now = DateTime.now();
  if (timeRange == '1m') startDate = now.subtract(const Duration(days: 30));
  else if (timeRange == '3m') startDate = now.subtract(const Duration(days: 90));
  else if (timeRange == '6m') startDate = now.subtract(const Duration(days: 180));
  else if (timeRange == '1y') startDate = now.subtract(const Duration(days: 365));

  var query = db.select(db.workouts)..where((w) => w.isTemplate.equals(false));
  if (startDate != null) {
    query.where((w) => w.startTime.isBiggerOrEqualValue(startDate!));
  }
  query.orderBy([(w) => OrderingTerm.asc(w.startTime)]);

  return query.watch().asyncMap((workouts) async {
    final points = <ChartDataPoint>[];
    if (workouts.isEmpty) return points;

    final workoutIds = workouts.map((w) => w.id).toList();
    final allSets = await (db.select(db.workoutSets)
      ..where((s) => s.workoutId.isIn(workoutIds))).get();
    
    final setsByWorkout = <int, List<WorkoutSet>>{};
    for (final s in allSets) {
      setsByWorkout.putIfAbsent(s.workoutId, () => []).add(s);
    }

    for (final workout in workouts) {
      final sets = setsByWorkout[workout.id] ?? [];
      
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
final muscleDistributionProvider = StreamProvider<Map<String, double>>((ref) {
  final db = ref.watch(databaseProvider);
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

  return (db.select(db.workouts)
        ..where((w) => w.isTemplate.equals(false))
        ..where((w) => w.startTime.isBiggerOrEqualValue(thirtyDaysAgo)))
      .watch()
      .asyncMap((workouts) async {
    final distribution = <String, double>{};
    if (workouts.isEmpty) return distribution;

    final workoutIds = workouts.map((w) => w.id).toList();
    final allSets = await (db.select(db.workoutSets)
      ..where((s) => s.workoutId.isIn(workoutIds))).get();
    
    final exerciseIds = allSets.map((s) => s.exerciseId).toSet();
    if (exerciseIds.isEmpty) return distribution;

    final exercises = await (db.select(db.exercises)
      ..where((e) => e.id.isIn(exerciseIds))).get();
    final exerciseMap = {for (final e in exercises) e.id: e};

    final setsByWorkout = <int, List<WorkoutSet>>{};
    for (final s in allSets) {
      setsByWorkout.putIfAbsent(s.workoutId, () => []).add(s);
    }

    for (final workout in workouts) {
      final sets = setsByWorkout[workout.id] ?? [];
      final uniqueExerciseIds = sets.map((s) => s.exerciseId).toSet();

      for (final exerciseId in uniqueExerciseIds) {
        final exercise = exerciseMap[exerciseId];
        if (exercise != null) {
          distribution[exercise.primaryMuscle] =
              (distribution[exercise.primaryMuscle] ?? 0.0) + 1.0;
          
          if (exercise.secondaryMuscles.isNotEmpty) {
            final secondaries = exercise.secondaryMuscles.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
            for (final secondary in secondaries) {
              distribution[secondary] = (distribution[secondary] ?? 0.0) + 0.5;
            }
          }
        }
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
    if (workouts.isEmpty) return <String, double>{};

    final workoutIds = workouts.map((w) => w.id).toList();
    final allSets = await (db.select(db.workoutSets)
      ..where((s) => s.workoutId.isIn(workoutIds))).get();
    
    final exerciseIds = allSets.map((s) => s.exerciseId).toSet();
    if (exerciseIds.isEmpty) return <String, double>{};

    final exercises = await (db.select(db.exercises)
      ..where((e) => e.id.isIn(exerciseIds))).get();
    final exerciseMap = {for (final e in exercises) e.id: e};

    final setsByWorkout = <int, List<WorkoutSet>>{};
    for (final s in allSets) {
      setsByWorkout.putIfAbsent(s.workoutId, () => []).add(s);
    }

    for (final workout in workouts) {
      final sets = setsByWorkout[workout.id] ?? [];
      final uniqueExerciseIds = sets.map((s) => s.exerciseId).toSet();

      for (final exerciseId in uniqueExerciseIds) {
        final exercise = exerciseMap[exerciseId];
        if (exercise != null) {
          final muscle = exercise.primaryMuscle;
          if (!lastTrained.containsKey(muscle)) {
            lastTrained[muscle] = workout.startTime;
          } else if (workout.startTime.isAfter(lastTrained[muscle]!)) {
            lastTrained[muscle] = workout.startTime;
          }
        }
      }
    }

    final recovery = <String, double>{};
    final now = DateTime.now();
    
    final customRecoveryHours = <String, double>{
      'legs': 72.0,
      'chest': 48.0,
      'back': 48.0,
      'shoulders': 48.0,
      'arms': 24.0,
      'biceps': 24.0,
      'triceps': 24.0,
      'core': 24.0,
      'forearms': 24.0,
      'calves': 24.0,
      'glutes': 48.0,
    };

    for (final entry in lastTrained.entries) {
      final hoursElapsed = now.difference(entry.value).inHours.toDouble();
      final targetRecovery = customRecoveryHours[entry.key.toLowerCase()] ?? 48.0;
      double percent = hoursElapsed / targetRecovery;
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
            icon: const Icon(Icons.calendar_month, color: AppColors.accent),
            tooltip: 'Monthly Wrap-Up',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MonthlyReportScreen()),
              );
            },
          ),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Current Streak',
                            value: '${stats['currentStreak']} wks',
                            icon: Icons.local_fire_department,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Best Streak',
                            value: '${stats['bestStreak']} wks',
                            icon: Icons.emoji_events,
                            color: Colors.amber,
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

            const SizedBox(height: 16),
            const ProgressiveOverloadWidget(),
            const SizedBox(height: 16),
            const WeeklyTargetsWidget(),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL VOLUME',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: '1m', label: Text('1M')),
                          ButtonSegment(value: '3m', label: Text('3M')),
                          ButtonSegment(value: '6m', label: Text('6M')),
                          ButtonSegment(value: 'all', label: Text('ALL')),
                        ],
                        selected: {ref.watch(volumeTimeRangeProvider)},
                        onSelectionChanged: (set) {
                          ref.read(volumeTimeRangeProvider.notifier).setRange(set.first);
                        },
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
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

                  final total = distribution.values.fold<double>(0.0, (sum, count) => sum + count);
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
                                  '${(percentage * 100).toInt()}% (${entry.value.toStringAsFixed(1)})',
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


