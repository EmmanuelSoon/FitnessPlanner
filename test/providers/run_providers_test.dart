import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/run_repository.dart';
import 'package:fitness_planner/providers/run_providers.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';

void main() {
  late FakeRunRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeRunRepository();
    container = ProviderContainer(
      overrides: [runRepositoryProvider.overrideWithValue(fakeRepo)],
    );
  });

  tearDown(() => container.dispose());

  test('build() loads the current runs from the repository', () async {
    fakeRepo.store['r1'] = buildRunSession(id: 'r1');

    final result = await container.read(runsProvider.future);

    expect(result.map((r) => r.id), ['r1']);
  });

  test('saveRun() persists to the repository and updates state', () async {
    await container.read(runsProvider.future);

    await container.read(runsProvider.notifier).saveRun(buildRunSession(id: 'r1'));

    expect(fakeRepo.store.containsKey('r1'), isTrue);
    expect(container.read(runsProvider).value?.map((r) => r.id), ['r1']);
  });

  test('deleteRun() removes from the repository and updates state', () async {
    fakeRepo.store['r1'] = buildRunSession(id: 'r1');
    await container.read(runsProvider.future);

    await container.read(runsProvider.notifier).deleteRun('r1');

    expect(fakeRepo.store.containsKey('r1'), isFalse);
    expect(container.read(runsProvider).value, isEmpty);
  });
}
