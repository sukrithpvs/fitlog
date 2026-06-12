// lib/features/exercises/presentation/widgets/create_exercise_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../../../core/constants/equipment_types.dart';
import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/database/app_database.dart';
import '../../providers/exercise_providers.dart';

class CreateExerciseSheet extends ConsumerStatefulWidget {
  final Exercise? exercise;

  const CreateExerciseSheet({super.key, this.exercise});

  @override
  ConsumerState<CreateExerciseSheet> createState() => _CreateExerciseSheetState();
}

class _CreateExerciseSheetState extends ConsumerState<CreateExerciseSheet> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late MuscleGroup _selectedMuscle;
  late EquipmentType _selectedEquipment;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exercise?.name);
    _notesController = TextEditingController(text: widget.exercise?.notes);
    _selectedMuscle = widget.exercise != null
        ? MuscleGroup.fromString(widget.exercise!.primaryMuscle)
        : MuscleGroup.chest;
    _selectedEquipment = widget.exercise != null
        ? EquipmentType.fromString(widget.exercise!.equipment)
        : EquipmentType.barbell;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.exercise != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEdit ? 'Edit Exercise' : 'Create Exercise',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),

              // Name
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Exercise Name',
                  hintText: 'e.g., Bench Press',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),

              // Muscle Group
              Text(
                'Primary Muscle',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MuscleGroup.values.map((muscle) {
                  final isSelected = _selectedMuscle == muscle;
                  return ChoiceChip(
                    label: Text(muscle.displayName.split(' ')[0]),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedMuscle = muscle);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Equipment
              Text(
                'Equipment',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: EquipmentType.values.map((equipment) {
                  final isSelected = _selectedEquipment == equipment;
                  return ChoiceChip(
                    label: Text(equipment.displayName),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedEquipment = equipment);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Notes
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Form tips, cues, etc.',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveExercise,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEdit ? 'Save Changes' : 'Create Exercise'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveExercise() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an exercise name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(exerciseRepositoryProvider);
      final notes = _notesController.text.trim();

      if (widget.exercise != null) {
        // Update existing - using Drift's generated copyWith
        final updated = widget.exercise!.copyWith(
          name: name,
          primaryMuscle: _selectedMuscle.name,
          equipment: _selectedEquipment.name,
          notes: Value(notes.isEmpty ? null : notes),
        );
        await repository.updateExercise(updated);
      } else {
        // Create new
        await repository.createExercise(
          name: name,
          primaryMuscle: _selectedMuscle.name,
          equipment: _selectedEquipment.name,
          notes: notes.isEmpty ? null : notes,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.exercise != null
                ? 'Exercise updated'
                : 'Exercise created'),
          ),
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
        setState(() => _isLoading = false);
      }
    }
  }
}
