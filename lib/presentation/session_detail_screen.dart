import 'package:flutter/material.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';

class SessionDetailScreen extends StatelessWidget {
  final WorkoutSession session;
  const SessionDetailScreen({super.key, required this.session});

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(session.workoutName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_formatDate(session.startedAt)} · ${session.duration.inMinutes}min'
                '${session.completed ? '' : ' · Partial'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
      body: session.sets.isEmpty
          ? const Center(child: Text('No sets logged.'))
          : ListView.builder(
              itemCount: session.sets.length,
              itemBuilder: (context, index) =>
                  _SetTile(setNumber: index + 1, logged: session.sets[index]),
            ),
    );
  }
}

class _SetTile extends StatelessWidget {
  final int setNumber;
  final LoggedSet logged;
  const _SetTile({required this.setNumber, required this.logged});

  String _repsWeight(int reps, double weight) {
    final base = '$reps reps';
    return weight > 0 ? '$base × ${weight}kg' : base;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: logged.skipped ? Colors.grey.shade300 : null,
        child: Text('$setNumber'),
      ),
      title: Text(
        logged.exerciseName,
        style: logged.skipped
            ? TextStyle(color: Theme.of(context).disabledColor)
            : null,
      ),
      subtitle: logged.skipped
          ? null
          : Text(
              'Target: ${_repsWeight(logged.targetReps, logged.targetWeight)}'
              '  →  '
              '${_repsWeight(logged.actualReps, logged.actualWeight)}',
            ),
      trailing: logged.skipped
          ? Chip(
              label: const Text('Skipped'),
              backgroundColor: Colors.grey.shade200,
            )
          : null,
    );
  }
}
