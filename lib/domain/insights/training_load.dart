import 'package:fitness_planner/domain/insights/volume_stats.dart' show weekStartOf;
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
      if (set.skipped) continue;
      if (set.category != null) continue;
      if (_libraryCategoryByNormalizedName.containsKey(_normalize(set.exerciseName))) continue;
      names.add(set.exerciseName);
    }
  }
  return names;
}

/// One category's load for one week: [workingSets] is the plan's definition
/// of a working set (performed, non-skipped, non-timed); timed holds are
/// counted separately in [timedSets] and never folded into [workingSets] — a
/// plank is not a set of squats. [exerciseCount] is the number of distinct
/// exercise names logged in this category that week, not a set count.
class CategoryLoad {
  final String category;
  final int workingSets;
  final int timedSets;
  final int exerciseCount;

  const CategoryLoad({
    required this.category,
    required this.workingSets,
    required this.timedSets,
    required this.exerciseCount,
  });
}

/// One calendar week's training load, broken down by muscle group.
/// [isPartial] is true only for the week containing "now" — it hasn't fully
/// elapsed yet, so it must never be folded into a trailing mean (see
/// [compareToTrailing]).
class WeekLoad {
  final DateTime weekStart;
  final Map<String, CategoryLoad> byCategory;
  final int totalWorkingSets;
  final int sessionCount;
  final bool isPartial;

  const WeekLoad({
    required this.weekStart,
    required this.byCategory,
    required this.totalWorkingSets,
    required this.sessionCount,
    required this.isPartial,
  });
}

class _CategoryAccumulator {
  int workingSets = 0;
  int timedSets = 0;
  final Set<String> exerciseNames = {};
}

WeekLoad _buildWeekLoad(DateTime weekStart, List<WorkoutSession> sessions, {required bool isPartial}) {
  final acc = <String, _CategoryAccumulator>{};
  for (final session in sessions) {
    for (final set in session.sets) {
      if (set.skipped) continue;
      final entry = acc.putIfAbsent(resolveCategory(set), () => _CategoryAccumulator());
      entry.exerciseNames.add(set.exerciseName);
      if (set.heldSeconds != null) {
        entry.timedSets++;
      } else {
        entry.workingSets++;
      }
    }
  }

  final byCategory = {
    for (final e in acc.entries)
      e.key: CategoryLoad(
        category: e.key,
        workingSets: e.value.workingSets,
        timedSets: e.value.timedSets,
        exerciseCount: e.value.exerciseNames.length,
      ),
  };

  return WeekLoad(
    weekStart: weekStart,
    byCategory: byCategory,
    totalWorkingSets: byCategory.values.fold(0, (sum, c) => sum + c.workingSets),
    sessionCount: sessions.length,
    isPartial: isPartial,
  );
}

/// One [WeekLoad] bucket per week for the last [weeks] weeks, chronological,
/// ending with the week containing [now] (defaults to the current time).
/// Weeks with no logged sessions are included with zeroed figures, mirroring
/// [weeklyVolume]'s convention of never skipping a bucket.
List<WeekLoad> weeklyTrainingLoad(
  List<WorkoutSession> sessions, {
  int weeks = 8,
  DateTime? now,
}) {
  final currentWeekStart = weekStartOf(now ?? DateTime.now());
  final bucketStarts = [
    for (var i = weeks - 1; i >= 0; i--)
      DateTime(
        currentWeekStart.year,
        currentWeekStart.month,
        currentWeekStart.day - 7 * i,
      ),
  ];

  final sessionsByWeek = <DateTime, List<WorkoutSession>>{
    for (final start in bucketStarts) start: [],
  };
  for (final session in sessions) {
    sessionsByWeek[weekStartOf(session.startedAt)]?.add(session);
  }

  return [
    for (final start in bucketStarts)
      _buildWeekLoad(start, sessionsByWeek[start]!, isPartial: start == currentWeekStart),
  ];
}

enum LoadBand { light, typical, heavy, unknown }

/// One category's current-week load against its trailing baseline.
/// [trailingMean] and a real [band] require at least two completed prior
/// weeks of data; below that the band is [LoadBand.unknown] and the mean is
/// null rather than a guess from a single noisy week.
class CategoryLoadComparison {
  final String category;
  final int workingSets;
  final double? trailingMean;
  final LoadBand band;

  const CategoryLoadComparison({
    required this.category,
    required this.workingSets,
    required this.trailingMean,
    required this.band,
  });
}

const double _kLoadBandTolerance = 0.25;
const int _kMinTrailingWeeks = 2;

CategoryLoadComparison _compareCategory(String category, WeekLoad current, List<WeekLoad> trailing) {
  final workingSets = current.byCategory[category]?.workingSets ?? 0;
  if (trailing.length < _kMinTrailingWeeks) {
    return CategoryLoadComparison(
      category: category,
      workingSets: workingSets,
      trailingMean: null,
      band: LoadBand.unknown,
    );
  }

  final mean = trailing
          .map((w) => w.byCategory[category]?.workingSets ?? 0)
          .reduce((a, b) => a + b) /
      trailing.length;

  final LoadBand band;
  if (workingSets < mean * (1 - _kLoadBandTolerance)) {
    band = LoadBand.light;
  } else if (workingSets > mean * (1 + _kLoadBandTolerance)) {
    band = LoadBand.heavy;
  } else {
    band = LoadBand.typical;
  }

  return CategoryLoadComparison(category: category, workingSets: workingSets, trailingMean: mean, band: band);
}

/// Compares [weeks]' last entry (the current week, in progress) against the
/// trailing mean of up to [trailingWeeks] prior *completed* weeks — the
/// in-progress week is never part of its own baseline, or every Wednesday
/// would read "light". Covers every category seen in either the current week
/// or the trailing window, so a muscle group trained regularly but skipped
/// this week still shows up (at zero) rather than silently disappearing.
List<CategoryLoadComparison> compareToTrailing(
  List<WeekLoad> weeks, {
  int trailingWeeks = 4,
}) {
  if (weeks.isEmpty) return [];
  final current = weeks.last;
  final completed = weeks.sublist(0, weeks.length - 1).where((w) => !w.isPartial).toList();
  final trailing = completed.length > trailingWeeks
      ? completed.sublist(completed.length - trailingWeeks)
      : completed;

  final categories = <String>{
    ...current.byCategory.keys,
    for (final w in trailing) ...w.byCategory.keys,
  };

  return [for (final category in categories) _compareCategory(category, current, trailing)];
}
