import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/providers/workout_providers.dart';
import 'package:fitness_planner/presentation/create_workout.dart';
import 'package:fitness_planner/presentation/workout_session_screen.dart';
import 'package:fitness_planner/presentation/history_screen.dart';

class WorkoutListScreen extends ConsumerWidget {
  const WorkoutListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Workouts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateWorkoutScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: workoutsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (workouts) => workouts.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                itemCount: workouts.length,
                itemBuilder: (context, index) =>
                    _WorkoutCard(workout: workouts[index]),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fitness_center, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No workouts yet', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateWorkoutScreen()),
            ),
            child: const Text('Create your first workout'),
          ),
        ],
      ),
    );
  }
}

class _WorkoutCard extends ConsumerWidget {
  final Workout workout;
  const _WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final durationMinutes = workout.totalDuration.inMinutes;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(workout.name,
            style: Theme.of(context).textTheme.headlineSmall),
        subtitle: Text(
            '${workout.exercises.length} exercises · ${durationMinutes}min · Tap to start'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkoutSessionScreen(workout: workout),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CreateWorkoutScreen(existingWorkout: workout),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete workout?'),
        content: Text('Are you sure you want to delete "${workout.name}"?'),
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
      await ref.read(workoutsProvider.notifier).deleteWorkout(workout.id);
    }
  }
}
