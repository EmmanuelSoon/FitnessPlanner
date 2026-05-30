import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/mesocycle.dart';
import '../domain/models/day_override.dart';
import '../domain/models/workout.dart';
import '../domain/schedule/schedule_logic.dart';
import '../providers/mesocycle_providers.dart';
import '../providers/workout_providers.dart';
import '../theme/app_theme.dart';
import 'mesocycle_setup_screen.dart';
import 'warmup_screen.dart';
import 'workout_session_screen.dart';
import 'widgets/app_widgets.dart';
import 'widgets/month_grid.dart';
import 'widgets/reminder_picker.dart';
import 'widgets/workout_picker.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _visibleMonth;
  final _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(_today.year, _today.month);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    final meso = ref.watch(activeMesocycleProvider);
    final overrides = ref.watch(overridesProvider).asData?.value ?? [];
    final workouts = ref.watch(workoutsProvider).asData?.value ?? [];

    final overrideMap = <String, DayOverride>{};
    for (final o in overrides) {
      overrideMap[_dateKey(o.date)] = o;
    }
    final workoutNames = <String, String>{for (final w in workouts) w.id: w.name};
    final workoutMap = <String, Workout>{for (final w in workouts) w.id: w};

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, c, meso),
            if (meso != null) _WeekBanner(
              meso: meso,
              today: _today,
              onEarlyRest: () => _confirmEarlyRest(context, meso),
              onAdjustWeek: () => _showSetCurrentWeekSheet(context, meso),
            ),
            Expanded(
              child: meso == null
                  ? _NoMesoState(onSetUp: () => _pushSetup(context, null))
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          MonthGrid(
                            month: _visibleMonth,
                            today: _today,
                            meso: meso,
                            overrideForDate: (date) => overrideMap[_dateKey(date)],
                            workoutNames: workoutNames,
                            onDayTap: (date, workoutId, workoutName) => _showDaySheet(
                              context,
                              date: date,
                              workoutId: workoutId,
                              workout: workoutId != null ? workoutMap[workoutId] : null,
                              workouts: workouts,
                              overrideMap: overrideMap,
                              meso: meso,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, AppColors c, Mesocycle? meso) {
    final label =
        '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}'.toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.chevron_left_rounded,
            onPressed: () => setState(() => _visibleMonth =
                DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() =>
                  _visibleMonth = DateTime(_today.year, _today.month)),
              child: Center(
                child: Text(
                  label,
                  style: bodyStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
          AppIconButton(
            icon: Icons.chevron_right_rounded,
            onPressed: () => setState(() => _visibleMonth =
                DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
          ),
          AppIconButton(
            icon: Icons.notifications_outlined,
            onPressed: () => showReminderPicker(context),
          ),
          AppIconButton(
            icon: Icons.edit_outlined,
            onPressed: () => _pushSetup(context, meso),
          ),
        ],
      ),
    );
  }

  // ─── Navigation ───────────────────────────────────────────────────────

  void _pushSetup(BuildContext context, Mesocycle? meso) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => MesocycleSetupScreen(existingMeso: meso)),
    );
  }

  // ─── Day tap sheet ────────────────────────────────────────────────────

  void _showDaySheet(
    BuildContext context, {
    required DateTime date,
    required String? workoutId,
    required Workout? workout,
    required List<Workout> workouts,
    required Map<String, DayOverride> overrideMap,
    required Mesocycle meso,
  }) {
    final c = AppThemeData.of(context).c;
    final hasOverride = overrideMap.containsKey(_dateKey(date));
    final dateLabel = _formatDate(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius + 8)),
        ),
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 20,
          bottom: 28 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              dateLabel,
              style: bodyStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.inkMute,
                  letterSpacing: 1.0),
            ),
            const SizedBox(height: 4),
            Text(
              workoutId != null ? (workout?.name ?? 'Workout') : 'Rest day',
              style: displayStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: c.ink,
                  letterSpacing: -0.4),
            ),
            const SizedBox(height: 20),
            if (workout != null) ...[
              AppButton(
                label: 'Start workout',
                icon: Icons.play_arrow_rounded,
                full: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => workout.warmup.isNotEmpty
                          ? WarmupScreen(workout: workout)
                          : WorkoutSessionScreen(workout: workout),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Move to another date',
                kind: ButtonKind.outline,
                icon: Icons.swap_horiz_rounded,
                full: true,
                onPressed: () async {
                  Navigator.pop(ctx);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date.add(const Duration(days: 1)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null && context.mounted) {
                    await ref
                        .read(overridesProvider.notifier)
                        .move(date, picked, workoutId!);
                  }
                },
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Clear — make it a rest day',
                kind: ButtonKind.ghost,
                full: true,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(overridesProvider.notifier).setRest(date);
                },
              ),
            ] else ...[
              AppButton(
                label: 'Add a workout',
                icon: Icons.add_rounded,
                full: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  showWorkoutPicker(
                    context: context,
                    workouts: workouts,
                    selectedWorkoutId: null,
                    onSelected: (id) async {
                      if (id != null) {
                        await ref
                            .read(overridesProvider.notifier)
                            .setWorkout(date, id);
                      }
                    },
                  );
                },
              ),
            ],
            if (hasOverride) ...[
              const SizedBox(height: 10),
              AppButton(
                label: 'Reset to scheduled',
                kind: ButtonKind.ghost,
                full: true,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(overridesProvider.notifier).clearOverride(date);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Early rest confirm ───────────────────────────────────────────────

  void _confirmEarlyRest(BuildContext context, Mesocycle meso) {
    final c = AppThemeData.of(context).c;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius + 8)),
        ),
        padding: EdgeInsets.only(
          left: 22, right: 22, top: 20,
          bottom: 28 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: c.hairline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Start rest week early?',
                style: displayStyle(fontSize: 22, fontWeight: FontWeight.w500, color: c.ink, letterSpacing: -0.3)),
            const SizedBox(height: 10),
            Text(
              'This week becomes your rest week. After ${meso.restWeeks == 1 ? "it" : "${meso.restWeeks} rest weeks"} pass${meso.restWeeks == 1 ? "s" : ""}, a fresh training block will begin automatically.',
              style: bodyStyle(fontSize: 14, color: c.inkDim, height: 1.5),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    kind: ButtonKind.outline,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Start rest week',
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref.read(mesocyclesProvider.notifier).appendAdjustment(
                        meso.id,
                        earlyRestAdjustment(meso, _today),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Set current week sheet ───────────────────────────────────────────

  void _showSetCurrentWeekSheet(BuildContext context, Mesocycle meso) {
    final c = AppThemeData.of(context).c;
    final totalLen = meso.trainingWeeks + meso.restWeeks;
    final options = <String>[
      ...List.generate(
          meso.trainingWeeks, (i) => 'Week ${i + 1} · Training'),
      ...List.generate(
          meso.restWeeks, (i) => meso.restWeeks == 1 ? 'Rest week' : 'Rest week ${i + 1}'),
    ];
    final currentIdx = cycleWeekIndexForDate(meso, _today).clamp(0, totalLen - 1);
    int selectedIdx = currentIdx;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius + 8)),
          ),
          padding: EdgeInsets.only(
            left: 22, right: 22, top: 20,
            bottom: 28 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: c.hairline, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "I'm currently on…",
                style: displayStyle(fontSize: 20, fontWeight: FontWeight.w500, color: c.ink, letterSpacing: -0.3),
              ),
              const SizedBox(height: 4),
              Text(
                'This only affects this week onward — past weeks are unchanged.',
                style: bodyStyle(fontSize: 13, color: c.inkDim),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: currentIdx),
                  itemExtent: 44,
                  onSelectedItemChanged: (i) => selectedIdx = i,
                  children: options
                      .map((o) => Center(
                            child: Text(o, style: bodyStyle(fontSize: 16, color: c.ink)),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Set week',
                full: true,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(mesocyclesProvider.notifier).appendAdjustment(
                    meso.id,
                    setCurrentWeekAdjustment(_today, selectedIdx),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${days[d.weekday - 1].toUpperCase()}, ${months[d.month - 1]} ${d.day}'.toUpperCase();
  }

  String _monthName(int m) => const [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][m - 1];
}

// ─── Week status banner ────────────────────────────────────────────────

class _WeekBanner extends StatelessWidget {
  final Mesocycle meso;
  final DateTime today;
  final VoidCallback onEarlyRest;
  final VoidCallback onAdjustWeek;

  const _WeekBanner({
    required this.meso,
    required this.today,
    required this.onEarlyRest,
    required this.onAdjustWeek,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    final isDark = AppThemeData.of(context).isDark;
    final status = statusForDate(meso, today);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(kRadius),
          boxShadow: cardShadow(isDark),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    style: bodyStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: status.isTraining ? c.accent : c.inkDim,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meso.name,
                    style: bodyStyle(fontSize: 12, color: c.inkMute),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (status.isTraining)
              AppButton(
                label: 'Rest early',
                kind: ButtonKind.outline,
                small: true,
                onPressed: onEarlyRest,
              ),
            const SizedBox(width: 8),
            AppButton(
              label: 'Adjust',
              kind: ButtonKind.ghost,
              small: true,
              onPressed: onAdjustWeek,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── No mesocycle empty state ──────────────────────────────────────────

class _NoMesoState extends StatelessWidget {
  final VoidCallback onSetUp;

  const _NoMesoState({required this.onSetUp});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.hairline, width: 1.5),
            ),
            child: Icon(Icons.calendar_today_rounded, size: 28, color: c.inkMute),
          ),
          const SizedBox(height: 18),
          Text(
            'No mesocycle set up.',
            style: displayStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: c.ink,
              letterSpacing: -0.4,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Define your training block once — the calendar fills itself in.',
            style: bodyStyle(fontSize: 14, color: c.inkDim, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Set up mesocycle',
            icon: Icons.add_rounded,
            onPressed: onSetUp,
          ),
        ],
      ),
    );
  }
}
