// lib/features/workout/presentation/widgets/plate_calculator_modal.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PlateCalculatorModal extends StatefulWidget {
  const PlateCalculatorModal({super.key});

  @override
  State<PlateCalculatorModal> createState() => _PlateCalculatorModalState();
}

class _PlateCalculatorModalState extends State<PlateCalculatorModal> {
  double _targetWeight = 100.0;
  final double _barWeight = 20.0; // Standard barbell
  final List<double> _availablePlates = [25, 20, 15, 10, 5, 2.5, 1.25];

  Map<double, int> _calculatePlates() {
    double remainingWeight = (_targetWeight - _barWeight) / 2; // Per side
    final Map<double, int> plates = {};

    for (final plate in _availablePlates) {
      if (remainingWeight >= plate) {
        final count = (remainingWeight / plate).floor();
        plates[plate] = count;
        remainingWeight -= count * plate;
      }
    }

    return plates;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plates = _calculatePlates();
    final actualWeight = _barWeight + (plates.entries.fold<double>(0, (sum, e) => sum + (e.key * e.value)) * 2);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate, color: AppColors.accent),
                const SizedBox(width: 12),
                Text(
                  'Plate Calculator',
                  style: theme.textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Weight Input
            Text('Target Weight', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() {
                    if (_targetWeight > 20) _targetWeight -= 2.5;
                  }),
                ),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _targetWeight.toStringAsFixed(1)),
                    decoration: InputDecoration(
                      suffix: Text('kg', style: theme.textTheme.bodySmall),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                    onChanged: (value) {
                      final weight = double.tryParse(value);
                      if (weight != null) setState(() => _targetWeight = weight);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _targetWeight += 2.5),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Plates Breakdown
            Text('Plates per side', style: theme.textTheme.labelMedium),
            const SizedBox(height: 12),

            if (plates.isEmpty)
              Center(
                child: Text(
                  'Weight too light for standard bar',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warning),
                ),
              )
            else
              ...plates.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getPlateColor(entry.key),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${entry.key}kg',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'x ${entry.value}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bar weight:', style: theme.textTheme.bodyMedium),
                Text('$_barWeight kg', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Actual total:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  '${actualWeight.toStringAsFixed(1)} kg',
                  style: theme.textTheme.titleLarge?.copyWith(color: AppColors.accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPlateColor(double weight) {
    if (weight >= 20) return const Color(0xFFEF4444); // Red
    if (weight >= 15) return const Color(0xFF3B82F6); // Blue
    if (weight >= 10) return const Color(0xFFF59E0B); // Amber
    if (weight >= 5) return const Color(0xFF10B981); // Green
    return const Color(0xFF71717A); // Gray
  }
}
