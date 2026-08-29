import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/providers/session_providers.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';

void main() {
  late FakeSessionRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeSessionRepository();
    container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(fakeRepo)],
    );
  });

  tearDown(() => container.dispose());

  test('build() loads the current sessions from the repository', () async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1');

    final result = await container.read(sessionsProvider.future);

    expect(result.map((s) => s.id), ['ws1']);
  });

  test('saveSession() persists to the repository and updates state', () async {
    await container.read(sessionsProvider.future);

    await container.read(sessionsProvider.notifier).saveSession(buildWorkoutSession(id: 'ws1'));

    expect(fakeRepo.store.containsKey('ws1'), isTrue);
    expect(container.read(sessionsProvider).value?.map((s) => s.id), ['ws1']);
  });

  test('deleteSession() removes from the repository and updates state', () async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1');
    await container.read(sessionsProvider.future);

    await container.read(sessionsProvider.notifier).deleteSession('ws1');

    expect(fakeRepo.store.containsKey('ws1'), isFalse);
    expect(container.read(sessionsProvider).value, isEmpty);
  });
}
