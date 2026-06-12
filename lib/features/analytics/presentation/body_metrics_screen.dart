// lib/features/analytics/presentation/body_metrics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';

final bodyMetricsProvider = StreamProvider<List<BodyMetric>>((ref) {
  return ref.watch(databaseProvider).watchBodyMetrics();
});

class BodyMetricsScreen extends ConsumerWidget {
  const BodyMetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final metricsAsync = ref.watch(bodyMetricsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Metrics'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMetric(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Log Weight'),
      ),
      body: metricsAsync.when(
        data: (metrics) {
          if (metrics.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.monitor_weight_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No body metrics yet',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your weight and body fat',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Latest Stats
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatColumn(
                            label: 'Weight',
                            value: '${metrics.first.weightKg?.toStringAsFixed(1) ?? '-'} kg',
                            color: AppColors.accent,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: theme.colorScheme.outline,
                        ),
                        Expanded(
                          child: _StatColumn(
                            label: 'Body Fat',
                            value: '${metrics.first.bodyFatPercent?.toStringAsFixed(1) ?? '-'}%',
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Text('HISTORY', style: theme.textTheme.labelSmall),
                const SizedBox(height: 16),

                ...metrics.map((metric) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.monitor_weight,
                            color: AppColors.accent,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '${metric.weightKg?.toStringAsFixed(1) ?? '-'} kg',
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          DateFormatter.relative(metric.recordedAt),
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: metric.bodyFatPercent != null
                            ? Text(
                                '${metric.bodyFatPercent!.toStringAsFixed(1)}% BF',
                                style: theme.textTheme.bodySmall,
                              )
                            : null,
                      ),
                    )),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showAddMetric(BuildContext context, WidgetRef ref) {
    final weightController = TextEditingController();
    final bodyFatController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Body Metrics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                hintText: '70.5',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bodyFatController,
              decoration: const InputDecoration(
                labelText: 'Body Fat % (optional)',
                hintText: '15.0',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final weight = double.tryParse(weightController.text);
              final bodyFat = double.tryParse(bodyFatController.text);

              if (weight != null) {
                final db = ref.read(databaseProvider);
                await db.insertBodyMetric(
                  BodyMetricsCompanion.insert(
                    recordedAt: DateTime.now(),
                    weightKg: Value(weight),
                    bodyFatPercent: Value(bodyFat),
                  ),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Metrics logged')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
