// lib/features/analytics/presentation/widgets/muscle_recovery_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../analytics_tab_screen.dart';

class MuscleRecoveryCard extends ConsumerWidget {
  const MuscleRecoveryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recoveryAsync = ref.watch(muscleRecoveryProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [AppColors.darkSurface, AppColors.darkBg]
            : [AppColors.lightSurface, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
          width: 1,
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
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.battery_charging_full, color: AppColors.error, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Muscle Recovery',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          recoveryAsync.when(
            data: (recoveryData) {
              if (recoveryData.isEmpty) {
                return const Center(child: Text('Not enough data'));
              }

              // Sort by least recovered first
              final sortedEntries = recoveryData.entries.toList()
                ..sort((a, b) => a.value.compareTo(b.value));

              return Column(
                children: sortedEntries.map((entry) {
                  final muscle = entry.key;
                  final percent = entry.value;
                  
                  Color color;
                  String status;
                  IconData statusIcon;
                  if (percent < 0.33) {
                    color = AppColors.error;
                    status = 'Exhausted';
                    statusIcon = Icons.warning_rounded;
                  } else if (percent < 0.66) {
                    color = AppColors.warning;
                    status = 'Recovering';
                    statusIcon = Icons.hourglass_bottom_rounded;
                  } else if (percent < 1.0) {
                    color = Colors.lightGreen;
                    status = 'Almost Ready';
                    statusIcon = Icons.battery_charging_full_rounded;
                  } else {
                    color = AppColors.success;
                    status = 'Fully Recovered';
                    statusIcon = Icons.check_circle_rounded;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              muscle[0].toUpperCase() + muscle.substring(1),
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Row(
                              children: [
                                Icon(statusIcon, color: color, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  status,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: percent),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeOutQuart,
                          builder: (context, val, _) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: val,
                                minHeight: 12,
                                backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation(color),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('Error: $err'),
          ),
        ],
      ),
    );
  }
}
