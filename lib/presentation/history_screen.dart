import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/providers/session_providers.dart';
import 'package:fitness_planner/presentation/session_detail_screen.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/theme/app_theme.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);
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
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'History',
                    style: displayStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                      letterSpacing: -1.2,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: sessionsAsync.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: c.accent)),
                error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: bodyStyle(color: c.danger))),
                data: (sessions) => sessions.isEmpty
                    ? _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        itemCount: sessions.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _SessionCard(session: sessions[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.hairline, width: 1.5),
            ),
            child:
                Icon(Icons.history_rounded, size: 28, color: c.inkMute),
          ),
          const SizedBox(height: 18),
          Text(
            'No sessions yet',
            style: displayStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: c.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a workout to see your history here.',
            style: bodyStyle(fontSize: 14, color: c.inkDim, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  final WorkoutSession session;
  const _SessionCard({required this.session});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final dur = session.duration.inMinutes;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SessionDetailScreen(session: session)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(kRadius),
          border: theme.isDark ? Border.all(color: c.hairlineSoft) : null,
          boxShadow: cardShadow(theme.isDark),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            // Icon tile
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(
                    (kRadius - 8).clamp(8.0, double.infinity)),
              ),
              child: Icon(
                session.completed
                    ? Icons.check_circle_outline_rounded
                    : Icons.timelapse_rounded,
                size: 22,
                color: session.completed ? c.accent : c.inkMute,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.workoutName,
                    style: displayStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        _formatDate(session.startedAt),
                        style: bodyStyle(
                            fontSize: 13,
                            color: c.inkDim,
                            letterSpacing: 0.1),
                      ),
                      Text(' · ',
                          style: bodyStyle(
                              fontSize: 13,
                              color: c.inkMute,
                              letterSpacing: 0)),
                      Text(
                        '${dur}min',
                        style: bodyStyle(
                            fontSize: 13,
                            color: c.inkDim,
                            letterSpacing: 0.1),
                      ),
                      if (!session.completed) ...[
                        Text(' · ',
                            style: bodyStyle(
                                fontSize: 13,
                                color: c.inkMute,
                                letterSpacing: 0)),
                        Text(
                          'partial',
                          style: bodyStyle(
                            fontSize: 13,
                            color: c.inkMute,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Delete button
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: c.inkMute),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: c.inkMute),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref) async {
    final theme = AppThemeData.of(context);
    final c = theme.c;

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
              'Delete session?',
              style: displayStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: c.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Remove this "${session.workoutName}" session from your history?',
              style: bodyStyle(
                  fontSize: 14, color: c.inkDim, height: 1.5),
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
                      await ref
                          .read(sessionsProvider.notifier)
                          .deleteSession(session.id);
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
