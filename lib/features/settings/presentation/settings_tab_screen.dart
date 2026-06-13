// lib/features/settings/presentation/settings_tab_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../core/database/database_provider.dart';
import '../../routines/utils/routine_share.dart';
import '../utils/csv_export.dart';
import '../utils/csv_export.dart';
import '../utils/data_import.dart';
import 'package:go_router/go_router.dart';

class SettingsTabScreen extends ConsumerWidget {
  const SettingsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final weightUnit = ref.watch(weightUnitProvider);
    final defaultRest = ref.watch(defaultRestSecondsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Appearance Section
          _SectionHeader(title: 'APPEARANCE'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: Text(themeMode == ThemeMode.dark ? 'Enabled' : 'Disabled'),
            value: themeMode == ThemeMode.dark,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
            secondary: const Icon(Icons.dark_mode),
          ),

          const Divider(),

          // Units Section
          _SectionHeader(title: 'UNITS'),
          ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text('Weight Unit'),
            subtitle: Text(weightUnit.toUpperCase()),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'kg', label: Text('kg')),
                ButtonSegment(value: 'lbs', label: Text('lbs')),
              ],
              selected: {weightUnit},
              onSelectionChanged: (Set<String> newSelection) {
                ref.read(weightUnitProvider.notifier).toggleUnit();
              },
            ),
          ),

          const Divider(),

          // Workout Settings
          _SectionHeader(title: 'WORKOUT'),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('Default Rest Timer'),
            subtitle: Text('$defaultRest seconds'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    if (defaultRest > 30) {
                      ref.read(defaultRestSecondsProvider.notifier).setDuration(defaultRest - 15);
                    }
                  },
                ),
                Text('${defaultRest}s'),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    if (defaultRest < 300) {
                      ref.read(defaultRestSecondsProvider.notifier).setDuration(defaultRest + 15);
                    }
                  },
                ),
              ],
            ),
          ),

          const Divider(),

          // Data Management
          _SectionHeader(title: 'DATA'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export Workout History'),
            subtitle: const Text('Download as CSV'),
            onTap: () => _exportCsv(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Export Full Backup'),
            subtitle: const Text('JSON format'),
            onTap: () => _exportBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import Workout History'),
            subtitle: const Text('From CSV file'),
            onTap: () => _importCsv(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Import Backup'),
            subtitle: const Text('From JSON file'),
            onTap: () => _importJson(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Import Routine'),
            subtitle: const Text('From shared JSON'),
            onTap: () => _importRoutine(context, ref),
          ),

          const Divider(),

          // About Section
          _SectionHeader(title: 'ABOUT'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('0.1.0+1'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Built with Flutter'),
            subtitle: const Text('Hevy Clone'),
          ),

          const SizedBox(height: 32),

          // Danger Zone
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _confirmClearData(context, ref),
              icon: const Icon(Icons.delete_forever, color: AppColors.error),
              label: const Text('Clear All Data', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(databaseProvider);
      await CsvExporter.exportWorkoutHistory(db);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV export shared successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(databaseProvider);
      await CsvExporter.exportFullBackup(db);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup shared successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete:\n\n'
          '• All workout history\n'
          '• All body metrics\n'
          '• Custom exercises\n'
          '• Routine folders\n\n'
          'Built-in exercises and settings will remain.\n\n'
          'This action cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Clearing data...'),
            ],
          ),
        ),
      );

      try {
        final db = ref.read(databaseProvider);
        await db.clearAllData();
        
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ All data cleared successfully'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 3),
            ),
          );
          context.go('/');
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear data: $e'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(databaseProvider);
      final result = await DataImporter.importCSV(db);
      
      if (context.mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _importJson(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Backup'),
        content: const Text(
          'This will import data from a backup file. Existing data will not be deleted. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = ref.read(databaseProvider);
      final result = await DataImporter.importJSON(db);
      
      if (context.mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _importRoutine(BuildContext context, WidgetRef ref) async {
    try {
      // Pick JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      
      final db = ref.read(databaseProvider);
      final importResult = await RoutineSharer.importRoutine(db, content);
      
      if (context.mounted) {
        if (importResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.message),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
