import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/insights/personal_records.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/presentation/widgets/pr_card.dart';
import 'package:fitness_planner/providers/session_providers.dart';
import 'package:fitness_planner/theme/app_theme.dart';

/// The full personal-records list, reached via "See all" from the Insights
/// tab's "Recent records" section.
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  // Memoized on the sessions list's identity, matching InsightsScreen's
  // cache — a route-transition rebuild (or any unrelated ancestor rebuild)
  // would otherwise re-scan every session on every frame.
  List<WorkoutSession>? _cachedSessions;
  List<PersonalRecord>? _cachedRecords;

  List<PersonalRecord> _recordsFor(List<WorkoutSession> sessions) {
    if (!identical(_cachedSessions, sessions)) {
      _cachedSessions = sessions;
      _cachedRecords = computePersonalRecords(sessions, const []);
    }
    return _cachedRecords!;
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Records',
                    style: displayStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: sessionsAsync.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: c.accent)),
                error: (e, _) =>
                    Center(child: Text('Error: $e', style: bodyStyle(color: c.danger))),
                data: (sessions) {
                  final records = _recordsFor(sessions);
                  return records.isEmpty ? const _EmptyState() : _Body(records: records);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final List<PersonalRecord> records;
  const _Body({required this.records});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        for (final record in records) ...[
          PRCard(record: record),
          const SizedBox(height: 10),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(
            'Records are detected as you log sets — nothing to set up. '
            'Estimated 1RM uses Epley from your heaviest completed set.',
            style: bodyStyle(fontSize: 11, color: c.inkDim, height: 1.6),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
            child: Icon(Icons.emoji_events_rounded, size: 28, color: c.inkMute),
          ),
          const SizedBox(height: 18),
          Text(
            'No records yet',
            style: displayStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: c.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Log a set to start setting personal bests.',
            style: bodyStyle(fontSize: 14, color: c.inkDim, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
