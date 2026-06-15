// lib/features/workout/presentation/active_workout_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../exercises/presentation/widgets/exercise_picker_modal.dart';
import 'widgets/plate_calculator_modal.dart';
import '../../../core/utils/pr_detector.dart';
import '../../../core/utils/notification_service.dart';
import 'workout_summary_screen.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  final int? workoutId;
  final String? routineName;
  final int? folderId;
  final bool isEditing;

  const ActiveWorkoutScreen({
    super.key,
    this.workoutId,
    this.routineName,
    this.folderId,
    this.isEditing = false,
  });

  @override
  ConsumerState<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  late int _workoutId;
  bool _isLoading = true;
  final DateTime _startTime = DateTime.now();
  String _workoutTitle = '';
  Timer? _durationTimer;

  // Controllers
  final Map<int, TextEditingController> _weightControllers = {};
  final Map<int, TextEditingController> _repsControllers = {};
  final Map<int, TextEditingController> _timeControllers = {};
  final Map<int, TextEditingController> _distanceControllers = {};
  final Map<int, String> _trackingTypeCache = {};

  // Rest Timer State
  int? _activeRestSetId;
  int _restSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _initWorkout();
    if (!widget.isEditing) {
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    if (!widget.isEditing) {
      _durationTimer?.cancel();
    }
    for (final controller in _weightControllers.values) {
      controller.dispose();
    }
    for (final controller in _repsControllers.values) {
      controller.dispose();
    }
    for (final controller in _timeControllers.values) {
      controller.dispose();
    }
    for (final controller in _distanceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initWorkout() async {
    final db = ref.read(databaseProvider);
    if (widget.workoutId != null) {
      _workoutId = widget.workoutId!;
      final workout = await (db.select(db.workouts)..where((w) => w.id.equals(_workoutId))).getSingle();
      _workoutTitle = workout.title;
    } else {
      _workoutId = await db.insertWorkout(
        WorkoutsCompanion.insert(
          uuid: const Uuid().v4(),
          title: widget.routineName ?? 'Quick Workout',
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
        title: Text(
          widget.isEditing ? 'Edit Workout' : 
          (_workoutTitle.isEmpty ? 'Active Workout' : _workoutTitle),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Plate Calculator',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const PlateCalculatorModal(targetWeight: 60.0),
              );
            },
          ),
          if (widget.isEditing)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else
            TextButton(
              onPressed: () => _finishWorkout(context),
              child: const Text('Finish', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
            ),
        ],
        bottom: widget.isEditing ? null : PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Duration: ${DateFormatter.duration(DateTime.now().difference(_startTime))}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ),
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
    
    final exerciseId = sets.first.exerciseId;
    if (!_trackingTypeCache.containsKey(exerciseId)) {
      _trackingTypeCache[exerciseId] = 'weight_reps'; // temporary default
      ref.read(databaseProvider).getExerciseById(exerciseId).then((ex) {
        if (mounted && _trackingTypeCache[exerciseId] != ex.trackingType) {
          setState(() => _trackingTypeCache[exerciseId] = ex.trackingType);
        }
      });
    }

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
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'superset',
                      child: Text('Create Superset'),
                    ),
                    const PopupMenuItem(
                      value: 'warmup',
                      child: Text('Generate Warm-ups'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Remove Exercise', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteExercise(sets);
                    } else if (value == 'superset') {
                      _createSupersetFromCard(sets.first);
                    } else if (value == 'warmup') {
                      _generateWarmupSets(sets);
                    }
                  },
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
    final trackingType = _trackingTypeCache[sets.first.exerciseId] ?? 'weight_reps';
    
    String col1 = 'KG';
    String col2 = 'REPS';
    
    if (trackingType == 'reps_only') {
      col1 = '-';
      col2 = 'REPS';
    } else if (trackingType == 'time_only') {
      col1 = '-';
      col2 = 'TIME';
    } else if (trackingType == 'distance_time') {
      col1 = 'KM';
      col2 = 'TIME';
    }

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 50,
              child: Text('SET', style: theme.textTheme.labelSmall),
            ),
            Expanded(
              child: Text('PREVIOUS', style: theme.textTheme.labelSmall),
            ),
            Expanded(
              child: Text(col1, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
            ),
            Expanded(
              child: Text(col2, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 8),
        ...sets.map((set) => _buildSetRow(context, set, sets.indexOf(set) + 1)),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.subdirectory_arrow_right, size: 18),
            label: const Text('Add Drop Set'),
            onPressed: () => _addSet(sets.last, isDropSet: true),
          ),
        ),
      ],
    );
  }

  Widget _buildSetRow(BuildContext context, WorkoutSet set, int setNumber) {
    final theme = Theme.of(context);
    final trackingType = _trackingTypeCache[set.exerciseId] ?? 'weight_reps';
    
    if (!_weightControllers.containsKey(set.id)) _weightControllers[set.id] = TextEditingController(text: set.weight?.toStringAsFixed(1).replaceAll('.0', '') ?? '');
    if (!_repsControllers.containsKey(set.id)) _repsControllers[set.id] = TextEditingController(text: set.reps?.toString() ?? '');
    if (!_timeControllers.containsKey(set.id)) {
      String timeStr = '';
      if (set.durationSeconds != null) {
        final m = set.durationSeconds! ~/ 60;
        final s = set.durationSeconds! % 60;
        timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      }
      _timeControllers[set.id] = TextEditingController(text: timeStr);
    }
    if (!_distanceControllers.containsKey(set.id)) _distanceControllers[set.id] = TextEditingController(text: set.distanceMeters != null ? (set.distanceMeters! / 1000).toStringAsFixed(2).replaceAll('.00', '') : '');
    
    Widget buildCol1() {
      if (trackingType == 'reps_only' || trackingType == 'time_only') return const Center(child: Text('-'));
      if (trackingType == 'distance_time') {
        return TextField(
          controller: _distanceControllers[set.id],
          decoration: const InputDecoration(hintText: '0.0', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: theme.textTheme.bodyMedium, textAlign: TextAlign.center,
          onChanged: (v) {
            final val = double.tryParse(v);
            _updateSet(set.id, distanceMeters: val != null ? val * 1000 : null);
          },
        );
      }
      return TextField(
        controller: _weightControllers[set.id],
        decoration: const InputDecoration(hintText: '0', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: theme.textTheme.bodyMedium, textAlign: TextAlign.center,
        onChanged: (v) => _updateSet(set.id, weight: double.tryParse(v)),
      );
    }

    Widget buildCol2() {
      if (trackingType == 'time_only' || trackingType == 'distance_time') {
        return TextField(
          controller: _timeControllers[set.id],
          decoration: const InputDecoration(hintText: '00:00', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
          keyboardType: TextInputType.datetime,
          style: theme.textTheme.bodyMedium, textAlign: TextAlign.center,
          onChanged: (v) {
            if (v.length == 5 && v.contains(':')) {
              final parts = v.split(':');
              if (parts.length == 2) {
                final m = int.tryParse(parts[0]) ?? 0;
                final s = int.tryParse(parts[1]) ?? 0;
                _updateSet(set.id, durationSeconds: (m * 60) + s);
              }
            } else if (v.isEmpty) {
              _updateSet(set.id, durationSeconds: null);
            }
          },
        );
      }
      return TextField(
        controller: _repsControllers[set.id],
        decoration: const InputDecoration(hintText: '0', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
        keyboardType: TextInputType.number,
        style: theme.textTheme.bodyMedium, textAlign: TextAlign.center,
        onChanged: (v) => _updateSet(set.id, reps: int.tryParse(v)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Set number / Set Type with RPE indicator
          SizedBox(
            width: 50,
            child: Row(
              children: [
                if (set.setType == 'drop')
                  Icon(Icons.subdirectory_arrow_right, size: 16, color: theme.colorScheme.outline)
                else
                  const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _cycleSetType(set),
                    onLongPress: () => _showRpeDialog(set),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        _buildSetTypeIndicator(set, setNumber),
                        if (set.rpe != null)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getRpeColor(set.rpe!),
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
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
          const SizedBox(width: 8),
          Expanded(child: buildCol1()),
          const SizedBox(width: 8),
          Expanded(child: buildCol2()),
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

  Widget _buildSetTypeIndicator(WorkoutSet set, int setNumber) {
    final theme = Theme.of(context);
    String label = '$setNumber';
    Color bgColor = Colors.transparent;
    Color textColor = theme.colorScheme.onSurface;

    if (set.setType == 'warmup') {
      label = 'W';
      bgColor = AppColors.warning.withOpacity(0.2);
      textColor = AppColors.warning;
    } else if (set.setType == 'drop') {
      label = 'D';
      bgColor = AppColors.accent.withOpacity(0.2);
      textColor = AppColors.accent;
    } else if (set.setType == 'failure') {
      label = 'F';
      bgColor = AppColors.error.withOpacity(0.2);
      textColor = AppColors.error;
    }

    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Future<void> _cycleSetType(WorkoutSet set) async {
    final types = ['normal', 'warmup', 'drop', 'failure'];
    final currentIndex = types.indexOf(set.setType);
    final nextIndex = (currentIndex + 1) % types.length;
    
    final db = ref.read(databaseProvider);
    await db.update(db.workoutSets).replace(
      set.copyWith(setType: types[nextIndex]),
    );
  }

  Future<void> _updateSet(int setId, {double? weight, int? reps, int? durationSeconds, double? distanceMeters}) async {
    final db = ref.read(databaseProvider);
    final currentSet = await (db.select(db.workoutSets)..where((s) => s.id.equals(setId))).getSingleOrNull();
    
    if (currentSet != null) {
      await db.update(db.workoutSets).replace(
        currentSet.copyWith(
          weight: weight != null ? Value(weight) : (currentSet.weight != null ? Value(currentSet.weight) : const Value.absent()),
          reps: reps != null ? Value(reps) : (currentSet.reps != null ? Value(currentSet.reps) : const Value.absent()),
          durationSeconds: durationSeconds != null ? Value(durationSeconds) : (currentSet.durationSeconds != null ? Value(currentSet.durationSeconds) : const Value.absent()),
          distanceMeters: distanceMeters != null ? Value(distanceMeters) : (currentSet.distanceMeters != null ? Value(currentSet.distanceMeters) : const Value.absent()),
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

    if (newCompleted && !widget.isEditing) {
      int suggestedRest = 90;
      try {
        final ex = await db.getExerciseById(set.exerciseId);
        final primaryMuscle = ex.primaryMuscle.toLowerCase();
        if (primaryMuscle == 'legs' || primaryMuscle == 'back' || primaryMuscle == 'chest') {
          suggestedRest = 120;
        } else if (primaryMuscle == 'core' || primaryMuscle == 'biceps' || primaryMuscle == 'triceps' || primaryMuscle == 'forearms') {
          suggestedRest = 60;
        } else if (primaryMuscle == 'cardio') {
          suggestedRest = 30;
        }
      } catch (_) {}

      setState(() {
        _activeRestSetId = set.id;
        _restSecondsRemaining = suggestedRest;
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
        if (mounted && _activeRestSetId != null) {
          setState(() => _activeRestSetId = null);
          NotificationService().showRestCompleteNotification();
        }
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
      await _checkRecovery(exercise);
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
      await _checkRecovery(exercise);
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
      await _checkRecovery(exercise);
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

  Future<void> _addSet(WorkoutSet templateSet, {bool isDropSet = false}) async {
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
        setType: Value(isDropSet ? 'drop' : 'normal'),
        supersetId: Value(templateSet.supersetId),
      ),
    );
  }

  Future<void> _checkRecovery(Exercise exercise) async {
    final db = ref.read(databaseProvider);
    final twoDaysAgo = DateTime.now().subtract(const Duration(hours: 48));
    
    // Check if there are completed sets for this primary muscle in the last 48 hours
    final recentSets = await (db.select(db.workoutSets).join([
      drift.innerJoin(db.workouts, db.workouts.id.equalsExp(db.workoutSets.workoutId)),
      drift.innerJoin(db.exercises, db.exercises.id.equalsExp(db.workoutSets.exerciseId)),
    ])
      ..where(db.workoutSets.isCompleted.equals(true))
      ..where(db.workouts.endTime.isBiggerOrEqualValue(twoDaysAgo))
      ..where(db.exercises.primaryMuscle.equals(exercise.primaryMuscle))
    ).get();

    if (recentSets.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text('⚠️ Your ${exercise.primaryMuscle} might still be recovering from a recent workout!')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _generateWarmupSets(List<WorkoutSet> sets) async {
    final firstWorkingSet = sets.firstWhere((s) => s.weight != null && s.weight! > 0, orElse: () => sets.first);
    final workingWeight = firstWorkingSet.weight ?? 0.0;
    
    if (workingWeight < 20) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Target weight too light for generated warmups.')));
      }
      return;
    }

    final db = ref.read(databaseProvider);
    final exerciseSets = await (db.select(db.workoutSets)
      ..where((s) => s.workoutId.equals(_workoutId) & s.exerciseId.equals(firstWorkingSet.exerciseId))
    ).get();
    final minOrder = exerciseSets.isEmpty ? 0 : exerciseSets.map((s) => s.setOrder).reduce((a, b) => a < b ? a : b);

    // Create 2 warmup sets: 50% for 10, 75% for 5
    await db.insertWorkoutSet(
      WorkoutSetsCompanion.insert(
        uuid: const Uuid().v4(),
        workoutId: _workoutId,
        exerciseId: firstWorkingSet.exerciseId,
        exerciseName: firstWorkingSet.exerciseName,
        setOrder: minOrder - 2,
        weight: Value(workingWeight * 0.5),
        reps: const Value(10),
        setType: const Value('warmup'),
      ),
    );
    await db.insertWorkoutSet(
      WorkoutSetsCompanion.insert(
        uuid: const Uuid().v4(),
        workoutId: _workoutId,
        exerciseId: firstWorkingSet.exerciseId,
        exerciseName: firstWorkingSet.exerciseName,
        setOrder: minOrder - 1,
        weight: Value(workingWeight * 0.75),
        reps: const Value(5),
        setType: const Value('warmup'),
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
        // Fix for "stays on the same page" - pop the active workout screen
        Navigator.pop(context);
        
        // Push the new intelligent summary screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkoutSummaryScreen(workoutId: _workoutId),
          ),
        );
      }
    }
  }
}
