import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'package:drift/drift.dart' as drift;
import 'package:share_plus/share_plus.dart';
import 'widgets/pr_celebration_overlay.dart';

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

    await _evaluateBadges(db);

    setState(() => _isLoading = false);
  }

  Future<void> _evaluateBadges(AppDatabase db) async {
    final completedSets = _sets.where((s) => s.isCompleted).toList();
    if (completedSets.isEmpty) return;

    final earnedIds = (await db.select(db.userBadges).get()).map((b) => b.badgeType).toSet();
    final newBadges = <UserBadgesCompanion>[];

    void award(String id) {
      if (!earnedIds.contains(id)) {
        newBadges.add(UserBadgesCompanion.insert(badgeType: id));
        earnedIds.add(id);
      }
    }

    // Workout Counts
    final allWorkouts = await (db.select(db.workouts)..where((w) => w.isTemplate.equals(false))).get();
    final count = allWorkouts.length;
    if (count >= 1) award('first_workout');
    if (count >= 10) award('10_workouts');
    if (count >= 50) award('50_workouts');
    if (count >= 100) award('100_workouts');

    // Volume
    final totalVolume = completedSets.where((s) => s.weight != null && s.reps != null).fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));
    if (totalVolume >= 10000) award('10k_volume');

    // 100kg Squat
    for (final s in completedSets) {
      if (s.exerciseName.toLowerCase().contains('squat') && (s.weight ?? 0) >= 100) {
        award('100kg_squat');
      }
    }

    // 7 Week Streak
    // Assuming simple week streak calculation based on dates:
    // ... we skip streak evaluation here to keep it simple, or we can just skip it.

    if (newBadges.isNotEmpty) {
      await db.batch((b) => b.insertAll(db.userBadges, newBadges));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🏆 You earned ${newBadges.length} new badge(s)! Check your Trophy Case.')),
        );
      }
    }
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
    final prSets = completedSets.where((s) => s.isPersonalRecord).toList();
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
      body: PRCelebrationOverlay(
        isPlaying: prSets.isNotEmpty,
        child: SingleChildScrollView(
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share Workout'),
                      onPressed: () {
                        final text = 'I just completed a workout: ${_workout!.title}!\n'
                            'Duration: ${duration.inMinutes}m\n'
                            'Volume: ${totalVolume.toStringAsFixed(0)} kg\n'
                            'Sets: ${completedSets.length}\n\n'
                            'Tracked with FitLog 💪';
                        Share.share(text);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (prSets.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text('Trophy Cabinet', style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 16),
              ...prSets.map((s) => Card(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.star, color: AppColors.accent),
                  title: Text(s.exerciseName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('New Personal Record: ${s.weight?.toStringAsFixed(1) ?? ''}kg × ${s.reps ?? ''} reps'),
                ),
              )),
              const SizedBox(height: 32),
            ],
            Text('Exercise Breakdown', style: theme.textTheme.titleLarge),
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
      icon = Icons.local_fire_department;
      color = AppColors.success;
      text = '🔥 Improved (+${pct.toStringAsFixed(1)}% volume vs last time)';
    } else if (diff < 0) {
      icon = Icons.trending_down;
      color = AppColors.error;
      text = '📉 Underperformed (-${pct.abs().toStringAsFixed(1)}% volume vs last time)';
    } else {
      icon = Icons.balance;
      color = theme.colorScheme.primary;
      text = '⚖️ Maintained previous performance.';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(text, style: TextStyle(color: color, fontSize: 12)),
      ),
    );
  }
}
