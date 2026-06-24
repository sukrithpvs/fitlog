// lib/features/workout/presentation/widgets/set_row_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';

class SetRowWidget extends StatefulWidget {
  final WorkoutSet set;
  final int setNumber;
  final String trackingType;
  final String previousPerformance;
  final Function(int setId, {double? weight, int? reps, int? durationSeconds, double? distanceMeters}) onUpdateSet;
  final Function(WorkoutSet set) onToggleComplete;
  final VoidCallback cycleSetType;
  final VoidCallback showRpeDialog;

  const SetRowWidget({
    Key? key,
    required this.set,
    required this.setNumber,
    required this.trackingType,
    required this.previousPerformance,
    required this.onUpdateSet,
    required this.onToggleComplete,
    required this.cycleSetType,
    required this.showRpeDialog,
  }) : super(key: key);

  @override
  State<SetRowWidget> createState() => _SetRowWidgetState();
}

class _SetRowWidgetState extends State<SetRowWidget> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  late TextEditingController _timeController;
  late TextEditingController _distanceController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant SetRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Don't override user input if they are currently typing, 
    // but update if the DB changed from outside (e.g., superset sync)
    if (widget.set.id != oldWidget.set.id) {
      _initControllers();
    }
  }

  void _initControllers() {
    _weightController = TextEditingController(text: widget.set.weight?.toStringAsFixed(1).replaceAll('.0', '') ?? '');
    _repsController = TextEditingController(text: widget.set.reps?.toString() ?? '');
    
    String timeStr = '';
    if (widget.set.durationSeconds != null) {
      final m = widget.set.durationSeconds! ~/ 60;
      final s = widget.set.durationSeconds! % 60;
      timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    _timeController = TextEditingController(text: timeStr);
    
    _distanceController = TextEditingController(text: widget.set.distanceMeters != null ? (widget.set.distanceMeters! / 1000).toStringAsFixed(2).replaceAll('.00', '') : '');
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _timeController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  Color _getRpeColor(int rpe) {
    if (rpe <= 6) return AppColors.success;
    if (rpe <= 8) return AppColors.warning;
    return AppColors.error;
  }

  Widget _buildSetTypeIndicator() {
    final set = widget.set;
    if (set.setType == 'warmup') {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
        child: const Center(child: Text('W', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold))),
      );
    } else if (set.setType == 'drop') {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
        child: const Center(child: Text('D', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))),
      );
    } else if (set.setType == 'failure') {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
        child: const Center(child: Text('F', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
      );
    } else if (set.setType == 'partials') {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: Colors.deepPurple.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
        child: const Center(child: Text('P', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold))),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
      child: Center(child: Text('${widget.setNumber}', style: const TextStyle(fontWeight: FontWeight.bold))),
    );
  }

  double? _getSuggestedWeight() {
    if (widget.trackingType == 'reps_only' || widget.trackingType == 'time_only' || widget.trackingType == 'distance_time') return null;
    if (widget.set.weight != null) return null;
    if (widget.previousPerformance == '—') return null;

    final weightMatch = RegExp(r'([\d\.]+)kg').firstMatch(widget.previousPerformance);
    final rpeMatch = RegExp(r'@RPE\s*(\d+)').firstMatch(widget.previousPerformance);
    
    if (weightMatch != null) {
      final prevWeight = double.tryParse(weightMatch.group(1) ?? '');
      if (prevWeight != null) {
        int? prevRpe;
        if (rpeMatch != null) {
          prevRpe = int.tryParse(rpeMatch.group(1) ?? '');
        }
        
        if (prevRpe != null) {
          if (prevRpe == 10) return prevWeight;
          else if (prevRpe >= 8) return prevWeight + 2.5;
          else return prevWeight + 5.0;
        } else {
          return prevWeight + 2.5;
        }
      }
    }
    return null;
  }

  String? _getSuggestionLabel(double? suggestedWeight) {
    if (suggestedWeight == null) return null;
    final rpeMatch = RegExp(r'@RPE\s*(\d+)').firstMatch(widget.previousPerformance);
    int? prevRpe = rpeMatch != null ? int.tryParse(rpeMatch.group(1) ?? '') : null;
    if (prevRpe != null) {
      if (prevRpe == 10) return 'Same';
      else if (prevRpe >= 8) return '+2.5kg';
      else return '+5kg';
    }
    return '+2.5kg';
  }

  Widget _buildCol1() {
    final theme = Theme.of(context);
    if (widget.trackingType == 'reps_only' || widget.trackingType == 'time_only') return const Center(child: Text('-'));
    if (widget.trackingType == 'distance_time') {
      return TextField(
        controller: _distanceController,
        decoration: const InputDecoration(hintText: '0.0', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: theme.textTheme.bodyMedium, textAlign: TextAlign.center,
        onChanged: (v) {
          final val = double.tryParse(v);
          widget.onUpdateSet(widget.set.id, distanceMeters: val != null ? val * 1000 : null);
        },
      );
    }
    
    final suggestedWeight = _getSuggestedWeight();
    final suggestionLabel = _getSuggestionLabel(suggestedWeight);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        TextField(
          controller: _weightController,
          decoration: const InputDecoration(hintText: '0', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: theme.textTheme.bodyMedium, textAlign: TextAlign.center,
          onChanged: (v) => widget.onUpdateSet(widget.set.id, weight: double.tryParse(v)),
        ),
        if (suggestedWeight != null)
          Positioned(
            bottom: -22,
            child: GestureDetector(
              onTap: () {
                _weightController.text = suggestedWeight!.toStringAsFixed(1).replaceAll('.0', '');
                widget.onUpdateSet(widget.set.id, weight: suggestedWeight);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(suggestionLabel ?? '+2.5kg', style: const TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCol2() {
    final theme = Theme.of(context);
    if (widget.trackingType == 'time_only' || widget.trackingType == 'distance_time') {
      return TextField(
        controller: _timeController,
        decoration: const InputDecoration(hintText: '00:00', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
        keyboardType: TextInputType.datetime,
        style: theme.textTheme.bodyMedium, textAlign: TextAlign.center,
        onChanged: (v) {
          if (v.length == 5 && v.contains(':')) {
            final parts = v.split(':');
            if (parts.length == 2) {
              final m = int.tryParse(parts[0]) ?? 0;
              final s = int.tryParse(parts[1]) ?? 0;
              widget.onUpdateSet(widget.set.id, durationSeconds: (m * 60) + s);
            }
          } else if (v.isEmpty) {
            widget.onUpdateSet(widget.set.id, durationSeconds: null);
          }
        },
      );
    }
    return TextField(
      controller: _repsController,
      decoration: const InputDecoration(hintText: '0', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
      keyboardType: TextInputType.number,
      style: theme.textTheme.bodyMedium, textAlign: TextAlign.center,
      onChanged: (v) => widget.onUpdateSet(widget.set.id, reps: int.tryParse(v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
    final theme = Theme.of(context);
    
    final bool hasSuggestion = _getSuggestedWeight() != null;
    
    return Padding(
      padding: EdgeInsets.only(bottom: hasSuggestion ? 26.0 : 8.0),
      child: Container(
        color: set.isCompleted ? AppColors.success.withValues(alpha: 0.1) : Colors.transparent,
        child: Row(
          children: [
            SizedBox(
              width: 50,
              child: Row(
                children: [
                  if (set.setType == 'drop')
                    Icon(Icons.subdirectory_arrow_right, size: 16, color: theme.colorScheme.outline)
                  else
                    const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.cycleSetType,
                      onLongPress: widget.showRpeDialog,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          _buildSetTypeIndicator(),
                          if (set.rpe != null)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getRpeColor(set.rpe!),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                widget.previousPerformance,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _buildCol1(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _buildCol2(),
              ),
            ),
            IconButton(
              icon: Icon(
                set.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: set.isCompleted ? AppColors.success : theme.colorScheme.outline,
              ),
              onPressed: () => widget.onToggleComplete(set),
            ),
          ],
        ),
      ),
    );
  }
}
