// lib/features/exercises/presentation/widgets/exercise_card.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/equipment_types.dart';
import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muscleGroup = MuscleGroup.fromString(exercise.primaryMuscle);
    final equipment = EquipmentType.fromString(exercise.equipment);
    final muscleColor = AppColors.muscleColors[exercise.primaryMuscle] ?? AppColors.accent;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Muscle color indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: muscleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),

              // Exercise info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _getMuscleIcon(exercise.primaryMuscle),
                          size: 14,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          muscleGroup.displayName,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Equipment badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getEquipmentIcon(exercise.equipment),
                      size: 14,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      equipment.displayName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getMuscleIcon(String muscle) {
    switch (muscle) {
      case 'chest':
        return Icons.favorite;
      case 'back':
        return Icons.accessibility_new;
      case 'legs':
      case 'hamstrings':
        return Icons.directions_run;
      case 'shoulders':
        return Icons.fitness_center;
      case 'biceps':
      case 'triceps':
        return Icons.sports_martial_arts;
      case 'core':
        return Icons.center_focus_strong;
      case 'cardio':
        return Icons.favorite_border;
      default:
        return Icons.fitness_center;
    }
  }

  IconData _getEquipmentIcon(String equipment) {
    switch (equipment) {
      case 'barbell':
        return Icons.linear_scale;
      case 'dumbbell':
        return Icons.fitness_center;
      case 'cable':
        return Icons.cable;
      case 'machine':
        return Icons.precision_manufacturing;
      case 'bodyweight':
        return Icons.accessibility;
      default:
        return Icons.help_outline;
    }
  }
}
