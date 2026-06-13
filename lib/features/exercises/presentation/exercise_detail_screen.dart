// lib/features/exercises/presentation/exercise_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Summary'),
              Tab(text: 'History'),
              Tab(text: 'How to'),
            ],
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          children: [
            _SummaryTab(exercise: exercise),
            _HistoryTab(exercise: exercise),
            _HowToTab(exercise: exercise),
          ],
        ),
      ),
    );
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

class _SummaryTab extends ConsumerStatefulWidget {
  final Exercise exercise;

  const _SummaryTab({required this.exercise});

  @override
  ConsumerState<_SummaryTab> createState() => _SummaryTabState();
}

enum ChartType { maxWeight, volume, est1RM }

class _SummaryTabState extends ConsumerState<_SummaryTab> {
  ChartType _selectedChart = ChartType.maxWeight;

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final theme = Theme.of(context);
    final weightUnit = ref.watch(weightUnitProvider);
    final muscleGroup = MuscleGroup.fromString(exercise.primaryMuscle);
    final equipment = EquipmentType.fromString(exercise.equipment);
    final muscleColor = AppColors.muscleColors[exercise.primaryMuscle] ?? AppColors.accent;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Info
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: muscleColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.fitness_center, color: muscleColor, size: 36),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          muscleGroup.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          equipment.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // PRs & Charts
          _buildProgressAndPRs(context, ref, theme, weightUnit),
        ],
      ),
    );
  }

  Widget _buildProgressAndPRs(BuildContext context, WidgetRef ref, ThemeData theme, String weightUnit) {
    final exercise = widget.exercise;
    final historyAsync = ref.watch(exerciseHistoryGroupedProvider(exercise.id));
    
    return historyAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No data to show yet.\nComplete this exercise to see your progress and PRs.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          );
        }

        // Flatten all sets to compute PRs
        final allSets = groups.expand((g) => g.sets).toList();
        final prs = PRDetector.getExercisePRs(allSets);

        // Chart Data Extraction
        final maxWeightData = _getMaxWeightData(allSets, weightUnit);
        final volumeData = _getVolumeData(allSets);
        final rmData = _get1RMData(allSets, weightUnit);
        
        List<ChartDataPoint> activeData = [];
        String chartTitle = '';
        Color chartColor = AppColors.accent;

        switch (_selectedChart) {
          case ChartType.maxWeight:
            activeData = maxWeightData;
            chartTitle = 'MAX WEIGHT OVER TIME';
            chartColor = AppColors.error;
            break;
          case ChartType.volume:
            activeData = volumeData;
            chartTitle = 'VOLUME PER SESSION';
            chartColor = AppColors.warning;
            break;
          case ChartType.est1RM:
            activeData = rmData;
            chartTitle = 'ESTIMATED 1RM';
            chartColor = AppColors.success;
            break;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personal Records
            if (prs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text('PERSONAL RECORDS', style: theme.textTheme.labelSmall),
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

            // Progress Charts
            if (activeData.length >= 2) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ChartType>(
                  segments: const [
                    ButtonSegment(value: ChartType.maxWeight, label: Text('Max Weight')),
                    ButtonSegment(value: ChartType.volume, label: Text('Volume')),
                    ButtonSegment(value: ChartType.est1RM, label: Text('1RM')),
                  ],
                  selected: {_selectedChart},
                  onSelectionChanged: (Set<ChartType> newSelection) {
                    setState(() {
                      _selectedChart = newSelection.first;
                    });
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(chartTitle, style: theme.textTheme.labelSmall),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 0.5,
                  ),
                ),
                child: SmoothLineChart(data: activeData, height: 200, color: chartColor),
              ),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  List<ChartDataPoint> _getMaxWeightData(List<WorkoutSet> sets, String unit) {
    final Map<DateTime, double> dailyMax = {};
    for (final set in sets) {
      if (set.weight == null) continue;
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
      if (set.weight == null || set.reps == null) continue;
      final date = set.completedAt ?? DateTime.now();
      final dateKey = DateTime(date.year, date.month, date.day);
      dailyVolume[dateKey] = (dailyVolume[dateKey] ?? 0) + (set.weight! * set.reps!);
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
      if (set.weight == null || set.reps == null) continue;
      final est1RM = OneRmCalculator.epley(set.weight!, set.reps!);
      if (est1RM == null) continue;
      final date = set.completedAt ?? DateTime.now();
      final dateKey = DateTime(date.year, date.month, date.day);
      if (!daily1RM.containsKey(dateKey) || est1RM > daily1RM[dateKey]!) {
        daily1RM[dateKey] = est1RM;
      }
    }
    final sorted = daily1RM.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => ChartDataPoint(
      label: DateFormatter.shortDate(e.key),
      value: unit == 'lbs' ? WeightConverter.toLbs(e.value) : e.value,
    )).toList();
  }
}

class _HistoryTab extends ConsumerWidget {
  final Exercise exercise;

  const _HistoryTab({required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final weightUnit = ref.watch(weightUnitProvider);
    final historyAsync = ref.watch(exerciseHistoryGroupedProvider(exercise.id));

    return historyAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return Center(
            child: Text(
              'No history yet',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 100, top: 16),
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final group = groups[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Workout Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          group.workout.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          DateFormatter.shortDate(group.workout.startTime),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                  // Sets List
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: group.sets.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final set = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${idx + 1}',
                                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              if (set.weight != null && set.reps != null)
                                Text(
                                  '${WeightConverter.display(set.weight!, weightUnit)} × ${set.reps}',
                                  style: theme.textTheme.bodyLarge,
                                )
                              else if (set.durationSeconds != null)
                                Text(
                                  '${set.durationSeconds}s',
                                  style: theme.textTheme.bodyLarge,
                                )
                              else
                                Text('-', style: theme.textTheme.bodyLarge),
                              const Spacer(),
                              Icon(
                                set.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                                color: set.isCompleted ? AppColors.success : theme.colorScheme.outline,
                                size: 20,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _HowToTab extends StatelessWidget {
  final Exercise exercise;

  const _HowToTab({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Instructions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(
            'Detailed instructional videos and step-by-step guides will be available here soon.\n\nMake sure to maintain proper form and consult a professional if you are unsure.',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5, color: theme.colorScheme.onSurface.withOpacity(0.8)),
          ),
          if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text('Personal Notes', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              child: Text(
                exercise.notes!,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PRStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PRStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
