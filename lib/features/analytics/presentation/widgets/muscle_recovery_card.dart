import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../analytics_tab_screen.dart'; // To access muscleRecoveryProvider

class MuscleRecoveryCard extends ConsumerWidget {
  const MuscleRecoveryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recoveryAsync = ref.watch(muscleRecoveryProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.battery_charging_full, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Muscle Recovery',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          recoveryAsync.when(
            data: (recoveryData) {
              if (recoveryData.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text('Complete workouts to track recovery', style: theme.textTheme.bodySmall),
                  ),
                );
              }

              final sorted = recoveryData.entries.toList()
                ..sort((a, b) => a.value.compareTo(b.value));

              return Column(
                children: sorted.map((entry) {
                  final muscle = entry.key;
                  final percent = entry.value;
                  
                  Color color;
                  String status;
                  if (percent < 0.33) {
                    color = AppColors.error;
                    status = 'Exhausted';
                  } else if (percent < 0.66) {
                    color = AppColors.warning;
                    status = 'Recovering';
                  } else if (percent < 1.0) {
                    color = Colors.lightGreen;
                    status = 'Almost Ready';
                  } else {
                    color = AppColors.success;
                    status = 'Fully Recovered';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              muscle[0].toUpperCase() + muscle.substring(1),
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              status,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.1),
                            color: color,
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ],
      ),
    );
  }
}
