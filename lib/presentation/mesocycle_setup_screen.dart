import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/mesocycle.dart';
import '../domain/schedule/schedule_logic.dart';
import '../providers/mesocycle_providers.dart';
import '../providers/workout_providers.dart';
import '../theme/app_theme.dart';
import 'widgets/app_widgets.dart';
import 'widgets/workout_picker.dart';

class MesocycleSetupScreen extends ConsumerStatefulWidget {
  final Mesocycle? existingMeso;

  const MesocycleSetupScreen({super.key, this.existingMeso});

  @override
  ConsumerState<MesocycleSetupScreen> createState() =>
      _MesocycleSetupScreenState();
}

class _MesocycleSetupScreenState extends ConsumerState<MesocycleSetupScreen> {
  final _nameController = TextEditingController();
  late DateTime _anchorDate;
  late int _trainingWeeks;
  late int _restWeeks;
  late Map<int, String?> _weekdayWorkouts; // 1=Mon..7=Sun

  @override
  void initState() {
    super.initState();
    final m = widget.existingMeso;
    if (m != null) {
      _nameController.text = m.name;
      _anchorDate = m.originalAnchor;
      _trainingWeeks = m.trainingWeeks;
      _restWeeks = m.restWeeks;
      _weekdayWorkouts = Map.from(m.weekdayWorkouts);
    } else {
      _anchorDate = mondayOf(DateTime.now());
      _trainingWeeks = 5;
      _restWeeks = 1;
      _weekdayWorkouts = {1: null, 2: null, 3: null, 4: null, 5: null, 6: null, 7: null};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    final workoutsAsync = ref.watch(workoutsProvider);
    final workouts = workoutsAsync.asData?.value ?? [];
    final workoutNames = {for (final w in workouts) w.id: w.name};

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            AppHeaderBar(
              title: widget.existingMeso != null ? 'Edit Mesocycle' : 'New Mesocycle',
              leading: AppIconButton(
                icon: Icons.close_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                children: [
                  // Name
                  _SectionLabel('NAME'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: displayStyle(fontSize: 18, color: c.ink),
                    decoration: InputDecoration(
                      hintText: 'e.g. Hypertrophy Block',
                      hintStyle: bodyStyle(color: c.inkMute),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Start date
                  _SectionLabel('START DATE'),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Anchor Monday',
                    value: _formatDate(_anchorDate),
                    onTap: () => _pickAnchorDate(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Snapped to the Monday of your chosen week.',
                      style: bodyStyle(fontSize: 12, color: c.inkMute),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Weeks
                  _SectionLabel('CYCLE LENGTH'),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Training weeks',
                    value: '$_trainingWeeks',
                    onTap: () => _showNumberPicker(
                      context,
                      title: 'Training weeks',
                      options: List.generate(12, (i) => '${i + 1} ${i == 0 ? "week" : "weeks"}'),
                      initialIndex: _trainingWeeks - 1,
                      onSelected: (i) => setState(() => _trainingWeeks = i + 1),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Rest weeks',
                    value: '$_restWeeks',
                    onTap: () => _showNumberPicker(
                      context,
                      title: 'Rest weeks',
                      options: List.generate(4, (i) => '${i + 1} ${i == 0 ? "week" : "weeks"}'),
                      initialIndex: _restWeeks - 1,
                      onSelected: (i) => setState(() => _restWeeks = i + 1),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Weekly schedule
                  _SectionLabel('WEEKLY SCHEDULE'),
                  const SizedBox(height: 8),
                  ...List.generate(7, (i) {
                    final weekday = i + 1;
                    final workoutId = _weekdayWorkouts[weekday];
                    final name = workoutId != null
                        ? (workoutNames[workoutId] ?? 'Unknown workout')
                        : 'Rest day';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _InfoRow(
                        label: _weekdayName(weekday),
                        value: name,
                        valueColor: workoutId != null
                            ? AppThemeData.of(context).c.accent
                            : null,
                        onTap: () => showWorkoutPicker(
                          context: context,
                          workouts: workouts,
                          selectedWorkoutId: workoutId,
                          onSelected: (id) =>
                              setState(() => _weekdayWorkouts[weekday] = id),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                12,
                22,
                24 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                children: [
                  AppButton(
                    label: widget.existingMeso != null
                        ? 'Save changes'
                        : 'Create mesocycle',
                    full: true,
                    onPressed: _save,
                  ),
                  if (widget.existingMeso != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _confirmDelete(context),
                      child: Text(
                        'Delete mesocycle',
                        style: bodyStyle(
                          fontSize: 14,
                          color: AppThemeData.of(context).c.danger,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAnchorDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _anchorDate = mondayOf(picked));
    }
  }

  void _showNumberPicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required int initialIndex,
    required void Function(int index) onSelected,
  }) {
    int selectedIdx = initialIndex;
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
          left: 22,
          right: 22,
          top: 20,
          bottom: 28 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Text(title,
                style: displayStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                    letterSpacing: -0.3)),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: CupertinoPicker(
                scrollController:
                    FixedExtentScrollController(initialItem: initialIndex),
                itemExtent: 44,
                onSelectedItemChanged: (i) => selectedIdx = i,
                children: options
                    .map((o) => Center(
                          child: Text(o,
                              style: bodyStyle(fontSize: 16, color: c.ink)),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Done',
              full: true,
              onPressed: () {
                Navigator.pop(ctx);
                onSelected(selectedIdx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final meso = (widget.existingMeso ?? Mesocycle(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      trainingWeeks: _trainingWeeks,
      restWeeks: _restWeeks,
      originalAnchor: _anchorDate,
      weekdayWorkouts: Map.from(_weekdayWorkouts),
      adjustments: const [],
    )).copyWith(
      name: name,
      trainingWeeks: _trainingWeeks,
      restWeeks: _restWeeks,
      originalAnchor: widget.existingMeso != null ? null : _anchorDate,
      weekdayWorkouts: Map.from(_weekdayWorkouts),
    );

    try {
      await ref.read(mesocyclesProvider.notifier).save(meso);
      await ref.read(activeMesoIdProvider.notifier).setActive(meso.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context) {
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
            Text('Delete mesocycle?',
                style: displayStyle(fontSize: 22, fontWeight: FontWeight.w500, color: c.ink, letterSpacing: -0.3)),
            const SizedBox(height: 10),
            Text(
              'This will permanently remove the mesocycle and all its overrides. This cannot be undone.',
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
                    label: 'Delete',
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref.read(mesocyclesProvider.notifier).delete(widget.existingMeso!.id);
                      if (mounted) Navigator.of(context).pop();
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

  String _formatDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${_weekdayName(d.weekday)}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _weekdayName(int weekday) => const [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
      ][weekday - 1];
}

// ─── Shared sub-widgets ────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    return Text(
      text,
      style: bodyStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: c.inkMute,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback onTap;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(kRadius - 4),
          boxShadow: cardShadow(AppThemeData.of(context).isDark),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: bodyStyle(fontSize: 14, color: c.inkDim)),
            ),
            Text(
              value,
              style: bodyStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor ?? c.ink,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 16, color: c.inkMute),
          ],
        ),
      ),
    );
  }
}
