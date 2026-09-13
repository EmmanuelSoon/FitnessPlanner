import 'package:fitness_planner/domain/models/exercise_library.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

const String kUncategorized = 'Other';

String _normalize(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Exact normalised-name lookup only — no fuzzy matching. "Close-Grip Bench
/// Press" is Arms while "Bench Press" is Chest, so substring or edit-distance
/// matching would silently reclassify one as the other.
final Map<String, String> _libraryCategoryByNormalizedName = {
  for (final e in kExerciseLibrary) _normalize(e.name): e.category,
};

/// A set's muscle-group tag: whatever was manually recorded on it, else a
/// library lookup by exact normalised name, else [kUncategorized].
String resolveCategory(LoggedSet set) =>
    set.category ??
    _libraryCategoryByNormalizedName[_normalize(set.exerciseName)] ??
    kUncategorized;

/// Exercise names that fell all the way through to [kUncategorized] because
/// they were never manually tagged and don't match anything in the library —
/// worth prompting the user to tag rather than showing a mystery "Other" bar.
/// A set the user deliberately tagged "Other" themselves is not included.
Set<String> unmatchedExerciseNames(List<WorkoutSession> sessions) {
  final names = <String>{};
  for (final session in sessions) {
    for (final set in session.sets) {
      if (set.category != null) continue;
      if (_libraryCategoryByNormalizedName.containsKey(_normalize(set.exerciseName))) continue;
      names.add(set.exerciseName);
    }
  }
  return names;
}
