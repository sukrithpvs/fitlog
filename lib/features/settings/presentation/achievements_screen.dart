import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

final achievementsProvider = StreamProvider<List<UserBadge>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.userBadges)
    ..orderBy([(b) => drift.OrderingTerm.desc(b.earnedAt)]))
  .watch();
});

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(achievementsProvider);
    final theme = Theme.of(context);

    // List of all possible badges in the system
    final allBadges = [
      {'id': 'first_workout', 'title': 'First Steps', 'desc': 'Completed your first workout', 'icon': Icons.directions_run},
      {'id': '10_workouts', 'title': 'Consistent', 'desc': 'Completed 10 workouts', 'icon': Icons.repeat},
      {'id': '50_workouts', 'title': 'Dedicated', 'desc': 'Completed 50 workouts', 'icon': Icons.fitness_center},
      {'id': '100_workouts', 'title': 'Centurion', 'desc': 'Completed 100 workouts', 'icon': Icons.emoji_events},
      {'id': '10k_volume', 'title': 'Heavy Lifter', 'desc': 'Lifted over 10,000kg in one session', 'icon': Icons.fitness_center},
      {'id': 'streak_7', 'title': '1 Week Streak', 'desc': 'Worked out 7 weeks in a row', 'icon': Icons.local_fire_department},
      {'id': '100kg_squat', 'title': 'First 100kg Squat', 'desc': 'Squatted 100kg or more', 'icon': Icons.accessibility_new},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trophy Case'),
      ),
      body: badgesAsync.when(
        data: (earnedBadges) {
          final earnedIds = earnedBadges.map((b) => b.badgeType).toSet();
          
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: allBadges.length,
            itemBuilder: (context, index) {
              final badgeDef = allBadges[index];
              final isEarned = earnedIds.contains(badgeDef['id']);
              final earnedRecord = isEarned ? earnedBadges.firstWhere((b) => b.badgeType == badgeDef['id']) : null;
              
              return Card(
                color: isEarned ? null : theme.colorScheme.surface.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: isEarned ? AppColors.warning : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isEarned ? AppColors.warning.withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          badgeDef['icon'] as IconData,
                          size: 40,
                          color: isEarned ? AppColors.warning : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        badgeDef['title'] as String,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isEarned ? null : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badgeDef['desc'] as String,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isEarned ? theme.colorScheme.onSurfaceVariant : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isEarned && earnedRecord != null) ...[
                        const Spacer(),
                        Text(
                          DateFormat.yMMMd().format(earnedRecord.earnedAt),
                          style: const TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.bold),
                        ),
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
