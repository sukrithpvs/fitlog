// lib/features/workout/presentation/widgets/rpe_picker_modal.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class RpePickerModal extends StatelessWidget {
  const RpePickerModal({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: AppColors.accent),
                const SizedBox(width: 12),
                Text(
                  'Rate of Perceived Exertion',
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'How hard was this set?',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            // RPE Scale
            ...List.generate(11, (index) {
              final rpe = 10 - index;
              return InkWell(
                onTap: () => Navigator.pop(context, rpe),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getRpeColor(rpe).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _getRpeColor(rpe).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getRpeColor(rpe),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$rpe',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getRpeLabel(rpe),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: _getRpeColor(rpe),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getRpeDescription(rpe),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRpeColor(int rpe) {
    if (rpe >= 9) return const Color(0xFFEF4444); // Red
    if (rpe >= 7) return const Color(0xFFF59E0B); // Amber
    if (rpe >= 5) return const Color(0xFF3B82F6); // Blue
    return const Color(0xFF10B981); // Green
  }

  String _getRpeLabel(int rpe) {
    if (rpe == 10) return 'Maximum Effort';
    if (rpe == 9) return 'Extremely Hard';
    if (rpe == 8) return 'Very Hard';
    if (rpe == 7) return 'Hard';
    if (rpe == 6) return 'Moderate-Hard';
    if (rpe == 5) return 'Moderate';
    if (rpe == 4) return 'Light-Moderate';
    if (rpe == 3) return 'Light';
    if (rpe == 2) return 'Very Light';
    if (rpe == 1) return 'Extremely Light';
    return 'No Effort';
  }

  String _getRpeDescription(int rpe) {
    if (rpe == 10) return '0 reps left';
    if (rpe == 9) return '1 rep left';
    if (rpe == 8) return '2 reps left';
    if (rpe == 7) return '3 reps left';
    if (rpe >= 5) return '${11 - rpe} reps left';
    return 'Easy recovery';
  }
}
