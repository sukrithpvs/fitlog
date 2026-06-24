import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/muscle_groups.dart';

// Provides the current week's sets per muscle group
final weeklyProgressProvider = FutureProvider<Map<String, int>>((ref) async {
  final db = ref.watch(databaseProvider);
  
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
  
  final sets = await db.select(db.workoutSets).get();
  final recentSets = sets.where((s) => s.isCompleted && s.completedAt != null && s.completedAt!.isAfter(startOfDay)).toList();
  
  if (recentSets.isEmpty) return {};
  
  // Batch-fetch all exercises at once instead of querying per-set (N+1 fix)
  final exerciseIds = recentSets.map((s) => s.exerciseId).toSet();
  final exercises = await (db.select(db.exercises)..where((e) => e.id.isIn(exerciseIds))).get();
  final exerciseMap = {for (final e in exercises) e.id: e};
  
  Map<String, int> progress = {};
  
  for (final s in recentSets) {
    final exercise = exerciseMap[s.exerciseId];
    if (exercise != null) {
      final muscle = exercise.primaryMuscle;
      progress[muscle] = (progress[muscle] ?? 0) + 1;
    }
  }
  
  return progress;
});

// Provides the weekly targets set by user
final weeklyTargetsProvider = StreamProvider<List<WeeklyTarget>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.weeklyTargets).watch();
});

class WeeklyTargetsWidget extends ConsumerWidget {
  const WeeklyTargetsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetsAsync = ref.watch(weeklyTargetsProvider);
    final progressAsync = ref.watch(weeklyProgressProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Weekly Volume Targets', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Sets completed this week (Mon-Sun).', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            
            targetsAsync.when(
              data: (targets) {
                if (targets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton(
                        onPressed: () => _showEditDialog(context, ref),
                        child: const Text('Set Targets'),
                      ),
                    ),
                  );
                }
                
                return progressAsync.when(
                  data: (progress) {
                    return Column(
                      children: targets.map((t) {
                        final current = progress[t.muscleGroup] ?? 0;
                        final percent = (current / t.targetSets).clamp(0.0, 1.0);
                        final isComplete = current >= t.targetSets;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(t.muscleGroup, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('$current / ${t.targetSets} sets', 
                                    style: TextStyle(
                                      color: isComplete ? AppColors.success : Colors.grey,
                                      fontWeight: isComplete ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: percent,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                color: isComplete ? AppColors.success : AppColors.accent,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Text('Error: $e'),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _EditTargetsDialog(),
    );
  }
}

class _EditTargetsDialog extends ConsumerStatefulWidget {
  const _EditTargetsDialog();

  @override
  ConsumerState<_EditTargetsDialog> createState() => _EditTargetsDialogState();
}

class _EditTargetsDialogState extends ConsumerState<_EditTargetsDialog> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final db = ref.read(databaseProvider);
    final targets = await db.select(db.weeklyTargets).get();
    
    for (final muscle in MuscleGroup.values) {
      final name = muscle.displayName;
      final existing = targets.where((t) => t.muscleGroup == name).firstOrNull;
      _controllers[name] = TextEditingController(text: existing?.targetSets.toString() ?? '');
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    
    // Clear old targets
    await db.delete(db.weeklyTargets).go();
    
    // Insert new targets
    final toInsert = <WeeklyTargetsCompanion>[];
    for (final entry in _controllers.entries) {
      final val = int.tryParse(entry.value.text);
      if (val != null && val > 0) {
        toInsert.add(WeeklyTargetsCompanion.insert(
          muscleGroup: entry.key,
          targetSets: val,
        ));
      }
    }
    
    if (toInsert.isNotEmpty) {
      await db.batch((b) {
        b.insertAll(db.weeklyTargets, toInsert);
      });
    }
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Set Weekly Targets', style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: MuscleGroup.values.map((m) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(m.displayName)),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _controllers[m.displayName],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: '0',
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
