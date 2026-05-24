import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/providers/session_providers.dart';
import 'package:fitness_planner/presentation/session_detail_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sessions) => sessions.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) =>
                    _SessionCard(session: sessions[index]),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No sessions yet', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('Start a workout to see your history here.'),
        ],
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  final WorkoutSession session;
  const _SessionCard({required this.session});

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                session.workoutName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (!session.completed)
              Chip(
                label: const Text('Partial'),
                backgroundColor: Colors.orange.shade100,
              ),
          ],
        ),
        subtitle: Text(
          '${_formatDate(session.startedAt)} · ${session.duration.inMinutes}min',
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(session: session),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _confirmDelete(context, ref),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text('Remove this "${session.workoutName}" session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionsProvider.notifier).deleteSession(session.id);
    }
  }
}
