import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/providers/workout_providers.dart';
import 'package:fitness_planner/presentation/create_workout.dart';
import 'package:fitness_planner/presentation/workout_session_screen.dart';
import 'package:fitness_planner/presentation/warmup_screen.dart';
import 'package:fitness_planner/presentation/history_screen.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/presentation/widgets/appearance_picker.dart';
import 'package:fitness_planner/theme/app_theme.dart';

class WorkoutListScreen extends ConsumerWidget {
  const WorkoutListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutsProvider);
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: workoutsAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: c.accent),
          ),
          error: (e, _) => Center(
            child: Text('Error: $e',
                style: bodyStyle(color: c.danger)),
          ),
          data: (workouts) => workouts.isEmpty
              ? _EmptyState(onCreatePressed: () => _openCreate(context))
              : _WorkoutList(workouts: workouts),
        ),
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateWorkoutScreen()),
    );
  }
}

// ─── Workout list (non-empty) ──────────────────────────────────────────
class _WorkoutList extends ConsumerWidget {
  final List<Workout> workouts;
  const _WorkoutList({required this.workouts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    final now = DateTime.now();
    final weekday = _weekdayName(now.weekday);
    final dateLabel =
        '$weekday · ${_monthName(now.month)} ${now.day}';

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // ─── Hero header ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 32, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateLabel.toUpperCase(),
                          style: bodyStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.inkDim,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Row(
                          children: [
                            // Appearance picker
                            GestureDetector(
                              onTap: () =>
                                  showAppearancePicker(context),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: Center(
                                  child: SwatchGlyph(
                                    size: 20,
                                    accentColor: c.accent,
                                    inkColor: c.ink,
                                  ),
                                ),
                              ),
                            ),
                            // History
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.history_rounded,
                                    size: 20, color: c.inkDim),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const HistoryScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Workouts',
                      style: displayStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -1.8,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${workouts.length} saved',
                      style: bodyStyle(
                        fontSize: 13,
                        color: c.inkDim,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ─── Cards ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList.separated(
                itemCount: workouts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final w = workouts[index];
                  final dur = w.totalDuration.inMinutes;
                  return WorkoutListCard(
                    name: w.name,
                    exerciseCount: w.exercises
                        .fold(0, (sum, s) => sum + s.exercises.length),
                    durationMinutes: dur > 0 ? dur : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => w.warmup.isNotEmpty
                            ? WarmupScreen(workout: w)
                            : WorkoutSessionScreen(workout: w),
                      ),
                    ),
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CreateWorkoutScreen(existingWorkout: w),
                      ),
                    ),
                    onDelete: () =>
                        _confirmDelete(context, ref, w),
                  );
                },
              ),
            ),
          ],
        ),
        // ─── FAB ──────────────────────────────────────────────────
        Positioned(
          right: 18,
          bottom: 36 + MediaQuery.of(context).padding.bottom,
          child: AppFab(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CreateWorkoutScreen()),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Workout workout) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DeleteSheet(
        workout: workout,
        onConfirm: () async {
          await ref
              .read(workoutsProvider.notifier)
              .deleteWorkout(workout.id);
        },
      ),
    );
  }

  String _weekdayName(int weekday) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ][weekday - 1];

  String _monthName(int month) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][month - 1];
}

// ─── Empty state ───────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreatePressed;
  const _EmptyState({required this.onCreatePressed});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
      child: Column(
        children: [
          AppHeaderBar(
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => showAppearancePicker(context),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: SwatchGlyph(
                        size: 20,
                        accentColor: c.accent,
                        inkColor: c.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Dashed circle with dumbbell
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.hairline,
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignCenter,
                    ),
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 32,
                    color: c.inkMute,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Nothing here yet.',
                  style: displayStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Plan a workout once, follow it at the gym.\nEverything stays on your device.',
                  style: bodyStyle(
                    fontSize: 14,
                    color: c.inkDim,
                    height: 1.5,
                    letterSpacing: 0.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                AppButton(
                  label: 'Create your first workout',
                  icon: Icons.add_rounded,
                  onPressed: onCreatePressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Delete confirmation bottom sheet ─────────────────────────────────
class _DeleteSheet extends StatelessWidget {
  final Workout workout;
  final VoidCallback onConfirm;

  const _DeleteSheet({required this.workout, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(kRadius + 8),
        ),
      ),
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 20,
        bottom: 28 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Delete "${workout.name}"?',
            style: displayStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: c.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This workout and its ${workout.exercises.length} exercises will be permanently removed from this device.',
            style: bodyStyle(
              fontSize: 14,
              color: c.inkDim,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  kind: ButtonKind.outline,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Delete',
                  kind: ButtonKind.danger,
                  icon: Icons.delete_outline_rounded,
                  onPressed: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
