import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PlateCalculatorModal extends StatefulWidget {
  final double targetWeight;
  const PlateCalculatorModal({super.key, required this.targetWeight});

  @override
  State<PlateCalculatorModal> createState() => _PlateCalculatorModalState();
}

class _PlateCalculatorModalState extends State<PlateCalculatorModal> {
  late TextEditingController _weightController;
  double _barWeight = 20.0; // Standard Olympic Bar
  
  // Standard plate sizes (in kg)
  final List<double> _availablePlates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.targetWeight.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Map<double, int> _calculatePlates(double target) {
    if (target <= _barWeight) return {};

    double weightRemaining = (target - _barWeight) / 2.0; // Weight per side
    final Map<double, int> platesToLoad = {};

    for (final plate in _availablePlates) {
      if (weightRemaining >= plate) {
        int count = (weightRemaining / plate).floor();
        platesToLoad[plate] = count;
        weightRemaining -= (plate * count);
      }
    }

    return platesToLoad;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = double.tryParse(_weightController.text) ?? widget.targetWeight;
    final plates = _calculatePlates(target);
    final canCalculate = target >= _barWeight;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Plate Calculator', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Target Weight (kg)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixText: 'kg',
            ),
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Text('Bar Weight:', style: theme.textTheme.bodyLarge),
              const SizedBox(width: 16),
              ChoiceChip(
                label: const Text('20 kg'),
                selected: _barWeight == 20.0,
                onSelected: (val) => setState(() => _barWeight = 20.0),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('15 kg'),
                selected: _barWeight == 15.0,
                onSelected: (val) => setState(() => _barWeight = 15.0),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (!canCalculate)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Target weight must be greater than the bar weight!',
                style: TextStyle(color: AppColors.error),
              ),
            )
          else if (plates.isEmpty)
             const Center(child: Text('Just the bar!'))
          else ...[
            Text('Load on EACH side:', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.accent)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: plates.entries.map((e) {
                final weight = e.key;
                final count = e.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _getColorForPlate(weight),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    '${weight}kg × $count',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                );
              }).toList(),
            ),
          ],
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Color _getColorForPlate(double weight) {
    if (weight >= 25) return Colors.red.shade700;
    if (weight >= 20) return Colors.blue.shade700;
    if (weight >= 15) return Colors.yellow.shade700;
    if (weight >= 10) return Colors.green.shade700;
    return Colors.grey.shade800;
  }
}
