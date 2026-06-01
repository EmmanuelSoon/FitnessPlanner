import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/providers/run_providers.dart';
import 'package:fitness_planner/data/run_repository.dart';
import 'package:fitness_planner/presentation/run_detail_screen.dart';
import 'package:fitness_planner/presentation/record_run_screen.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/services/health_service.dart';
import 'package:fitness_planner/theme/app_theme.dart';

class RunListScreen extends ConsumerStatefulWidget {
  const RunListScreen({super.key});

  @override
  ConsumerState<RunListScreen> createState() => _RunListScreenState();
}

class _RunListScreenState extends ConsumerState<RunListScreen> {
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final runsAsync = ref.watch(runsProvider);
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
              trailing: _syncing
                  ? SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.accent,
                          ),
                        ),
                      ),
                    )
                  : AppIconButton(
                      icon: Icons.sync_rounded,
                      onPressed: _syncFromHealthConnect,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Runs',
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
              child: runsAsync.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: c.accent)),
                error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: bodyStyle(color: c.danger))),
                data: (runs) => runs.isEmpty
                    ? _EmptyState(onRecord: _openRecord)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        itemCount: runs.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _RunCard(run: runs[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AppFab(onPressed: _openRecord),
    );
  }

  void _openRecord() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecordRunScreen()),
    );
  }

  Future<void> _syncFromHealthConnect() async {
    setState(() => _syncing = true);
    try {
      // Fetch the last 90 days by default.
      final since = DateTime.now().subtract(const Duration(days: 90));
      final imported = await HealthService.instance.fetchRuns(since: since);

      if (!mounted) return;

      // Persist only runs we haven't seen yet (dedup by id).
      final repo = ref.read(runRepositoryProvider);
      final notifier = ref.read(runsProvider.notifier);
      int added = 0;
      for (final run in imported) {
        if (!repo.exists(run.id)) {
          await notifier.saveRun(run);
          added++;
        }
      }

      if (!mounted) return;
      final c = AppThemeData.of(context).c;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: c.surface,
          content: Text(
            added == 0
                ? 'Already up to date.'
                : '$added run${added == 1 ? '' : 's'} imported.',
            style: bodyStyle(fontSize: 14, color: c.ink),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } on HealthServiceException catch (e) {
      if (!mounted) return;
      final c = AppThemeData.of(context).c;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: c.surface,
          content: Text(
            e.message,
            style: bodyStyle(fontSize: 14, color: c.danger),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final c = AppThemeData.of(context).c;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: c.surface,
          content: Text(
            'Sync failed: $e',
            style: bodyStyle(fontSize: 14, color: c.danger),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }
}

// ─── Empty state ───────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onRecord;
  const _EmptyState({required this.onRecord});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
            child: Icon(Icons.directions_run_rounded, size: 28, color: c.inkMute),
          ),
          const SizedBox(height: 18),
          Text(
            'No runs yet',
            style: displayStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: c.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a run manually or sync from your watch.',
            style: bodyStyle(fontSize: 14, color: c.inkDim, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Log a run',
            icon: Icons.add_rounded,
            onPressed: onRecord,
          ),
        ],
        ),
      ),
    );
  }
}

// ─── Run card ──────────────────────────────────────────────────────────
class _RunCard extends ConsumerWidget {
  final RunSession run;
  const _RunCard({required this.run});

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
    final dur = run.duration;
    final durStr = dur.inMinutes >= 60
        ? '${dur.inHours}h ${dur.inMinutes % 60}min'
        : '${dur.inMinutes}min';
    final distStr =
        '${run.distanceKm.toStringAsFixed(2)} km';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RunDetailScreen(run: run)),
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
                run.source == RunSource.healthConnect
                    ? Icons.watch_rounded
                    : Icons.directions_run_rounded,
                size: 22,
                color: c.accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _runTypeLabel(run.runType),
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
                        _formatDate(run.startedAt),
                        style: bodyStyle(
                            fontSize: 13,
                            color: c.inkDim,
                            letterSpacing: 0.1),
                      ),
                      Text(' · ',
                          style: bodyStyle(
                              fontSize: 13, color: c.inkMute, letterSpacing: 0)),
                      Text(
                        distStr,
                        style: bodyStyle(
                            fontSize: 13,
                            color: c.inkDim,
                            letterSpacing: 0.1),
                      ),
                      Text(' · ',
                          style: bodyStyle(
                              fontSize: 13, color: c.inkMute, letterSpacing: 0)),
                      Text(
                        durStr,
                        style: bodyStyle(
                            fontSize: 13,
                            color: c.inkDim,
                            letterSpacing: 0.1),
                      ),
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
            Icon(Icons.chevron_right_rounded, size: 18, color: c.inkMute),
          ],
        ),
      ),
    );
  }

  String _runTypeLabel(RunType t) {
    switch (t) {
      case RunType.easy:
        return 'Easy Run';
      case RunType.tempo:
        return 'Tempo Run';
      case RunType.interval:
        return 'Interval Run';
      case RunType.long:
        return 'Long Run';
      case RunType.race:
        return 'Race';
      case RunType.other:
        return 'Run';
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
                      await ref
                          .read(runsProvider.notifier)
                          .deleteRun(run.id);
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
