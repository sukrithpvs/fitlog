import 'package:flutter/material.dart';
import '../../../core/utils/one_rm_calculator.dart';
import '../../../core/theme/app_colors.dart';

class OneRmCalculatorScreen extends StatefulWidget {
  const OneRmCalculatorScreen({super.key});

  @override
  State<OneRmCalculatorScreen> createState() => _OneRmCalculatorScreenState();
}

class _OneRmCalculatorScreenState extends State<OneRmCalculatorScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  double? _oneRm;
  List<Map<String, dynamic>> _percentages = [];

  void _calculate() {
    final weight = double.tryParse(_weightController.text);
    final reps = int.tryParse(_repsController.text);

    if (weight != null && reps != null && reps > 0 && reps <= 30) {
      setState(() {
        _oneRm = OneRmCalculator.epley(weight, reps);
        if (_oneRm != null) {
          _percentages = [
            {'pct': 100, 'reps': 1, 'weight': _oneRm},
            {'pct': 95, 'reps': 2, 'weight': _oneRm! * 0.95},
            {'pct': 90, 'reps': 3, 'weight': _oneRm! * 0.90},
            {'pct': 85, 'reps': 5, 'weight': _oneRm! * 0.85},
            {'pct': 80, 'reps': 8, 'weight': _oneRm! * 0.80},
            {'pct': 75, 'reps': 10, 'weight': _oneRm! * 0.75},
            {'pct': 70, 'reps': 12, 'weight': _oneRm! * 0.70},
            {'pct': 65, 'reps': 15, 'weight': _oneRm! * 0.65},
            {'pct': 60, 'reps': 20, 'weight': _oneRm! * 0.60},
          ];
        }
      });
    } else {
      setState(() {
        _oneRm = null;
        _percentages = [];
      });
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('1RM Calculator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Estimate your One Rep Max (1RM) and view recommended weights for different rep ranges.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _calculate(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    decoration: const InputDecoration(
                      labelText: 'Reps',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculate(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (_oneRm != null) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text('Estimated 1RM', style: TextStyle(fontSize: 16, color: AppColors.accent)),
                    const SizedBox(height: 8),
                    Text(
                      '${_oneRm!.toStringAsFixed(1)} kg',
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text('Percentages', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _percentages.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = _percentages[index];
                    return ListTile(
                      leading: Container(
                        width: 48,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${row['pct']}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      title: Text('${(row['weight'] as double).toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      trailing: Text('${row['reps']} Reps', style: const TextStyle(color: Colors.grey)),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
