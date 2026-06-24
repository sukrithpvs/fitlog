import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_formatter.dart';
import '../utils/coach_insight_generator.dart';
import '../../../core/theme/app_colors.dart';

class MonthlyReportScreen extends ConsumerStatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  ConsumerState<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends ConsumerState<MonthlyReportScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isLoading = true;
  
  int _totalWorkouts = 0;
  double _totalVolume = 0;
  Duration _totalDuration = Duration.zero;
  String _favoriteExercise = 'None';
  String _mostTrainedMuscle = 'None';
  String _aiInsight = 'Keep lifting to generate insights!';

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseProvider);
    
    final startOfMonth = _currentMonth;
    final endOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);

    final workouts = await (db.select(db.workouts)
      ..where((w) => w.isTemplate.equals(false))
      ..where((w) => w.startTime.isBetweenValues(startOfMonth, endOfMonth))
    ).get();

    _totalWorkouts = workouts.length;
    _totalVolume = 0;
    _totalDuration = Duration.zero;

    final exerciseCounts = <String, int>{};
    final exerciseIdCounts = <int, int>{};
    final muscleCounts = <String, double>{};

    for (final workout in workouts) {
      if (workout.endTime != null) {
        _totalDuration += workout.endTime!.difference(workout.startTime);
      }

      final sets = await db.getSetsForWorkout(workout.id);
      final completedSets = sets.where((s) => s.isCompleted).toList();
      
      for (final s in completedSets) {
        if (s.weight != null && s.reps != null) {
          _totalVolume += (s.weight! * s.reps!);
        }
        
        exerciseCounts[s.exerciseName] = (exerciseCounts[s.exerciseName] ?? 0) + 1;
        exerciseIdCounts[s.exerciseId] = (exerciseIdCounts[s.exerciseId] ?? 0) + 1;
        
        final ex = await db.getExerciseById(s.exerciseId);
        muscleCounts[ex.primaryMuscle] = (muscleCounts[ex.primaryMuscle] ?? 0) + 1.0;
        
        final secondaries = ex.secondaryMuscles.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
        for (final sec in secondaries) {
          muscleCounts[sec] = (muscleCounts[sec] ?? 0) + 0.5;
        }
      }
    }

    if (exerciseCounts.isNotEmpty) {
      _favoriteExercise = exerciseCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    } else {
      _favoriteExercise = 'None';
    }

    if (muscleCounts.isNotEmpty) {
      _mostTrainedMuscle = muscleCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    } else {
      _mostTrainedMuscle = 'None';
    }

    _aiInsight = await CoachInsightGenerator.generateMonthlyInsight(
      db,
      workouts,
      muscleCounts,
      exerciseIdCounts,
    );

    setState(() => _isLoading = false);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _loadMonthData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_currentMonth.year == now.year && _currentMonth.month == now.month) return;
    
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _loadMonthData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthFormat = DateFormat('MMMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Wrap-Up'),
      ),
      body: Column(
        children: [
          // Month Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: _previousMonth),
                Text(monthFormat.format(_currentMonth), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: (_currentMonth.year == DateTime.now().year && _currentMonth.month == DateTime.now().month) ? null : _nextMonth,
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // AI Insight Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary.withValues(alpha: 0.8), AppColors.accent.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Coach Insight', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(_aiInsight, style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Main Stats Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                      children: [
                        _StatCard(title: 'Workouts', value: '$_totalWorkouts', icon: Icons.fitness_center, color: AppColors.accent),
                        _StatCard(title: 'Volume', value: '${(_totalVolume / 1000).toStringAsFixed(1)}k kg', icon: Icons.monitor_weight, color: theme.colorScheme.primary),
                        _StatCard(title: 'Time Spent', value: '${_totalDuration.inHours}h ${_totalDuration.inMinutes % 60}m', icon: Icons.timer, color: AppColors.warning),
                        _StatCard(title: 'Fav Muscle', value: _mostTrainedMuscle, icon: Icons.accessibility_new, color: AppColors.success),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Favorite Exercise
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text('Favorite Exercise', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
                            const SizedBox(height: 8),
                            Text(_favoriteExercise, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.accent), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          ),
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

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}
