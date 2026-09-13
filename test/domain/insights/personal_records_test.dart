import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/insights/personal_records.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

WorkoutSession _session({
  required String id,
  required DateTime startedAt,
  String workoutName = 'Push Day',
  required List<LoggedSet> sets,
}) =>
    WorkoutSession(
      id: id,
      workoutId: 'w1',
      workoutName: workoutName,
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(hours: 1)),
      completed: true,
      sets: sets,
    );

LoggedSet _weighted({
  String exercise = 'Bench Press',
  double weight = 60,
  int reps = 8,
  bool skipped = false,
}) =>
    LoggedSet(
      exerciseName: exercise,
      targetReps: reps,
      targetWeight: weight,
      actualReps: reps,
      actualWeight: weight,
      skipped: skipped,
    );

LoggedSet _bodyweight({String exercise = 'Push-up', int reps = 12, bool skipped = false}) =>
    LoggedSet(
      exerciseName: exercise,
      targetReps: reps,
      targetWeight: 0,
      actualReps: reps,
      actualWeight: 0,
      skipped: skipped,
    );

LoggedSet _timed({String exercise = 'Plank', int heldSeconds = 30}) => LoggedSet(
      exerciseName: exercise,
      targetReps: 0,
      targetWeight: 0,
      actualReps: 0,
      actualWeight: 0,
      skipped: false,
      heldSeconds: heldSeconds,
      targetSeconds: heldSeconds,
    );

PersonalRecord _find(List<PersonalRecord> records, PersonalRecordType type, [String? label]) =>
    records.firstWhere((r) => r.type == type && (label == null || r.label == label));

void main() {
  group('computePersonalRecords', () {
    test('returns nothing for no sessions or runs', () {
      expect(computePersonalRecords([], []), isEmpty);
    });

    test('a single weighted set sets a heaviest-weight PR with no previous value', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [_weighted(weight: 60, reps: 8)],
      );

      final record = _find(
        computePersonalRecords([session], []),
        PersonalRecordType.heaviestWeight,
      );

      expect(record.label, 'Bench Press');
      expect(record.value, 60);
      expect(record.reps, 8);
      expect(record.previousValue, isNull);
      expect(record.achievedAt, DateTime(2026, 3, 1));
      expect(record.sessionId, 's1');
    });

    test('a heavier later set replaces the record and carries the old value as previousValue', () {
      final earlier = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [_weighted(weight: 60, reps: 8)],
      );
      final later = _session(
        id: 's2',
        startedAt: DateTime(2026, 3, 8),
        sets: [_weighted(weight: 65, reps: 5)],
      );

      final record = _find(
        computePersonalRecords([later, earlier], []),
        PersonalRecordType.heaviestWeight,
      );

      expect(record.value, 65);
      expect(record.reps, 5);
      expect(record.previousValue, 60);
      expect(record.achievedAt, DateTime(2026, 3, 8));
      expect(record.sessionId, 's2');
    });

    test('a lighter later set does not override the standing record', () {
      final heavy = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [_weighted(weight: 65, reps: 5)],
      );
      final light = _session(
        id: 's2',
        startedAt: DateTime(2026, 3, 8),
        sets: [_weighted(weight: 60, reps: 8)],
      );

      final record = _find(
        computePersonalRecords([heavy, light], []),
        PersonalRecordType.heaviestWeight,
      );

      expect(record.value, 65);
      expect(record.achievedAt, DateTime(2026, 3, 1));
      expect(record.sessionId, 's1');
    });

    test('tracks heaviest-weight PRs separately per exercise', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [
          _weighted(exercise: 'Bench Press', weight: 60, reps: 8),
          _weighted(exercise: 'Squat', weight: 100, reps: 5),
        ],
      );

      final records = computePersonalRecords([session], []);

      expect(_find(records, PersonalRecordType.heaviestWeight, 'Bench Press').value, 60);
      expect(_find(records, PersonalRecordType.heaviestWeight, 'Squat').value, 100);
    });

    test('most-reps only considers bodyweight sets (zero actual weight)', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [
          _bodyweight(exercise: 'Push-up', reps: 20),
          _weighted(exercise: 'Bench Press', weight: 60, reps: 30),
        ],
      );

      final records = computePersonalRecords([session], []);

      final mostReps = _find(records, PersonalRecordType.mostReps, 'Push-up');
      expect(mostReps.value, 20);
      expect(records.any((r) => r.type == PersonalRecordType.mostReps && r.label == 'Bench Press'),
          isFalse);
    });

    test('longest-hold only considers timed sets', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [_timed(exercise: 'Plank', heldSeconds: 90)],
      );

      final record = _find(
        computePersonalRecords([session], []),
        PersonalRecordType.longestHold,
        'Plank',
      );

      expect(record.value, 90);
    });

    test('timed sets contribute to no other record type', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [_timed(exercise: 'Plank', heldSeconds: 90)],
      );

      final records = computePersonalRecords([session], []);

      expect(
        records.where((r) => r.label == 'Plank').map((r) => r.type),
        [PersonalRecordType.longestHold],
      );
    });

    test('best estimated 1RM uses the Epley formula over weighted sets', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [_weighted(exercise: 'Deadlift', weight: 100, reps: 6)],
      );

      final record = _find(
        computePersonalRecords([session], []),
        PersonalRecordType.bestEst1Rm,
        'Deadlift',
      );

      expect(record.value, 100 * (1 + 6 / 30));
    });

    test('a genuine one-rep single is reported as itself, not inflated by Epley', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [_weighted(exercise: 'Deadlift', weight: 100, reps: 1)],
      );

      final record = _find(
        computePersonalRecords([session], []),
        PersonalRecordType.bestEst1Rm,
        'Deadlift',
      );

      expect(record.value, 100);
    });

    test('a set above the 12-rep validity cap sets no bestEst1Rm record', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [_weighted(exercise: 'Deadlift', weight: 60, reps: 20)],
      );

      final records = computePersonalRecords([session], []);

      expect(records.any((r) => r.type == PersonalRecordType.bestEst1Rm), isFalse);
      // The set still counts for heaviest-weight — only the 1RM estimate is excluded.
      expect(_find(records, PersonalRecordType.heaviestWeight, 'Deadlift').value, 60);
    });

    test('session tonnage tracks the single best session total, labeled by workout name', () {
      final small = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        workoutName: 'Pull Day',
        sets: [_weighted(weight: 40, reps: 10)],
      );
      final big = _session(
        id: 's2',
        startedAt: DateTime(2026, 3, 8),
        workoutName: 'Chest & Triceps',
        sets: [_weighted(weight: 60, reps: 10), _weighted(weight: 60, reps: 10)],
      );

      final record = _find(
        computePersonalRecords([small, big], []),
        PersonalRecordType.sessionTonnage,
      );

      expect(record.value, 60 * 10 * 2);
      expect(record.previousValue, 40 * 10);
      expect(record.label, 'Chest & Triceps');
      expect(record.sessionId, 's2');
    });

    test('skipped sets are excluded from every record type', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [_weighted(exercise: 'Bench Press', weight: 60, reps: 8, skipped: true)],
      );

      expect(computePersonalRecords([session], []), isEmpty);
    });

    test('a single run sets a fastest-pace PR with no previous value', () {
      final run = RunSession(
        id: 'r1',
        startedAt: DateTime(2026, 3, 1),
        endedAt: DateTime(2026, 3, 1, 0, 30),
        distanceMeters: 5000, // 30min / 5km = 360s/km
      );

      final record = _find(
        computePersonalRecords([], [run]),
        PersonalRecordType.fastestPace,
      );

      expect(record.value, 360);
      expect(record.previousValue, isNull);
      expect(record.achievedAt, DateTime(2026, 3, 1));
      expect(record.sessionId, 'r1');
    });

    test('a faster later run replaces the fastest-pace record', () {
      final slow = RunSession(
        id: 'r1',
        startedAt: DateTime(2026, 3, 1),
        endedAt: DateTime(2026, 3, 1, 0, 30),
        distanceMeters: 5000, // 360s/km
      );
      final fast = RunSession(
        id: 'r2',
        startedAt: DateTime(2026, 3, 8),
        endedAt: DateTime(2026, 3, 8, 0, 20),
        distanceMeters: 5000, // 240s/km
      );

      final record = _find(
        computePersonalRecords([], [fast, slow]),
        PersonalRecordType.fastestPace,
      );

      expect(record.value, 240);
      expect(record.previousValue, 360);
      expect(record.sessionId, 'r2');
    });

    test('a slower later run does not override the standing fastest-pace record', () {
      final fast = RunSession(
        id: 'r1',
        startedAt: DateTime(2026, 3, 1),
        endedAt: DateTime(2026, 3, 1, 0, 20),
        distanceMeters: 5000, // 240s/km
      );
      final slow = RunSession(
        id: 'r2',
        startedAt: DateTime(2026, 3, 8),
        endedAt: DateTime(2026, 3, 8, 0, 30),
        distanceMeters: 5000, // 360s/km
      );

      final record = _find(
        computePersonalRecords([], [fast, slow]),
        PersonalRecordType.fastestPace,
      );

      expect(record.value, 240);
      expect(record.sessionId, 'r1');
    });

    test('a zero-distance run has no pace and is excluded from the fastest-pace record', () {
      final run = RunSession(
        id: 'r1',
        startedAt: DateTime(2026, 3, 1),
        endedAt: DateTime(2026, 3, 1, 0, 30),
        distanceMeters: 0,
      );

      expect(computePersonalRecords([], [run]), isEmpty);
    });

    test('orders records newest-achieved first', () {
      final earlier = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [_weighted(exercise: 'Bench Press', weight: 60, reps: 8)],
      );
      final later = _session(
        id: 's2',
        startedAt: DateTime(2026, 3, 8),
        sets: [_weighted(exercise: 'Squat', weight: 100, reps: 5)],
      );

      final records = computePersonalRecords([earlier, later], []);

      expect(records.first.achievedAt, DateTime(2026, 3, 8));
      expect(records.last.achievedAt, DateTime(2026, 3, 1));
    });

    test('breaks ties on the same achievedAt deterministically, by type then label', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [
          _weighted(exercise: 'Squat', weight: 100, reps: 5),
          _weighted(exercise: 'Bench Press', weight: 60, reps: 8),
          _bodyweight(exercise: 'Push-up', reps: 15),
        ],
      );

      // Every record here shares the same achievedAt (the one session), so
      // this ordering must come entirely from the type/label tie-break —
      // not from map-iteration order, which isn't guaranteed to repeat.
      final order = computePersonalRecords([session], [])
          .map((r) => (r.type, r.label))
          .toList();

      expect(order, [
        (PersonalRecordType.heaviestWeight, 'Bench Press'),
        (PersonalRecordType.heaviestWeight, 'Squat'),
        (PersonalRecordType.mostReps, 'Push-up'),
        (PersonalRecordType.bestEst1Rm, 'Bench Press'),
        (PersonalRecordType.bestEst1Rm, 'Squat'),
        (PersonalRecordType.sessionTonnage, 'Push Day'),
      ]);
    });
  });

  group('recordsSetInSession', () {
    test('returns the records a session claimed, in the middle of other sessions\' records', () {
      final earlier = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [_weighted(weight: 60, reps: 8)],
      );
      final later = _session(
        id: 's2',
        startedAt: DateTime(2026, 3, 8),
        sets: [_weighted(weight: 65, reps: 8)],
      );

      final all = computePersonalRecords([earlier, later], []);
      final setInLater = recordsSetInSession(all, 's2');

      // heaviestWeight + bestEst1Rm + sessionTonnage all move to the
      // heavier, higher-volume later session.
      expect(setInLater, hasLength(3));
      expect(setInLater.every((r) => r.sessionId == 's2'), isTrue);
    });

    test('returns empty when the session set no new record', () {
      final earlier = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 1),
        sets: [_weighted(weight: 65, reps: 8)],
      );
      final later = _session(
        id: 's2',
        startedAt: DateTime(2026, 3, 8),
        sets: [_weighted(weight: 60, reps: 5)],
      );

      final all = computePersonalRecords([earlier, later], []);

      expect(recordsSetInSession(all, 's2'), isEmpty);
    });

    test('returns empty for a session id with no records at all', () {
      expect(recordsSetInSession([], 'nonexistent'), isEmpty);
    });
  });
}
