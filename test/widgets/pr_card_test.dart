import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/insights/personal_records.dart';
import 'package:fitness_planner/presentation/widgets/pr_card.dart';

import '../support/pump_app.dart';

void main() {
  final record = PersonalRecord(
    type: PersonalRecordType.mostReps,
    label: 'Pull-up',
    value: 14,
    achievedAt: DateTime(2026, 1, 5),
    sessionId: 'ws1',
  );

  testWidgets('shows "Just now" when justNow is true, regardless of achievedAt', (tester) async {
    await pumpApp(
      tester,
      PRCard(record: record, justNow: true, now: DateTime(2026, 3, 1)),
    );

    expect(find.textContaining('Just now'), findsOneWidget);
    expect(find.textContaining('ago'), findsNothing);
  });

  testWidgets('shows the normal relative-time label when justNow is false (default)', (tester) async {
    await pumpApp(
      tester,
      PRCard(record: record, now: DateTime(2026, 3, 1)),
    );

    expect(find.textContaining('Just now'), findsNothing);
    expect(find.textContaining('ago'), findsOneWidget);
  });
}
