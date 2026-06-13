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
import 'widgets/muscle_recovery_card.dart';

// ─── Stats Provider (real DB data) ───
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

// ─── Volume Chart Data Provider ───
final volumeChartProvider = StreamProvider<List<ChartDataPoint>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.workouts)
        ..where((w) => w.isTemplate.equals(false))
        ..where((w) => w.endTime.isNotNull())
        ..orderBy([(w) => OrderingTerm.asc(w.startTime)]))
      .watch()
      .asyncMap((workouts) async {
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
});

// ─── Duration Chart Data Provider ───
final durationChartProvider = StreamProvider<List<ChartDataPoint>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.workouts)
        ..where((w) => w.isTemplate.equals(false))
        ..where((w) => w.endTime.isNotNull())
        ..orderBy([(w) => OrderingTerm.asc(w.startTime)]))
      .watch()
      .map((workouts) {
    final recent = workouts.length > 10 ? workouts.sublist(workouts.length - 10) : workouts;

    return recent.map((workout) {
      final duration = workout.endTime!.difference(workout.startTime).inMinutes.toDouble();
      return ChartDataPoint(
        label: DateFormatter.shortDate(workout.startTime),
        value: duration,
      );
    }).toList();
  });
});

// ─── Weekly Frequency Provider ───
final weeklyFrequencyProvider = StreamProvider<List<ChartDataPoint>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.workouts)..where((w) => w.isTemplate.equals(false))).watch().map((workouts) {
    final now = DateTime.now();
    final points = <ChartDataPoint>[];

    // Last 8 weeks
    for (int i = 7; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
      final weekEnd = weekStart.add(const Duration(days: 7));
      
      final count = workouts.where((w) => 
        w.startTime.isAfter(weekStart) && w.startTime.isBefore(weekEnd) || w.startTime.isAtSameMomentAs(weekStart)
      ).length;

      final label = i == 0 ? 'This' : i == 1 ? 'Last' : '${i}w ago';
      points.add(ChartDataPoint(
        label: label,
        value: count.toDouble(),
      ));
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
      // Assume 72 hours for 100% recovery
      double percent = hoursElapsed / 72.0;
      if (percent > 1.0) percent = 1.0;
      recovery[entry.key] = percent;
    }

    return recovery;
  });
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
    final durationAsync = ref.watch(durationChartProvider);
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    AppColors.darkBg.withValues(alpha: 0.8),
                    AppColors.darkSurface,
                  ]
                : [
                    AppColors.lightBg,
                    AppColors.lightSurface,
                  ],
          ),
        ),
        child: statsAsync.when(
          data: (stats) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Header ───
                  Text(
                    'Overview',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // ─── Stats Cards ───
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Workouts',
                          value: stats['totalWorkouts'],
                          icon: Icons.fitness_center,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'This Week',
                          value: stats['thisWeek'],
                          icon: Icons.local_fire_department,
                          color: AppColors.error, // vibrant red/orange
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'This Month',
                          value: stats['thisMonth'],
                          icon: Icons.calendar_month,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'Total Volume',
                          value: stats['totalVolume'],
                          formatter: 'kg',
                          icon: Icons.trending_up,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 36),

                // ─── Volume Over Time Chart ───
                _SectionHeader(
                  title: 'Volume Progress',
                  icon: Icons.insights,
                  color: AppColors.info,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                        ? [AppColors.darkSurface, AppColors.darkBg]
                        : [AppColors.lightSurface, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      width: 1,
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
                                Icon(Icons.show_chart, size: 48, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text('Complete workouts to see volume trends',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
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
                ),

                const SizedBox(height: 36),

                // ─── Duration Over Time Chart ───
                _SectionHeader(
                  title: 'Workout Duration',
                  icon: Icons.timer_outlined,
                  color: AppColors.warning,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                        ? [AppColors.darkSurface, AppColors.darkBg]
                        : [AppColors.lightSurface, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: durationAsync.when(
                    data: (data) {
                      if (data.isEmpty) {
                        return SizedBox(
                          height: 200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timer, size: 40, color: theme.colorScheme.outline),
                                const SizedBox(height: 8),
                                Text('Complete workouts to see duration trends',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        );
                      }
                      return SmoothLineChart(data: data, height: 220, color: AppColors.warning, valueFormatter: 'min');
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

                const SizedBox(height: 36),

                // ─── Frequency Chart ───
                _SectionHeader(
                  title: 'Workout Frequency',
                  icon: Icons.calendar_month,
                  color: AppColors.success,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                        ? [AppColors.darkSurface, AppColors.darkBg]
                        : [AppColors.lightSurface, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: weeklyAsync.when(
                    data: (data) {
                      if (data.isEmpty) {
                        return SizedBox(
                          height: 180,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bar_chart, size: 48, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text('Start working out to track frequency',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                              ],
                            ),
                          ),
                        );
                      }
                      return SmoothLineChart(data: data, height: 200, color: AppColors.success);
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

                const SizedBox(height: 36),

                // ─── Muscle Distribution ───
                _SectionHeader(
                  title: 'Muscle Distribution (30 Days)',
                  icon: Icons.pie_chart_outline,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                        ? [AppColors.darkSurface, AppColors.darkBg]
                        : [AppColors.lightSurface, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      width: 1,
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
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(entry.key, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                    Text(
                                      '${(percentage * 100).toInt()}% (${entry.value})',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0, end: percentage),
                                  duration: const Duration(milliseconds: 1200),
                                  curve: Curves.easeOutQuart,
                                  builder: (context, val, _) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: val,
                                        minHeight: 10,
                                        backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.1),
                                        valueColor: AlwaysStoppedAnimation(color),
                                      ),
                                    );
                                  },
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

                const SizedBox(height: 36),
                const MuscleRecoveryCard(),
                const SizedBox(height: 60),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    ));
  }
}

// ─── Section Header ───
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

// ─── Animated Premium Stat Card Widget ───
class _StatCard extends StatelessWidget {
  final String title;
  final num value;
  final String formatter;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    this.formatter = '',
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.05),
              ]
            : [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.02),
              ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 15,
                  spreadRadius: -5,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: -2,
                    )
                  ],
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutQuart,
            builder: (context, animValue, child) {
              String displayValue;
              if (formatter == 'kg') {
                if (animValue >= 1000) {
                  displayValue = '${(animValue / 1000).toStringAsFixed(1)}k kg';
                } else {
                  displayValue = '${animValue.toStringAsFixed(0)} kg';
                }
              } else {
                displayValue = animValue.toInt().toString();
              }

              return Text(
                displayValue,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

