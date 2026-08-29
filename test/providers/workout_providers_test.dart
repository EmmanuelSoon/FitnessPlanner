import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/workout_repository.dart';
import 'package:fitness_planner/providers/workout_providers.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';

void main() {
  late FakeWorkoutRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeWorkoutRepository();
    container = ProviderContainer(
      overrides: [workoutRepositoryProvider.overrideWithValue(fakeRepo)],
    );
  });

  tearDown(() => container.dispose());

  test('build() loads the current workouts from the repository', () async {
    fakeRepo.store['w1'] = buildWorkout(id: 'w1');

    final result = await container.read(workoutsProvider.future);

    expect(result.map((w) => w.id), ['w1']);
  });

  test('saveWorkout() persists to the repository and updates state', () async {
    await container.read(workoutsProvider.future);

    await container.read(workoutsProvider.notifier).saveWorkout(buildWorkout(id: 'w1'));

    expect(fakeRepo.store.containsKey('w1'), isTrue);
    expect(container.read(workoutsProvider).value?.map((w) => w.id), ['w1']);
  });

  test('deleteWorkout() removes from the repository and updates state', () async {
    fakeRepo.store['w1'] = buildWorkout(id: 'w1');
    await container.read(workoutsProvider.future);

    await container.read(workoutsProvider.notifier).deleteWorkout('w1');

    expect(fakeRepo.store.containsKey('w1'), isFalse);
    expect(container.read(workoutsProvider).value, isEmpty);
  });
}
