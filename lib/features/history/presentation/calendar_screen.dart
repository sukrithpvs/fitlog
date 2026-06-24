// lib/features/history/presentation/calendar_screen.dart
// Hevy-style workout calendar showing workout history on calendar view
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import 'workout_detail_screen.dart';

// Provider for workouts by date
final workoutsByDateProvider = StreamProvider<Map<DateTime, List<Workout>>>((ref) async* {
  final db = ref.watch(databaseProvider);
  final workoutsStream = (db.select(db.workouts)
        ..where((w) => w.isTemplate.equals(false))
        ..orderBy([(w) => OrderingTerm.desc(w.startTime)]))
      .watch();

  await for (final workouts in workoutsStream) {
    final map = <DateTime, List<Workout>>{};
    for (final workout in workouts) {
      final date = DateTime(
        workout.startTime.year,
        workout.startTime.month,
        workout.startTime.day,
      );
      map.putIfAbsent(date, () => []).add(workout);
    }
    yield map;
  }
});

// Provider for scheduled workouts by date
final scheduledWorkoutsByDateProvider = StreamProvider<Map<DateTime, List<ScheduledWorkout>>>((ref) async* {
  final db = ref.watch(databaseProvider);
  final scheduledStream = db.select(db.scheduledWorkouts).watch();

  await for (final scheduled in scheduledStream) {
    final map = <DateTime, List<ScheduledWorkout>>{};
    for (final s in scheduled) {
      final date = DateTime(
        s.scheduledDate.year,
        s.scheduledDate.month,
        s.scheduledDate.day,
      );
      map.putIfAbsent(date, () => []).add(s);
    }
    yield map;
  }
});
class MonthlyStats {
  final int activeDays;
  final int restDays;
  final double totalVolume;
  MonthlyStats(this.activeDays, this.restDays, this.totalVolume);
}

final monthlyStatsProvider = StreamProvider.family<MonthlyStats, DateTime>((ref, month) async* {
  final db = ref.watch(databaseProvider);
  
  final workoutsStream = (db.select(db.workouts)..where((w) => w.isTemplate.equals(false))).watch();
  
  await for (final workouts in workoutsStream) {
    final monthWorkouts = workouts.where((w) => w.startTime.year == month.year && w.startTime.month == month.month).toList();
    final activeDays = monthWorkouts.map((w) => w.startTime.day).toSet().length;
    
    final now = DateTime.now();
    int passedDays = DateUtils.getDaysInMonth(month.year, month.month);
    if (month.year == now.year && month.month == now.month) {
      passedDays = now.day;
    } else if (month.isAfter(now)) {
      passedDays = 0;
    }
    int restDays = passedDays > activeDays ? passedDays - activeDays : 0;
    
    double totalVolume = 0;
    for (final w in monthWorkouts) {
      final sets = await db.getSetsForWorkout(w.id);
      totalVolume += sets
          .where((s) => s.isCompleted && s.weight != null && s.reps != null)
          .fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));
    }
    
    yield MonthlyStats(activeDays, restDays, totalVolume);
  }
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final workoutsAsync = ref.watch(workoutsByDateProvider);
    final scheduledAsync = ref.watch(scheduledWorkoutsByDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
          ),
        ],
      ),
      body: workoutsAsync.when(
        data: (workoutsByDate) {
          final statsAsync = ref.watch(monthlyStatsProvider(DateTime(_focusedDay.year, _focusedDay.month)));

          return Column(
            children: [
              // Monthly Summary Banner
              statsAsync.when(
                data: (stats) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MonthStat(
                        icon: Icons.local_fire_department,
                        label: 'Active',
                        value: '${stats.activeDays}d',
                        color: AppColors.accent,
                      ),
                      _MonthStat(
                        icon: Icons.bedtime,
                        label: 'Rest',
                        value: '${stats.restDays}d',
                        color: theme.colorScheme.outline,
                      ),
                      _MonthStat(
                        icon: Icons.fitness_center,
                        label: 'Volume',
                        value: '${stats.totalVolume.toStringAsFixed(0)}kg',
                        color: AppColors.success,
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Calendar
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  eventLoader: (day) {
                    final normalizedDay = DateTime(day.year, day.month, day.day);
                    return workoutsByDate[normalizedDay] ?? [];
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 1,
                    markerSize: 7,
                    outsideDaysVisible: false,
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    formatButtonShowsNext: false,
                    formatButtonDecoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    formatButtonTextStyle: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: _buildWorkoutList(
                  workoutsByDate, 
                  scheduledAsync.value ?? {}, 
                  theme, 
                  isDark
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error loading calendar: $err'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutList(
    Map<DateTime, List<Workout>> workoutsByDate,
    Map<DateTime, List<ScheduledWorkout>> scheduledByDate,
    ThemeData theme,
    bool isDark,
  ) {
    if (_selectedDay == null) {
      return const Center(child: Text('Select a day to view workouts'));
    }

    final normalizedDay = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );
    final workouts = workoutsByDate[normalizedDay] ?? [];
    final scheduledWorkouts = scheduledByDate[normalizedDay] ?? [];

    if (workouts.isEmpty && scheduledWorkouts.isEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final isFuture = normalizedDay.isAfter(today) || normalizedDay.isAtSameMomentAs(today);

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No workouts',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              DateFormatter.fullDate(_selectedDay!),
              style: theme.textTheme.bodySmall,
            ),
            if (isFuture) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Schedule Workout'),
                onPressed: () {
                  // TODO: Implement schedule dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Schedule feature coming soon')),
                  );
                },
              ),
            ]
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            DateFormatter.fullDate(_selectedDay!).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              ...workouts.map((workout) => _buildWorkoutCard(workout, theme, isDark)),
              ...scheduledWorkouts.map((scheduled) => _buildScheduledCard(scheduled, theme, isDark)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduledCard(ScheduledWorkout scheduled, ThemeData theme, bool isDark) {
    return FutureBuilder<Workout?>(
      future: (ref.read(databaseProvider).select(ref.read(databaseProvider).workouts)
            ..where((w) => w.id.equals(scheduled.routineId)))
          .getSingleOrNull(),
      builder: (context, snapshot) {
        final template = snapshot.data;
        if (template == null) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5), width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_note, color: AppColors.accent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scheduled',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    // TODO: cancel scheduled workout
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkoutCard(Workout workout, ThemeData theme, bool isDark) {
    final duration = workout.endTime?.difference(workout.startTime);

    return FutureBuilder<List<WorkoutSet>>(
      future: ref.read(databaseProvider).getSetsForWorkout(workout.id),
      builder: (context, snapshot) {
        final sets = snapshot.data ?? [];
        final completedSets = sets.where((s) => s.isCompleted).length;
        final totalVolume = sets
            .where((s) => s.isCompleted && s.weight != null && s.reps != null)
            .fold<double>(0, (sum, s) => sum + (s.weight! * s.reps!));

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkoutDetailScreen(workoutId: workout.id),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                        child: const Icon(
                          Icons.fitness_center,
                          color: AppColors.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workout.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormatter.time(workout.startTime),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (workout.intensityRating != null)
                        Row(
                          children: List.generate(workout.intensityRating!, (i) {
                            return const Icon(
                              Icons.star,
                              color: AppColors.warning,
                              size: 14,
                            );
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.timer_outlined,
                        label: duration != null ? DateFormatter.duration(duration) : '-',
                      ),
                      const SizedBox(width: 12),
                      _InfoChip(
                        icon: Icons.check_circle_outline,
                        label: '$completedSets sets',
                      ),
                      const SizedBox(width: 12),
                      _InfoChip(
                        icon: Icons.trending_up,
                        label: '${totalVolume.toStringAsFixed(0)} kg',
                      ),
                    ],
                  ),
                  if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notes,
                            size: 14,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              workout.notes!,
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _MonthStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MonthStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ],
    );
  }
}
