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

    final dur = session.duration;
    final durLabel = _fmtDuration(dur);

    final completedSets =
        session.sets.where((s) => !s.skipped).length;
    final volumeKg = session.sets.fold<double>(
        0, (acc, s) => acc + s.actualReps * s.actualWeight);
    final volumeLabel = volumeKg >= 1000
        ? '${(volumeKg / 1000).toStringAsFixed(1)}t'
        : '${volumeKg.toStringAsFixed(0)}kg';

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              // ✓ + headline
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_rounded,
                        size: 24, color: c.accentInk),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Workout done!',
                    style: displayStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                session.workoutName,
                style: bodyStyle(fontSize: 15, color: c.inkDim),
              ),
              const SizedBox(height: 28),
              // Stats strip
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
                          value: durLabel,
                          label: 'duration',
                          leftBorder: false,
                        ),
                      ),
                      Expanded(
                        child: _StatCell(
                          value: '$completedSets',
                          label: 'sets',
                          leftBorder: true,
                        ),
                      ),
                      Expanded(
                        child: _StatCell(
                          value: volumeLabel,
                          label: 'volume',
                          leftBorder: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Cool-down reminder
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: c.hairlineSoft),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🧘', style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Remember to cool down',
                            style: bodyStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Stretch for 5–10 min to help recovery.',
                            style: bodyStyle(
                                fontSize: 13,
                                color: c.inkDim,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // TODO: calendar phase — next workout section
              // When scheduledWorkouts are available, surface the next
              // upcoming entry after today's date here.
              const Spacer(),
              AppButton(
                label: 'Back to workouts',
                full: true,
                icon: Icons.home_rounded,
                onPressed: () => Navigator.of(context)
                    .popUntil((route) => route.isFirst),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final bool leftBorder;

  const _StatCell({
    required this.value,
    required this.label,
    required this.leftBorder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
