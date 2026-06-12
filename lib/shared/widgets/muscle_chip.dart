// lib/shared/widgets/muscle_chip.dart
// A colored chip for displaying muscle groups with their assigned color.

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class MuscleChip extends StatelessWidget {
  final String muscle;
  final bool isSelected;
  final VoidCallback? onTap;

  const MuscleChip({
    super.key,
    required this.muscle,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.muscleColors[muscle] ?? AppColors.accent;
    final displayName = _capitalize(muscle);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).colorScheme.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          displayName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
