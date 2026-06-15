import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'package:drift/drift.dart' as drift;

class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  final int workoutId;

  const WorkoutSummaryScreen({super.key, required this.workoutId});

  @override
  ConsumerState<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  bool _isLoading = true;
  Workout? _workout;
  List<WorkoutSet> _sets = [];
  final Map<int, List<WorkoutSet>> _previousSetsMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    _workout = await (db.select(db.workouts)..where((w) => w.id.equals(widget.workoutId))).getSingle();
    _sets = await db.getSetsForWorkout(widget.workoutId);
    
    // Group sets by exercise
    final exerciseIds = _sets.map((s) => s.exerciseId).toSet();
    for (final exId in exerciseIds) {
      _previousSetsMap[exId] = await _getSetsForExerciseBeforeWorkout(db, exId, widget.workoutId);
    }

    setState(() => _isLoading = false);
  }

  Future<List<WorkoutSet>> _getSetsForExerciseBeforeWorkout(AppDatabase db, int exerciseId, int currentWorkoutId) async {
    final currentWorkout = await (db.select(db.workouts)..where((w) => w.id.equals(currentWorkoutId))).getSingle();
    
    final query = db.select(db.workoutSets).join([
      drift.innerJoin(db.workouts, db.workouts.id.equalsExp(db.workoutSets.workoutId)),
    ])
      ..where(db.workoutSets.exerciseId.equals(exerciseId))
      ..where(db.workoutSets.isCompleted.equals(true))
      ..where(db.workouts.startTime.isSmallerThanValue(currentWorkout.startTime))
      ..orderBy([drift.OrderingTerm.desc(db.workouts.startTime)]);
      
    final results = await query.get();
    if (results.isEmpty) return [];
    
    final mostRecentWorkoutId = results.first.readTable(db.workouts).id;
    return results
        .where((row) => row.readTable(db.workouts).id == mostRecentWorkoutId)
        .map((r) => r.readTable(db.workoutSets))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final completedSets = _sets.where((s) => s.isCompleted).toList();
    final totalVolume = completedSets.where((s) => s.weight != null && s.reps != null).fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));
    final duration = _workout!.endTime != null ? _workout!.endTime!.difference(_workout!.startTime) : Duration.zero;

    final theme = Theme.of(context);

    // Group current sets
    final exerciseGroups = <int, List<WorkoutSet>>{};
    for (final s in completedSets) {
      exerciseGroups.putIfAbsent(s.exerciseId, () => []).add(s);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Summary'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Stats
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('🏆 Workout Complete!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Duration', '${duration.inMinutes}m'),
                      _buildStatColumn('Volume', '${totalVolume.toStringAsFixed(0)} kg'),
                      _buildStatColumn('Sets', '${completedSets.length}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('Intelligent Insights', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            ...exerciseGroups.entries.map((entry) {
              final exId = entry.key;
              final currentExSets = entry.value;
              final prevExSets = _previousSetsMap[exId] ?? [];
              
              final exerciseName = currentExSets.first.exerciseName;
              return _buildInsightCard(exerciseName, currentExSets, prevExSets, theme);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.accent)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildInsightCard(String name, List<WorkoutSet> current, List<WorkoutSet> previous, ThemeData theme) {
    if (previous.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(Icons.fiber_new, color: AppColors.accent),
          title: Text(name),
          subtitle: const Text('New baseline established!'),
        ),
      );
    }

    // Compare Volume
    final currentVol = current.where((s) => s.weight != null && s.reps != null).fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));
    final prevVol = previous.where((s) => s.weight != null && s.reps != null).fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));

    if (currentVol == 0 && prevVol == 0) {
      // Must be cardio or reps only
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.grey),
          title: Text(name),
          subtitle: const Text('Workout logged.'),
        ),
      );
    }

    final diff = currentVol - prevVol;
    final pct = (diff / prevVol) * 100;

    IconData icon;
    Color color;
    String text;

    if (diff > 0) {
      icon = Icons.trending_up;
      color = AppColors.success;
      text = 'Progressive Overload! (+${pct.toStringAsFixed(1)}% volume vs last time)';
    } else if (diff < 0) {
      icon = Icons.trending_down;
      color = AppColors.error;
      text = 'Underperformed (-${pct.abs().toStringAsFixed(1)}% volume vs last time)';
    } else {
      icon = Icons.compare_arrows;
      color = AppColors.warning;
      text = 'Matched previous performance.';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(text, style: TextStyle(color: color)),
      ),
    );
  }
}
