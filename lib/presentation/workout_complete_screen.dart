import 'package:flutter/material.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/theme/app_theme.dart';

class WorkoutCompleteScreen extends StatelessWidget {
  final WorkoutSession session;
  const WorkoutCompleteScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    final duration = session.duration;
    final durationStr = _fmtDuration(duration);
    final totalSets = session.sets.where((s) => !s.skipped).length;
    final totalVolKg = session.sets.fold<double>(
      0,
      (a, s) => a + s.actualReps * s.actualWeight,
    );
    final volStr = totalVolKg >= 1000
        ? '${(totalVolKg / 1000).toStringAsFixed(1)}t'
        : '${totalVolKg.toStringAsFixed(0)}kg';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) {},
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 40, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Checkmark ──────────────────────────────────────
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 36,
                          color: c.accentInk,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Workout done!',
                        style: displayStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          color: c.ink,
                          letterSpacing: -0.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.workoutName,
                        style: bodyStyle(
                          fontSize: 15,
                          color: c.inkDim,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // ── Stats row ──────────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(kRadius),
                          border: Border.all(color: c.hairlineSoft),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatCell(
                                  value: durationStr,
                                  label: 'Duration',
                                  leftBorder: false,
                                  c: c,
                                ),
                              ),
                              Expanded(
                                child: _StatCell(
                                  value: '$totalSets',
                                  label: 'Sets',
                                  leftBorder: true,
                                  c: c,
                                ),
                              ),
                              Expanded(
                                child: _StatCell(
                                  value: volStr,
                                  label: 'Volume',
                                  leftBorder: true,
                                  c: c,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Cool down reminder ─────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(kRadius),
                          border: Border.all(color: c.hairlineSoft),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('🧘', style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Text(
                                  'Remember to cool down',
                                  style: bodyStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: c.ink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: Text(
                                'Stretch for 5–10 minutes to aid recovery.',
                                style: bodyStyle(
                                  fontSize: 13,
                                  color: c.inkDim,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // TODO: calendar phase — next workout slot goes here
                    ],
                  ),
                ),
              ),

              // ── Bottom CTA ─────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  18, 0, 18, 16 + MediaQuery.of(context).padding.bottom,
                ),
                child: AppButton(
                  label: 'Back to workouts',
                  full: true,
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final bool leftBorder;
  final AppColors c;

  const _StatCell({
    required this.value,
    required this.label,
    required this.leftBorder,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        border: leftBorder
            ? Border(left: BorderSide(color: c.hairlineSoft))
            : null,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: displayStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: c.ink,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: bodyStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: c.inkMute,
              letterSpacing: 0.8,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
