// lib/features/workout/presentation/active_workout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../exercises/presentation/widgets/exercise_picker_modal.dart';
import '../../../core/utils/pr_detector.dart';
import 'widgets/plate_calculator_modal.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  final int? workoutId;

  const ActiveWorkoutScreen({super.key, this.workoutId});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  late int _workoutId;
  bool _isLoading = true;
  final DateTime _startTime = DateTime.now();

  // Controllers
  final Map<int, TextEditingController> _weightControllers = {};
  final Map<int, TextEditingController> _repsControllers = {};

  // Rest Timer State
  int? _activeRestSetId;
  int _restSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _initWorkout();
  }

  @override
  void dispose() {
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

                // Group by supersetId or exerciseId
                final groups = <String, List<WorkoutSet>>{};
                for (final set in sets) {
                  final key = set.supersetId ?? set.exerciseId.toString();
                  groups.putIfAbsent(key, () => []).add(set);
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

                    // Exercise/Superset Cards
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final key = groups.keys.elementAt(index);
                          final groupSets = groups[key]!;
                          final isSuperset = groupSets.first.supersetId != null;

                          return isSuperset
                              ? _buildSupersetCard(context, groupSets)
                              : _buildExerciseCard(context, groupSets.first.exerciseName, groupSets);
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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteExercise(sets);
                    } else if (value == 'superset') {
                      _createSupersetFromCard(sets.first);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'superset',
                      child: Text('Create Superset'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Remove Exercise', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => _addSet(sets.first),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _buildSetsTable(context, sets),
          ],
        ),
      ),
    );
  }

  Widget _buildSupersetCard(BuildContext context, List<WorkoutSet> sets) {
    final theme = Theme.of(context);
    final exercises = sets.map((s) => s.exerciseName).toSet().toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.warning.withOpacity(0.5), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SUPERSET',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteExercise(sets);
                    } else if (value == 'add_exercise') {
                      _addExerciseToSuperset(sets.first.supersetId!);
                    } else if (value == 'unlink') {
                      _unlinkSuperset(sets);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'add_exercise',
                      child: Text('Add Exercise'),
                    ),
                    const PopupMenuItem(
                      value: 'unlink',
                      child: Text('Unlink Superset'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Remove All', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...exercises.map((exName) {
              final exSets = sets.where((s) => s.exerciseName == exName).toList();
              final letter = String.fromCharCode(65 + exercises.indexOf(exName)); // A, B, C...
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(letter, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(exName, style: theme.textTheme.titleSmall)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () => _addSet(exSets.first),
                      ),
                    ],
                  ),
                  _buildSetsTable(context, exSets),
                  const SizedBox(height: 16),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSetsTable(BuildContext context, List<WorkoutSet> sets) {
    final theme = Theme.of(context);
    return Column(
      children: [
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
    );
  }

  Widget _buildSetRow(BuildContext context, WorkoutSet set, int setNumber) {
    final theme = Theme.of(context);
    
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
    
    bool isPR = false;
    
    if (newCompleted && set.weight != null && set.reps != null) {
      final previousSets = await db.getSetsForExercise(set.exerciseId);
      final setWithCompletion = set.copyWith(
        isCompleted: true,
        completedAt: Value(DateTime.now()),
      );
      final prs = await PRDetector.detectPRs(setWithCompletion, previousSets);
      if (prs.isNotEmpty) {
        isPR = true;
      }
    }
    
    await db.update(db.workoutSets).replace(
      set.copyWith(
        isCompleted: newCompleted,
        completedAt: Value(newCompleted ? DateTime.now() : null),
        isPersonalRecord: isPR,
      ),
    );

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

  Future<void> _createSupersetFromCard(WorkoutSet sourceSet) async {
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ExercisePickerModal(),
    );

    if (exercise != null) {
      final db = ref.read(databaseProvider);
      final supersetId = const Uuid().v4();

      // Update existing sets of this exercise to use the supersetId
      await (db.update(db.workoutSets)
            ..where((s) => s.workoutId.equals(_workoutId) & s.exerciseId.equals(sourceSet.exerciseId)))
          .write(WorkoutSetsCompanion(supersetId: Value(supersetId)));

      // Add the new exercise to the superset
      await db.insertWorkoutSet(
        WorkoutSetsCompanion.insert(
          uuid: const Uuid().v4(),
          workoutId: _workoutId,
          exerciseId: exercise.id,
          exerciseName: exercise.name,
          setOrder: 0,
          setType: const Value('normal'),
          supersetId: Value(supersetId),
        ),
      );
    }
  }

  Future<void> _addExerciseToSuperset(String supersetId) async {
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
          supersetId: Value(supersetId),
        ),
      );
    }
  }

  Future<void> _unlinkSuperset(List<WorkoutSet> sets) async {
    final db = ref.read(databaseProvider);
    for (final set in sets) {
      await (db.update(db.workoutSets)..where((s) => s.id.equals(set.id)))
          .write(const WorkoutSetsCompanion(supersetId: Value(null)));
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
        supersetId: Value(templateSet.supersetId),
      ),
    );
  }

  Future<String> _getPreviousPerformance(int exerciseId, int setOrder) async {
    try {
      final db = ref.read(databaseProvider);
      final prevSet = await db.getPreviousSetPerformance(exerciseId, setOrder);
      if (prevSet != null && prevSet.workoutId != _workoutId) {
        return '${prevSet.weight!.toStringAsFixed(0)}kg × ${prevSet.reps}';
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
        title: const Text('Remove'),
        content: Text('Remove these sets?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      for (final set in sets) {
        _weightControllers[set.id]?.dispose();
        _repsControllers[set.id]?.dispose();
        _weightControllers.remove(set.id);
        _repsControllers.remove(set.id);
        
        await db.deleteWorkoutSet(set.id);
      }
    }
  }

  Future<void> _finishWorkout(BuildContext context) async {
    final db = ref.read(databaseProvider);
    final sets = await db.getSetsForWorkout(_workoutId);
    final completedSets = sets.where((s) => s.isCompleted).length;
    final totalVolume = sets
        .where((s) => s.isCompleted && s.weight != null && s.reps != null)
        .fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));
    
    final notesController = TextEditingController();
    int selectedIntensity = 3; 

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
      await (db.update(db.workouts)..where((w) => w.id.equals(_workoutId))).write(
        WorkoutsCompanion(
          endTime: Value(DateTime.now()),
          notes: Value(result['notes'].isEmpty ? null : result['notes']),
          intensityRating: Value(result['intensity']),
        ),
      );
      
      if (mounted) {
        // Fix for "stays on the same page" - just pop using the current valid context!
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Workout completed! 💪 $completedSets sets, ${totalVolume.toStringAsFixed(0)}kg volume'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
