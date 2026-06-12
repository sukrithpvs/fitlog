// lib/features/exercises/presentation/exercise_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/equipment_types.dart';
import '../../../core/constants/muscle_groups.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../core/utils/one_rm_calculator.dart';
import '../../../core/utils/pr_detector.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/widgets/custom_charts.dart';
import '../providers/exercise_providers.dart';
import 'widgets/create_exercise_sheet.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repository = ref.watch(exerciseRepositoryProvider);
    final weightUnit = ref.watch(weightUnitProvider);
    final muscleGroup = MuscleGroup.fromString(exercise.primaryMuscle);
    final equipment = EquipmentType.fromString(exercise.equipment);
    final muscleColor = AppColors.muscleColors[exercise.primaryMuscle] ?? AppColors.accent;

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        actions: [
          if (exercise.isCustom)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditExercise(context, exercise),
            ),
          if (exercise.isCustom)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context, ref, exercise),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: muscleColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.fitness_center,
                            color: muscleColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                muscleGroup.displayName,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                equipment.displayName,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (exercise.isCustom)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'CUSTOM',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.info,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Notes',
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        exercise.notes!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Personal Records
            FutureBuilder<List<WorkoutSet>>(
              future: repository.getExerciseHistory(exercise.id),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final prs = PRDetector.getExercisePRs(snapshot.data!);
                  if (prs.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            'PERSONAL RECORDS',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                if (prs.containsKey(PRType.maxWeight))
                                  _PRStat(
                                    label: 'Max Weight',
                                    value: WeightConverter.display(prs[PRType.maxWeight]!, weightUnit),
                                    color: AppColors.error,
                                  ),
                                if (prs.containsKey(PRType.maxVolume))
                                  _PRStat(
                                    label: 'Max Volume',
                                    value: '${prs[PRType.maxVolume]!.toStringAsFixed(0)} kg',
                                    color: AppColors.warning,
                                  ),
                                if (prs.containsKey(PRType.max1RM))
                                  _PRStat(
                                    label: 'Est. 1RM',
                                    value: WeightConverter.display(prs[PRType.max1RM]!, weightUnit),
                                    color: AppColors.success,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),

            // Progress Charts
            FutureBuilder<List<WorkoutSet>>(
              future: repository.getExerciseHistory(exercise.id),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.length >= 3) {
                  final sets = snapshot.data!;
                  final completed = sets.where((s) => s.isCompleted && s.weight != null && s.reps != null).toList();
                  
                  if (completed.length >= 3) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            'PROGRESS',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        
                        // Max Weight Over Time
                        _buildProgressChart(
                          context,
                          'Max Weight',
                          _getMaxWeightData(completed.reversed.take(10).toList(), weightUnit),
                        ),
                        const SizedBox(height: 16),
                        
                        // Volume Over Time
                        _buildProgressChart(
                          context,
                          'Volume Per Session',
                          _getVolumeData(completed.reversed.take(10).toList()),
                        ),
                        const SizedBox(height: 16),
                        
                        // 1RM Estimation
                        _buildProgressChart(
                          context,
                          'Estimated 1RM',
                          _get1RMData(completed.reversed.take(10).toList(), weightUnit),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),

            // History Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'HISTORY',
                style: theme.textTheme.labelSmall,
              ),
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<WorkoutSet>>(
              future: repository.getExerciseHistory(exercise.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No history yet',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Start a workout to log sets',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final sets = snapshot.data!;
                final allSets = sets.where((s) => s.weight != null && s.reps != null).toList();
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: allSets.length > 20 ? 20 : allSets.length,
                  itemBuilder: (context, index) {
                    final set = allSets[index];
                    final isPR = PRDetector.isPR(set, allSets, PRType.maxWeight) ||
                                 PRDetector.isPR(set, allSets, PRType.maxVolume) ||
                                 PRDetector.isPR(set, allSets, PRType.max1RM);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      color: isPR ? AppColors.accent.withValues(alpha: 0.1) : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPR 
                              ? AppColors.accent.withValues(alpha: 0.3)
                              : muscleColor.withValues(alpha: 0.2),
                          child: isPR
                              ? const Icon(Icons.emoji_events, color: AppColors.accent, size: 18)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: muscleColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              '${WeightConverter.display(set.weight!, weightUnit)} × ${set.reps}',
                              style: theme.textTheme.titleMedium,
                            ),
                            if (set.rpe != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getRpeColor(set.rpe!).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'RPE ${set.rpe}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: _getRpeColor(set.rpe!),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (isPR) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'PR',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: set.completedAt != null
                            ? Text(
                                DateFormatter.relative(set.completedAt!),
                                style: theme.textTheme.bodySmall,
                              )
                            : null,
                        trailing: Icon(
                          set.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: set.isCompleted ? AppColors.success : theme.colorScheme.outline,
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressChart(BuildContext context, String title, List<ChartDataPoint> data) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: VolumeLineChart(data: data, height: 180),
            ),
          ],
        ),
      ),
    );
  }

  List<ChartDataPoint> _getMaxWeightData(List<WorkoutSet> sets, String unit) {
    final Map<DateTime, double> dailyMax = {};
    
    for (final set in sets) {
      final date = set.completedAt ?? DateTime.now();
      final dateKey = DateTime(date.year, date.month, date.day);
      
      if (!dailyMax.containsKey(dateKey) || set.weight! > dailyMax[dateKey]!) {
        dailyMax[dateKey] = set.weight!;
      }
    }
    
    final sorted = dailyMax.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    
    return sorted.map((e) => ChartDataPoint(
      label: DateFormatter.shortDate(e.key),
      value: unit == 'lbs' ? WeightConverter.toLbs(e.value) : e.value,
    )).toList();
  }

  List<ChartDataPoint> _getVolumeData(List<WorkoutSet> sets) {
    final Map<DateTime, double> dailyVolume = {};
    
    for (final set in sets) {
      final date = set.completedAt ?? DateTime.now();
      final dateKey = DateTime(date.year, date.month, date.day);
      final volume = set.weight! * set.reps!;
      
      dailyVolume[dateKey] = (dailyVolume[dateKey] ?? 0) + volume;
    }
    
    final sorted = dailyVolume.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    
    return sorted.map((e) => ChartDataPoint(
      label: DateFormatter.shortDate(e.key),
      value: e.value,
    )).toList();
  }

  List<ChartDataPoint> _get1RMData(List<WorkoutSet> sets, String unit) {
    final Map<DateTime, double> daily1RM = {};
    
    for (final set in sets) {
      final date = set.completedAt ?? DateTime.now();
      final dateKey = DateTime(date.year, date.month, date.day);
      final oneRM = OneRmCalculator.epley(set.weight, set.reps);
      
      if (oneRM != null) {
        if (!daily1RM.containsKey(dateKey) || oneRM > daily1RM[dateKey]!) {
          daily1RM[dateKey] = oneRM;
        }
      }
    }
    
    final sorted = daily1RM.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    
    return sorted.map((e) => ChartDataPoint(
      label: DateFormatter.shortDate(e.key),
      value: unit == 'lbs' ? WeightConverter.toLbs(e.value) : e.value,
    )).toList();
  }

  Color _getRpeColor(int rpe) {
    if (rpe <= 6) return AppColors.success;
    if (rpe <= 8) return AppColors.warning;
    return AppColors.error;
  }

  void _showEditExercise(BuildContext context, Exercise exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreateExerciseSheet(exercise: exercise),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Exercise exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text('Are you sure you want to delete "${exercise.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(exerciseRepositoryProvider).deleteExercise(exercise.id);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close detail screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exercise deleted')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _PRStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PRStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

