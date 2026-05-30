import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mesocycle_repository.dart';
import '../data/override_repository.dart';
import '../domain/models/mesocycle.dart';
import '../domain/models/day_override.dart';
import '../domain/schedule/schedule_logic.dart';
import 'workout_providers.dart';
import 'reminder_provider.dart';
import '../services/notification_service.dart';

// ─── Active mesocycle ID (stored in shared_preferences) ───────────────

class ActiveMesoIdNotifier extends AsyncNotifier<String?> {
  static const _key = 'active_mesocycle_id';

  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> setActive(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, id);
    }
    state = AsyncData(id);
  }
}

final activeMesoIdProvider =
    AsyncNotifierProvider<ActiveMesoIdNotifier, String?>(ActiveMesoIdNotifier.new);

// ─── Derived: active Mesocycle object ─────────────────────────────────

final activeMesocycleProvider = Provider<Mesocycle?>((ref) {
  final mesoList = ref.watch(mesocyclesProvider).asData?.value ?? [];
  final activeId = ref.watch(activeMesoIdProvider).asData?.value;
  if (activeId == null) return null;
  try {
    return mesoList.firstWhere((m) => m.id == activeId);
  } catch (_) {
    return null;
  }
});

// ─── All mesocycles ───────────────────────────────────────────────────

class MesocyclesNotifier extends AsyncNotifier<List<Mesocycle>> {
  @override
  Future<List<Mesocycle>> build() async =>
      ref.read(mesocycleRepositoryProvider).getAll();

  Future<void> save(Mesocycle meso) async {
    await ref.read(mesocycleRepositoryProvider).save(meso);
    ref.invalidateSelf();
    await future;
    await _reschedule();
  }

  Future<void> delete(String id) async {
    if (ref.read(activeMesoIdProvider).asData?.value == id) {
      await ref.read(activeMesoIdProvider.notifier).setActive(null);
    }
    await ref.read(mesocycleRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
    await _reschedule();
  }

  // Appends a CycleAdjustment, deduping any existing adjustment with the
  // same effectiveDate (replacing it), then sorts chronologically.
  Future<void> appendAdjustment(String mesoId, CycleAdjustment adj) async {
    final list = ref.read(mesocycleRepositoryProvider).getAll();
    final idx = list.indexWhere((m) => m.id == mesoId);
    if (idx < 0) return;
    final meso = list[idx];
    final adjustments = List<CycleAdjustment>.from(meso.adjustments)
      ..removeWhere((a) => a.effectiveDate == adj.effectiveDate)
      ..add(adj);
    adjustments.sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
    await ref
        .read(mesocycleRepositoryProvider)
        .save(meso.copyWith(adjustments: adjustments));
    ref.invalidateSelf();
    await future;
    await _reschedule();
  }

  // Public entry point used by widgets (WidgetRef.read cannot call the
  // top-level rescheduleNotifications directly since Ref ≠ WidgetRef).
  Future<void> reschedule() => _reschedule();

  Future<void> _reschedule() => rescheduleNotifications(ref);
}

final mesocyclesProvider =
    AsyncNotifierProvider<MesocyclesNotifier, List<Mesocycle>>(MesocyclesNotifier.new);

// ─── Per-day overrides for the active mesocycle ───────────────────────

class OverridesNotifier extends AsyncNotifier<List<DayOverride>> {
  @override
  Future<List<DayOverride>> build() async {
    final meso = ref.watch(activeMesocycleProvider);
    if (meso == null) return [];
    return ref.read(overrideRepositoryProvider).forMeso(meso.id);
  }

  String? _activeMesoId() => ref.read(activeMesocycleProvider)?.id;

  Future<void> setWorkout(DateTime date, String workoutId) async {
    final mesoId = _activeMesoId();
    if (mesoId == null) return;
    await ref.read(overrideRepositoryProvider).save(DayOverride(
      mesocycleId: mesoId,
      date: normalizeDate(date),
      kind: OverrideKind.setWorkout,
      workoutId: workoutId,
    ));
    ref.invalidateSelf();
    await future;
    await _reschedule();
  }

  Future<void> setRest(DateTime date) async {
    final mesoId = _activeMesoId();
    if (mesoId == null) return;
    await ref.read(overrideRepositoryProvider).save(DayOverride(
      mesocycleId: mesoId,
      date: normalizeDate(date),
      kind: OverrideKind.rest,
    ));
    ref.invalidateSelf();
    await future;
    await _reschedule();
  }

  Future<void> clearOverride(DateTime date) async {
    final mesoId = _activeMesoId();
    if (mesoId == null) return;
    await ref
        .read(overrideRepositoryProvider)
        .clear(mesoId, normalizeDate(date));
    ref.invalidateSelf();
    await future;
    await _reschedule();
  }

  // Moves [workoutId] from [from] to [to] by setting a rest override on [from]
  // and a setWorkout override on [to]. The caller passes the workoutId since
  // it already knows which workout is displayed on [from].
  Future<void> move(DateTime from, DateTime to, String workoutId) async {
    final mesoId = _activeMesoId();
    if (mesoId == null) return;
    final repo = ref.read(overrideRepositoryProvider);
    await repo.save(DayOverride(
      mesocycleId: mesoId,
      date: normalizeDate(from),
      kind: OverrideKind.rest,
    ));
    await repo.save(DayOverride(
      mesocycleId: mesoId,
      date: normalizeDate(to),
      kind: OverrideKind.setWorkout,
      workoutId: workoutId,
    ));
    ref.invalidateSelf();
    await future;
    await _reschedule();
  }

  Future<void> _reschedule() => rescheduleNotifications(ref);
}

final overridesProvider =
    AsyncNotifierProvider<OverridesNotifier, List<DayOverride>>(OverridesNotifier.new);

// ─── Reminder reschedule helper (called from AsyncNotifier.ref only) ──

Future<void> rescheduleNotifications(Ref ref) async {
  final meso = ref.read(activeMesocycleProvider);
  final overrideRepo = ref.read(overrideRepositoryProvider);
  final workouts = ref.read(workoutsProvider).asData?.value ?? [];
  final reminderState = ref.read(reminderProvider).asData?.value;
  if (reminderState == null) return;

  await NotificationService.instance.rescheduleAll(
    meso: meso,
    overrideForDate: (date) =>
        meso != null ? overrideRepo.get(meso.id, date) : null,
    workouts: workouts,
    time: reminderState.time,
    enabled: reminderState.enabled,
  );
}
