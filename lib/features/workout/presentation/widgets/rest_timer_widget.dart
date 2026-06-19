// lib/features/workout/presentation/widgets/rest_timer_widget.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';

class RestTimerWidget extends StatelessWidget {
  final int secondsRemaining;
  final VoidCallback onAdd30s;
  final VoidCallback onSubtract30s;
  final VoidCallback onSkip;

  const RestTimerWidget({
    Key? key,
    required this.secondsRemaining,
    required this.onAdd30s,
    required this.onSubtract30s,
    required this.onSkip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                'Rest: ${DateFormatter.timerSeconds(secondsRemaining)}',
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
                onPressed: onSubtract30s,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                onPressed: onAdd30s,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onSkip,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
