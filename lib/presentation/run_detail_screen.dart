import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/providers/run_providers.dart';
import 'package:fitness_planner/presentation/record_run_screen.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/theme/app_theme.dart';

class RunDetailScreen extends ConsumerWidget {
  final RunSession run;
  const RunDetailScreen({super.key, required this.run});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = (d.inMinutes % 60).toString().padLeft(2, '0');
      final s = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _runTypeLabel(RunType t) {
    switch (t) {
      case RunType.easy: return 'Easy';
      case RunType.tempo: return 'Tempo';
      case RunType.interval: return 'Interval';
      case RunType.long: return 'Long';
      case RunType.race: return 'Race';
      case RunType.other: return 'Run';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            AppHeaderBar(
              leading: AppIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.pop(context),
              ),
              trailing: AppIconButton(
                icon: Icons.edit_outlined,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecordRunScreen(existingRun: run),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 40),
                children: [
                  // Title area
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _runTypeLabel(run.runType),
                              style: displayStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w500,
                                color: c.ink,
                                letterSpacing: -0.6,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(run.startedAt),
                              style: bodyStyle(fontSize: 13, color: c.inkDim),
                            ),
                          ],
                        ),
                      ),
                      // Source badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              run.source == RunSource.healthConnect
                                  ? Icons.watch_rounded
                                  : Icons.edit_note_rounded,
                              size: 12,
                              color: c.inkDim,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              run.source == RunSource.healthConnect
                                  ? 'Watch'
                                  : 'Manual',
                              style: bodyStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: c.inkDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Primary stats grid
                  _StatsGrid(run: run, c: c, isDark: isDark),
                  const SizedBox(height: 16),

                  // Time info
                  _InfoRow(
                    label: 'Start time',
                    value: _formatTime(run.startedAt),
                    c: c,
                    isDark: isDark,
                  ),
                  _InfoRow(
                    label: 'Duration',
                    value: _formatDuration(run.duration),
                    c: c,
                    isDark: isDark,
                  ),

                  // Optional fields
                  if (run.avgHeartRate != null)
                    _InfoRow(
                      label: 'Avg heart rate',
                      value: '${run.avgHeartRate} bpm',
                      c: c,
                      isDark: isDark,
                    ),
                  if (run.calories != null)
                    _InfoRow(
                      label: 'Calories',
                      value: '${run.calories!.round()} kcal',
                      c: c,
                      isDark: isDark,
                    ),
                  if (run.cadenceSpm != null)
                    _InfoRow(
                      label: 'Cadence',
                      value: '${run.cadenceSpm} spm',
                      c: c,
                      isDark: isDark,
                    ),
                  if (run.notes != null && run.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Notes',
                      style: bodyStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.inkMute,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(kRadius),
                        border: Border.all(color: c.hairlineSoft),
                      ),
                      child: Text(
                        run.notes!,
                        style: bodyStyle(
                            fontSize: 14, color: c.inkDim, height: 1.6),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  AppButton(
                    label: 'Delete run',
                    kind: ButtonKind.dangerOutline,
                    icon: Icons.delete_outline_rounded,
                    full: true,
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final c = AppThemeData.of(context).c;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(kRadius + 8)),
        ),
        padding: EdgeInsets.fromLTRB(
            22, 20, 22, 28 + MediaQuery.of(context).padding.bottom),
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
              'Delete run?',
              style: displayStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: c.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This run record will be permanently removed from this device.',
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
                    kind: ButtonKind.danger,
                    icon: Icons.delete_outline_rounded,
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref.read(runsProvider.notifier).deleteRun(run.id);
                      if (context.mounted) Navigator.pop(context);
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
}

// ─── Primary stats grid ────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final RunSession run;
  final AppColors c;
  final bool isDark;

  const _StatsGrid({required this.run, required this.c, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatBox(
          label: 'Distance',
          value: run.distanceKm.toStringAsFixed(2),
          unit: 'km',
          c: c,
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _StatBox(
          label: 'Pace',
          value: run.formattedPace,
          unit: '/km',
          c: c,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final AppColors c;
  final bool isDark;

  const _StatBox({
    required this.label,
    required this.value,
    required this.unit,
    required this.c,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(kRadius),
          boxShadow: cardShadow(isDark),
          border: isDark ? Border.all(color: c.hairlineSoft) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: bodyStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: c.inkMute,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: displayStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                      letterSpacing: -0.8,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: bodyStyle(fontSize: 13, color: c.inkDim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info row ──────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final AppColors c;
  final bool isDark;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.c,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bodyStyle(fontSize: 14, color: c.inkDim)),
          Text(value,
              style: bodyStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.ink,
              )),
        ],
      ),
    );
  }
}
