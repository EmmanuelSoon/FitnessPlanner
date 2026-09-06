import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/presentation/all_sessions_screen.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

void main() {
  late FakeSessionRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeSessionRepository();
  });

  Future<void> pumpAllSessions(WidgetTester tester) => pumpApp(
        tester,
        const AllSessionsScreen(),
        overrides: [sessionRepositoryProvider.overrideWithValue(fakeRepo)],
      );

  testWidgets('shows the empty state when there are no sessions', (tester) async {
    await pumpAllSessions(tester);

    expect(find.text('No sessions yet'), findsOneWidget);
  });

  testWidgets('renders past sessions and navigates into the detail screen', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1');

    await pumpAllSessions(tester);

    expect(find.text('Push Day'), findsOneWidget);

    await tester.tap(find.text('Push Day'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
  });
}
