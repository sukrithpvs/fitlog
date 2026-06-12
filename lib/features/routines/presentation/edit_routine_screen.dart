// lib/features/routines/presentation/edit_routine_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../exercises/presentation/widgets/exercise_picker_modal.dart';
import '../providers/routine_providers.dart';

class EditRoutineScreen extends ConsumerStatefulWidget {
  final Workout routine;
  
  const EditRoutineScreen({super.key, required this.routine});

  @override
  ConsumerState<EditRoutineScreen> createState() => _EditRoutineScreenState();
}

class _EditRoutineScreenState extends ConsumerState<EditRoutineScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  List<Exercise> _selectedExercises = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.routine.title);
    _notesController = TextEditingController(text: widget.routine.notes ?? '');
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final db = ref.read(databaseProvider);
    final sets = await db.getSetsForWorkout(widget.routine.id);
    
    // Get unique exercises in order
    final exerciseIds = <int>[];
    for (final set in sets) {
      if (!exerciseIds.contains(set.exerciseId)) {
        exerciseIds.add(set.exerciseId);
      }
    }
    
    final exercises = <Exercise>[];
    for (final id in exerciseIds) {
      try {
        final exercise = await db.getExerciseById(id);
        exercises.add(exercise);
      } catch (_) {}
    }
    
    setState(() {
      _selectedExercises = exercises;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Routine')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Routine'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Routine Name',
                      hintText: 'e.g., Push Day',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Description or notes',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  
                  // Exercises Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EXERCISES (${_selectedExercises.length})',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addExercise,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Exercise'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  if (_selectedExercises.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.fitness_center_outlined,
                              size: 48,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No exercises added',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Add Exercise" to get started',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedExercises.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = _selectedExercises.removeAt(oldIndex);
                          _selectedExercises.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final exercise = _selectedExercises[index];
                        return Card(
                          key: ValueKey(exercise.id),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              Icons.drag_handle,
                              color: theme.colorScheme.outline,
                            ),
                            title: Text(exercise.name),
                            subtitle: Text(exercise.primaryMuscle),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                setState(() {
                                  _selectedExercises.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          
          // Save Button (fixed at bottom)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveRoutine,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExercise() async {
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ExercisePickerModal(),
    );

    if (exercise != null && !_selectedExercises.contains(exercise)) {
      setState(() {
        _selectedExercises.add(exercise);
      });
    }
  }

  Future<void> _saveRoutine() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a routine name')),
      );
      return;
    }

    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final notes = _notesController.text.trim();
      final uuid = const Uuid();
      
      // Update workout template
      await db.updateWorkout(
        WorkoutsCompanion(
          id: Value(widget.routine.id),
          uuid: Value(widget.routine.uuid),
          title: Value(title),
          startTime: Value(widget.routine.startTime),
          isTemplate: const Value(true),
          notes: Value(notes.isEmpty ? null : notes),
        ),
      );

      // Delete all existing sets
      await db.deleteSetsForWorkout(widget.routine.id);

      // Add new exercises as template sets (3 sets each)
      for (int exerciseIndex = 0; exerciseIndex < _selectedExercises.length; exerciseIndex++) {
        final exercise = _selectedExercises[exerciseIndex];
        for (int setNum = 0; setNum < 3; setNum++) {
          await db.insertWorkoutSet(
            WorkoutSetsCompanion.insert(
              uuid: uuid.v4(),
              workoutId: widget.routine.id,
              exerciseId: exercise.id,
              exerciseName: exercise.name,
              setOrder: (exerciseIndex * 3) + setNum,
            ),
          );
        }
      }

      // Invalidate provider to refresh list
      ref.invalidate(routineRepositoryProvider);
      ref.invalidate(routineSetsProvider(widget.routine.id));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Routine updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
