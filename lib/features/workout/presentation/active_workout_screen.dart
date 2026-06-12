// lib/features/workout/presentation/active_workout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../exercises/presentation/widgets/exercise_picker_modal.dart';
import 'widgets/plate_calculator_modal.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  final int? workoutId;

  const ActiveWorkoutScreen({super.key, this.workoutId});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  late int _workoutId;
  final _startTime = DateTime.now();
  bool _isLoading = true;
  int? _activeRestSetId;
  int _restSecondsRemaining = 0;
  
  // Keep text controllers alive to prevent focus loss
  final Map<int, TextEditingController> _weightControllers = {};
  final Map<int, TextEditingController> _repsControllers = {};

  @override
  void initState() {
    super.initState();
    _initWorkout();
  }

  @override
  void dispose() {
    // Clean up controllers
    for (final controller in _weightControllers.values) {
      controller.dispose();
    }
    for (final controller in _repsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initWorkout() async {
    if (widget.workoutId != null) {
      _workoutId = widget.workoutId!;
    } else {
      final db = ref.read(databaseProvider);
      _workoutId = await db.insertWorkout(
        WorkoutsCompanion.insert(
          uuid: const Uuid().v4(),
          title: 'Quick Workout',
          startTime: _startTime,
          isTemplate: const Value(false),
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Active Workout'),
            Text(
              'Started ${DateFormatter.time(_startTime)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const PlateCalculatorModal(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => _finishWorkout(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExercisePicker(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
      ),
      body: Column(
        children: [
          // Rest Timer Banner
          if (_activeRestSetId != null && _restSecondsRemaining > 0)
            _buildRestTimerBanner(),

          // Exercise List
          Expanded(
            child: StreamBuilder<List<WorkoutSet>>(
              stream: ref.read(databaseProvider).watchSetsForWorkout(_workoutId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sets = snapshot.data!;

                if (sets.isEmpty) {
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
                          'No exercises yet',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add an exercise',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                // Group by exercise
                final exerciseGroups = <String, List<WorkoutSet>>{};
                for (final set in sets) {
                  exerciseGroups.putIfAbsent(set.exerciseName, () => []).add(set);
                }

                // Calculate total volume
                final totalVolume = sets
                    .where((s) => s.isCompleted && s.weight != null && s.reps != null)
                    .fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));

                return Column(
                  children: [
                    // Volume Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: theme.colorScheme.surface,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Volume',
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            '${totalVolume.toStringAsFixed(1)} kg',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Exercise Cards
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: exerciseGroups.length,
                        itemBuilder: (context, index) {
                          final exerciseName = exerciseGroups.keys.elementAt(index);
                          final exerciseSets = exerciseGroups[exerciseName]!;
                          return _buildExerciseCard(context, exerciseName, exerciseSets);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestTimerBanner() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColors.accent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Rest: ${DateFormatter.timerSeconds(_restSecondsRemaining)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                onPressed: () => setState(() {
                  if (_restSecondsRemaining > 30) _restSecondsRemaining -= 30;
                }),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                onPressed: () => setState(() => _restSecondsRemaining += 30),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() {
                  _activeRestSetId = null;
                  _restSecondsRemaining = 0;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, String exerciseName, List<WorkoutSet> sets) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exerciseName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => _addSet(sets.first),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                  onPressed: () => _deleteExercise(sets),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Headers
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text('SET', style: theme.textTheme.labelSmall),
                ),
                Expanded(
                  child: Text('PREVIOUS', style: theme.textTheme.labelSmall),
                ),
                Expanded(
                  child: Text('KG', style: theme.textTheme.labelSmall),
                ),
                Expanded(
                  child: Text('REPS', style: theme.textTheme.labelSmall),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 8),
            ...sets.map((set) => _buildSetRow(context, set, sets.indexOf(set) + 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildSetRow(BuildContext context, WorkoutSet set, int setNumber) {
    final theme = Theme.of(context);
    
    // Get or create persistent controllers for this set
    if (!_weightControllers.containsKey(set.id)) {
      _weightControllers[set.id] = TextEditingController(
        text: set.weight != null ? set.weight!.toStringAsFixed(1).replaceAll('.0', '') : '',
      );
    }
    if (!_repsControllers.containsKey(set.id)) {
      _repsControllers[set.id] = TextEditingController(
        text: set.reps?.toString() ?? '',
      );
    }
    
    final weightController = _weightControllers[set.id]!;
    final repsController = _repsControllers[set.id]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Set number with RPE indicator
          SizedBox(
            width: 40,
            child: GestureDetector(
              onLongPress: () => _showRpeDialog(set),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$setNumber',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (set.rpe != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _getRpeColor(set.rpe!),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<String>(
              future: _getPreviousPerformance(set.exerciseId, set.setOrder),
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? '—',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: TextField(
              controller: weightController,
              decoration: const InputDecoration(
                hintText: '0',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
              onChanged: (value) {
                if (value.isEmpty) {
                  _updateSet(set.id, weight: null);
                } else {
                  final weight = double.tryParse(value);
                  if (weight != null) {
                    _updateSet(set.id, weight: weight);
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: repsController,
              decoration: const InputDecoration(
                hintText: '0',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
              onChanged: (value) {
                if (value.isEmpty) {
                  _updateSet(set.id, reps: null);
                } else {
                  final reps = int.tryParse(value);
                  if (reps != null) {
                    _updateSet(set.id, reps: reps);
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              set.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: set.isCompleted ? AppColors.success : theme.colorScheme.outline,
            ),
            onPressed: () => _toggleSetComplete(set),
          ),
        ],
      ),
    );
  }

  Color _getRpeColor(int rpe) {
    if (rpe <= 6) return AppColors.success;
    if (rpe <= 8) return AppColors.warning;
    return AppColors.error;
  }

  Future<void> _showRpeDialog(WorkoutSet set) async {
    final selectedRpe = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate of Perceived Exertion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How hard was this set?'),
            const SizedBox(height: 16),
            ...List.generate(11, (index) {
              final rpe = index;
              return ListTile(
                leading: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getRpeColor(rpe),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text('RPE $rpe - ${_getRpeLabel(rpe)}'),
                selected: set.rpe == rpe,
                onTap: () => Navigator.pop(context, rpe),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (set.rpe != null)
            TextButton(
              onPressed: () async {
                final db = ref.read(databaseProvider);
                await db.update(db.workoutSets).replace(
                  set.copyWith(rpe: const Value.absent()),
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
        ],
      ),
    );

    if (selectedRpe != null) {
      final db = ref.read(databaseProvider);
      await db.update(db.workoutSets).replace(
        set.copyWith(rpe: Value(selectedRpe)),
      );
    }
  }

  String _getRpeLabel(int rpe) {
    switch (rpe) {
      case 0: return 'No effort';
      case 1: return 'Very light';
      case 2: return 'Light';
      case 3: return 'Moderate';
      case 4: return 'Somewhat hard';
      case 5: return 'Hard';
      case 6: return 'Very hard';
      case 7: return '3 reps left';
      case 8: return '2 reps left';
      case 9: return '1 rep left';
      case 10: return 'Maximum effort';
      default: return '';
    }
  }

  Future<void> _updateSet(int setId, {double? weight, int? reps}) async {
    final db = ref.read(databaseProvider);
    final currentSet = await (db.select(db.workoutSets)..where((s) => s.id.equals(setId))).getSingleOrNull();
    
    if (currentSet != null) {
      await db.update(db.workoutSets).replace(
        currentSet.copyWith(
          weight: weight != null ? Value(weight) : (currentSet.weight != null ? Value(currentSet.weight) : const Value.absent()),
          reps: reps != null ? Value(reps) : (currentSet.reps != null ? Value(currentSet.reps) : const Value.absent()),
        ),
      );
    }
  }

  Future<void> _toggleSetComplete(WorkoutSet set) async {
    final db = ref.read(databaseProvider);
    final newCompleted = !set.isCompleted;
    
    await db.update(db.workoutSets).replace(
      set.copyWith(
        isCompleted: newCompleted,
        completedAt: Value(newCompleted ? DateTime.now() : null),
      ),
    );

    // Start rest timer if set is completed
    if (newCompleted && set.weight != null && set.reps != null) {
      setState(() {
        _activeRestSetId = set.id;
        _restSecondsRemaining = 90;
      });
      _startRestTimer();
    }
  }

  void _startRestTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_restSecondsRemaining > 0 && mounted) {
        setState(() => _restSecondsRemaining--);
        _startRestTimer();
      } else if (_restSecondsRemaining == 0) {
        setState(() => _activeRestSetId = null);
        // TODO: Show notification
      }
    });
  }

  Future<void> _showExercisePicker(BuildContext context) async {
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ExercisePickerModal(),
    );

    if (exercise != null) {
      final db = ref.read(databaseProvider);
      await db.insertWorkoutSet(
        WorkoutSetsCompanion.insert(
          uuid: const Uuid().v4(),
          workoutId: _workoutId,
          exerciseId: exercise.id,
          exerciseName: exercise.name,
          setOrder: 0,
          setType: const Value('normal'),
        ),
      );
    }
  }

  Future<void> _addSet(WorkoutSet templateSet) async {
    final db = ref.read(databaseProvider);
    final sets = await db.getSetsForWorkout(_workoutId);
    final exerciseSets = sets.where((s) => s.exerciseName == templateSet.exerciseName).toList();
    final maxOrder = exerciseSets.isEmpty ? -1 : exerciseSets.map((s) => s.setOrder).reduce((a, b) => a > b ? a : b);

    await db.insertWorkoutSet(
      WorkoutSetsCompanion.insert(
        uuid: const Uuid().v4(),
        workoutId: _workoutId,
        exerciseId: templateSet.exerciseId,
        exerciseName: templateSet.exerciseName,
        setOrder: maxOrder + 1,
        weight: Value(templateSet.weight),
        reps: Value(templateSet.reps),
        setType: const Value('normal'),
      ),
    );
  }

  Future<String> _getPreviousPerformance(int exerciseId, int setOrder) async {
    try {
      final db = ref.read(databaseProvider);
      
      // Get all completed sets for this exercise from other workouts
      final allSets = await db.select(db.workoutSets).get();
      
      // Filter to get previous performance
      final previousSets = allSets.where((s) => 
        s.exerciseId == exerciseId &&
        s.workoutId != _workoutId &&
        s.isCompleted &&
        s.setOrder == setOrder &&
        s.weight != null &&
        s.reps != null
      ).toList();
      
      // Sort by completed date descending
      previousSets.sort((a, b) {
        if (a.completedAt == null) return 1;
        if (b.completedAt == null) return -1;
        return b.completedAt!.compareTo(a.completedAt!);
      });

      if (previousSets.isNotEmpty) {
        final prev = previousSets.first;
        return '${prev.weight!.toStringAsFixed(0)}kg × ${prev.reps}';
      }
    } catch (e) {
      // Ignore errors
    }
    return '—';
  }

  Future<void> _deleteExercise(List<WorkoutSet> sets) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text('Remove ${sets.first.exerciseName} and all its sets?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      for (final set in sets) {
        // Clean up controllers
        _weightControllers[set.id]?.dispose();
        _repsControllers[set.id]?.dispose();
        _weightControllers.remove(set.id);
        _repsControllers.remove(set.id);
        
        await db.deleteWorkoutSet(set.id);
      }
    }
  }

  Future<void> _finishWorkout(BuildContext context) async {
    // Store the screen-level navigator BEFORE showing the dialog
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    final db = ref.read(databaseProvider);
    final sets = await db.getSetsForWorkout(_workoutId);
    final completedSets = sets.where((s) => s.isCompleted).length;
    final totalVolume = sets
        .where((s) => s.isCompleted && s.weight != null && s.reps != null)
        .fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));
    
    final notesController = TextEditingController();
    int selectedIntensity = 3; // Default to 3 stars

    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Finish Workout'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Completed $completedSets sets'),
                Text('Total volume: ${totalVolume.toStringAsFixed(1)} kg'),
                const SizedBox(height: 20),
                const Text('How intense was this workout?', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    return IconButton(
                      icon: Icon(
                        star <= selectedIntensity ? Icons.star : Icons.star_border,
                        color: AppColors.warning,
                        size: 32,
                      ),
                      onPressed: () => setState(() => selectedIntensity = star),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'How did the workout feel?',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'notes': notesController.text,
                'intensity': selectedIntensity,
              }),
              child: const Text('Finish'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      // Use write() for partial update
      await (db.update(db.workouts)..where((w) => w.id.equals(_workoutId))).write(
        WorkoutsCompanion(
          endTime: Value(DateTime.now()),
          notes: Value(result['notes'].isEmpty ? null : result['notes']),
          intensityRating: Value(result['intensity']),
        ),
      );
      
      // Navigate back using the screen-level navigator
      if (mounted) {
        navigator.pop();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Workout completed! 💪 $completedSets sets, ${totalVolume.toStringAsFixed(0)}kg volume'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
