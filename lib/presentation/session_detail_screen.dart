import 'package:flutter/material.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/theme/app_theme.dart';

class SessionDetailScreen extends StatelessWidget {
  final WorkoutSession session;
  const SessionDetailScreen({super.key, required this.session});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.workoutName,
                    style: displayStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        _formatDate(session.startedAt),
                        style: bodyStyle(
                            fontSize: 13, color: c.inkDim),
                      ),
                      Text(' · ',
                          style: bodyStyle(
                              fontSize: 13, color: c.inkMute)),
                      Text(
                        '${session.duration.inMinutes}min',
                        style: bodyStyle(
                            fontSize: 13, color: c.inkDim),
                      ),
                      if (!session.completed) ...[
                        Text(' · ',
                            style: bodyStyle(
                                fontSize: 13, color: c.inkMute)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.surfaceAlt,
                            borderRadius:
                                BorderRadius.circular(100),
                          ),
                          child: Text(
                            'Partial',
                            style: bodyStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.inkDim,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: session.sets.isEmpty
                  ? Center(
                      child: Text('No sets logged.',
                          style: bodyStyle(
                              fontSize: 14, color: c.inkMute)),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: session.sets.length,
                      itemBuilder: (context, index) => _SetTile(
                        setNumber: index + 1,
                        logged: session.sets[index],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetTile extends StatelessWidget {
  final int setNumber;
  final LoggedSet logged;
  const _SetTile({required this.setNumber, required this.logged});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: c.hairlineSoft),
      ),
      child: Row(
        children: [
          // Set number circle
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: logged.skipped ? c.surfaceAlt : c.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$setNumber',
              style: bodyStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: logged.skipped ? c.inkMute : c.accentInk,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  logged.exerciseName,
                  style: bodyStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: logged.skipped ? c.inkMute : c.ink,
                  ),
                ),
                if (!logged.skipped) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Target: ${logged.targetReps} × ${logged.targetWeight}kg'
                    '  →  '
                    '${logged.actualReps} × ${logged.actualWeight}kg',
                    style: bodyStyle(
                      fontSize: 12,
                      color: c.inkDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (logged.skipped)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Skipped',
                style: bodyStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: c.inkMute,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
