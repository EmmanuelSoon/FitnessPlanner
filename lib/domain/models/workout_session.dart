import 'logged_set.dart';

class WorkoutSession {
  final String id;
  final String workoutId;
  final String workoutName;
  final DateTime startedAt;
  final DateTime endedAt;
  final bool completed;
  final List<LoggedSet> sets;

  WorkoutSession({
    required this.id,
    required this.workoutId,
    required this.workoutName,
    required this.startedAt,
    required this.endedAt,
    required this.completed,
    required this.sets,
  });

  Duration get duration => endedAt.difference(startedAt);

  Map<String, dynamic> toJson() => {
    'id': id,
    'workoutId': workoutId,
    'workoutName': workoutName,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'completed': completed,
    'sets': sets.map((s) => s.toJson()).toList(),
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: json['id'] as String,
    workoutId: json['workoutId'] as String,
    workoutName: json['workoutName'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    endedAt: DateTime.parse(json['endedAt'] as String),
    completed: json['completed'] as bool,
    sets: (json['sets'] as List)
        .map((s) => LoggedSet.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}
