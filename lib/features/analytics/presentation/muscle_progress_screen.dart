// lib/features/analytics/presentation/muscle_progress_screen.dart
// Comprehensive muscle group analytics and progress tracking
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_charts.dart';

// Provider for muscle group analytics
final muscleAnalyticsProvider = StreamProvider.family<MuscleGroupAnalytics, String>((ref, muscle) async* {
  final db = ref.watch(databaseProvider);
  
  // Watch all workouts
  final workoutsStream = (db.select(db.workouts)
        ..where((w) => w.isTemplate.equals(false))
        ..orderBy([(w) => OrderingTerm.desc(w.startTime)]))
      .watch();

  await for (final workouts in workoutsStream) {

  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
  
  double totalVolume = 0;
  int totalSets = 0;
  int workoutsWithMuscle = 0;
  final volumeByDate = <DateTime, double>{};
  final setsByDate = <DateTime, int>{};
  
  for (final workout in workouts) {
    final sets = await db.getSetsForWorkout(workout.id);
    bool workoutHasMuscle = false;
    double workoutVolume = 0;
    int workoutSets = 0;
    
    for (final set in sets) {
      if (!set.isCompleted || set.weight == null || set.reps == null) continue;
      
      // Get exercise to check muscle
      try {
        final exercise = await db.getExerciseById(set.exerciseId);
        if (exercise.primaryMuscle.toLowerCase() == muscle.toLowerCase()) {
          final volume = set.weight! * set.reps!;
          totalVolume += volume;
          totalSets++;
          workoutHasMuscle = true;
          workoutVolume += volume;
          workoutSets++;
        }
      } catch (_) {}
    }
    
    if (workoutHasMuscle) {
      workoutsWithMuscle++;
      final date = DateTime(workout.startTime.year, workout.startTime.month, workout.startTime.day);
      volumeByDate[date] = (volumeByDate[date] ?? 0) + workoutVolume;
      setsByDate[date] = (setsByDate[date] ?? 0) + workoutSets;
    }
  }
  
  // Calculate frequency (last 30 days)
  final recentWorkouts = workouts.where((w) => w.startTime.isAfter(thirtyDaysAgo)).toList();
  int recentWorkoutsWithMuscle = 0;
  for (final workout in recentWorkouts) {
    final sets = await db.getSetsForWorkout(workout.id);
    for (final set in sets) {
      try {
        final exercise = await db.getExerciseById(set.exerciseId);
        if (exercise.primaryMuscle.toLowerCase() == muscle.toLowerCase()) {
          recentWorkoutsWithMuscle++;
          break;
        }
      } catch (_) {}
    }
  }
  
  // Get last 12 weeks data for charts
  final weeklyData = <ChartDataPoint>[];
  final now = DateTime.now();
  for (int i = 11; i >= 0; i--) {
    final weekStart = now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
    final weekEnd = weekStart.add(const Duration(days: 7));
    
    double weekVolume = 0;
    for (final entry in volumeByDate.entries) {
      if (entry.key.isAfter(weekStart) && entry.key.isBefore(weekEnd)) {
        weekVolume += entry.value;
      }
    }
    
    final label = i == 0 ? 'This' : i == 1 ? 'Last' : '${i}w';
    weeklyData.add(ChartDataPoint(label: label, value: weekVolume));
  }
  
  // Average volume per session
  final avgVolume = workoutsWithMuscle > 0 ? totalVolume / workoutsWithMuscle : 0.0;
  
    yield MuscleGroupAnalytics(
      muscleName: muscle,
      totalVolume: totalVolume,
      totalSets: totalSets,
      workoutCount: workoutsWithMuscle,
      frequencyPerWeek: recentWorkoutsWithMuscle / 4.0, // 30 days ≈ 4 weeks
      avgVolumePerSession: avgVolume,
      weeklyVolumeData: weeklyData,
      volumeByDate: volumeByDate,
    );
  }
});

class MuscleGroupAnalytics {
  final String muscleName;
  final double totalVolume;
  final int totalSets;
  final int workoutCount;
  final double frequencyPerWeek;
  final double avgVolumePerSession;
  final List<ChartDataPoint> weeklyVolumeData;
  final Map<DateTime, double> volumeByDate;

  MuscleGroupAnalytics({
    required this.muscleName,
    required this.totalVolume,
    required this.totalSets,
    required this.workoutCount,
    required this.frequencyPerWeek,
    required this.avgVolumePerSession,
    required this.weeklyVolumeData,
    required this.volumeByDate,
  });
}

class MuscleProgressScreen extends ConsumerStatefulWidget {
  const MuscleProgressScreen({super.key});

  @override
  ConsumerState<MuscleProgressScreen> createState() => _MuscleProgressScreenState();
}

class _MuscleProgressScreenState extends ConsumerState<MuscleProgressScreen> {
  String _selectedMuscle = 'Chest';
  
  final List<String> _muscleGroups = [
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Legs',
    'Core',
    'Calves',
    'Cardio',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final analyticsAsync = ref.watch(muscleAnalyticsProvider(_selectedMuscle));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Muscle Group Progress'),
      ),
      body: Column(
        children: [
          // Muscle selector
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _muscleGroups.map((muscle) {
                  final isSelected = muscle == _selectedMuscle;
                  final color = AppColors.muscleColors[muscle.toLowerCase()] ?? AppColors.accent;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(muscle),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedMuscle = muscle);
                        }
                      },
                      selectedColor: color.withValues(alpha: 0.3),
                      backgroundColor: isDark 
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                      labelStyle: TextStyle(
                        color: isSelected ? color : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? color : theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Analytics content
          Expanded(
            child: analyticsAsync.when(
              data: (analytics) => _buildAnalyticsContent(analytics, theme, isDark),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('Error loading data: $err'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent(MuscleGroupAnalytics analytics, ThemeData theme, bool isDark) {
    final color = AppColors.muscleColors[analytics.muscleName.toLowerCase()] ?? AppColors.accent;
    
    if (analytics.workoutCount == 0) {
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
              'No ${analytics.muscleName} workouts yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Start training to see progress',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Total Volume',
                  value: '${analytics.totalVolume.toStringAsFixed(0)} kg',
                  icon: Icons.trending_up,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Total Sets',
                  value: '${analytics.totalSets}',
                  icon: Icons.fitness_center,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Workouts',
                  value: '${analytics.workoutCount}',
                  icon: Icons.calendar_today,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Frequency',
                  value: '${analytics.frequencyPerWeek.toStringAsFixed(1)}/week',
                  icon: Icons.repeat,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(
            title: 'Average Volume per Session',
            value: '${analytics.avgVolumePerSession.toStringAsFixed(0)} kg',
            icon: Icons.show_chart,
            color: color,
            fullWidth: true,
          ),

          const SizedBox(height: 28),

          // Weekly Volume Chart
          Text(
            'VOLUME OVER TIME (WEEKLY)',
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
            child: analytics.weeklyVolumeData.every((d) => d.value == 0)
                ? SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'No data available',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  )
                : SmoothLineChart(
                    data: analytics.weeklyVolumeData,
                    height: 220,
                    color: color,
                  ),
          ),

          const SizedBox(height: 28),

          // Training Distribution
          Text(
            'TRAINING INSIGHTS',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                _InsightRow(
                  icon: Icons.calendar_month,
                  label: 'Training Frequency',
                  value: '${analytics.frequencyPerWeek.toStringAsFixed(1)} times per week',
                  color: color,
                ),
                const SizedBox(height: 16),
                _InsightRow(
                  icon: Icons.trending_up,
                  label: 'Avg Sets per Session',
                  value: '${(analytics.totalSets / analytics.workoutCount).toStringAsFixed(1)} sets',
                  color: color,
                ),
                const SizedBox(height: 16),
                _InsightRow(
                  icon: Icons.bar_chart,
                  label: 'Total Training Sessions',
                  value: '${analytics.workoutCount} workouts',
                  color: color,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool fullWidth;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: fullWidth ? double.infinity : null,
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
        crossAxisAlignment: fullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
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
              Flexible(
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
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall,
              ),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
