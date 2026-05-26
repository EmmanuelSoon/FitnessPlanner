import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/domain/models/default_warmup.dart';
import 'package:fitness_planner/providers/workout_providers.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/theme/app_theme.dart';

class CreateWorkoutScreen extends StatefulWidget {
  final Workout? existingWorkout;
  const CreateWorkoutScreen({super.key, this.existingWorkout});

  @override
  State<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final _nameCtrl = TextEditingController();
  final List<Exercise> _exercises = [];
  final List<Exercise> _warmup = [];
  bool _warmupExpanded = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingWorkout;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _exercises.addAll(existing.exercises.map(
        (e) => Exercise(
          name: e.name,
          reps: e.reps,
          sets: e.sets,
          restTime: e.restTime,
          weight: e.weight,
          timedDuration: e.timedDuration,
        ),
      ));
      _warmup.addAll(existing.warmup.map(
        (e) => Exercise(
          name: e.name,
          reps: e.reps,
          sets: e.sets,
          restTime: e.restTime,
          weight: e.weight,
          timedDuration: e.timedDuration,
        ),
      ));
    } else {
      // New workout: pre-populate with default warm-up
      _warmup.addAll(createDefaultWarmup());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _addExercise() {
    setState(() {
      _exercises.add(
        Exercise(
            name: '',
            reps: 10,
            sets: 3,
            restTime: const Duration(seconds: 60),
            weight: 0),
      );
    });
  }

  void _removeExercise(int index) {
    setState(() => _exercises.removeAt(index));
  }

  void _addWarmupExercise() {
    setState(() {
      _warmup.add(
        Exercise(
          name: '',
          reps: 0,
          sets: 1,
          restTime: Duration.zero,
          timedDuration: const Duration(seconds: 30),
        ),
      );
    });
  }

  void _removeWarmupExercise(int index) {
    setState(() => _warmup.removeAt(index));
  }

  void _goToPreview() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a workout name')),
      );
      return;
    }
    if (_exercises.any((e) => e.name.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All exercises must have a name')),
      );
      return;
    }
    if (_warmup.any((e) => e.name.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All warm-up exercises must have a name')),
      );
      return;
    }

    final workout = Workout(
      id: widget.existingWorkout?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      exercises: List.of(_exercises),
      warmup: List.of(_warmup),
    );
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutPreviewScreen(
          workout: workout,
          sequence: workout.generateWorkoutSequence(),
        ),
      ),
    ).then((saved) {
      if (!mounted) return;
      if (saved == true) {
        if (widget.existingWorkout != null) {
          Navigator.pop(context); // editing: single pop back to list
        } else {
          // Item 1.4 — new workout: pop all the way back to workout list
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final isEdit = widget.existingWorkout != null;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AppHeaderBar(
                  title: isEdit ? 'Edit workout' : 'New workout',
                  leading: AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),
                  trailing: AppIconButton(
                    icon: Icons.check_rounded,
                    onPressed: _goToPreview,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 110),
                    children: [
                      // Workout name field
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WORKOUT NAME',
                              style: bodyStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: c.inkMute,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _nameCtrl,
                              style: displayStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w500,
                                color: c.ink,
                                letterSpacing: -0.5,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. Chest & Triceps',
                                hintStyle: displayStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w500,
                                  color: c.inkMute,
                                  letterSpacing: -0.5,
                                ),
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(color: c.hairline),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: c.hairline),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide:
                                      BorderSide(color: c.accent, width: 1.5),
                                ),
                                contentPadding:
                                    const EdgeInsets.only(bottom: 8),
                              ),
                              onSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                            ),
                          ],
                        ),
                      ),

                      // ── Warm-up section ─────────────────────────────
                      GestureDetector(
                        onTap: () => setState(
                            () => _warmupExpanded = !_warmupExpanded),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'WARM-UP',
                                style: bodyStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: c.inkMute,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${_warmup.length}',
                                    style: bodyStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: c.inkMute,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    _warmupExpanded
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    size: 20,
                                    color: c.inkMute,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_warmupExpanded) ...[
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              ..._warmup.asMap().entries.map((entry) {
                                final i = entry.key;
                                final ex = entry.value;
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 10),
                                  child: WarmupExerciseCard(
                                    exercise: ex,
                                    index: i + 1,
                                    onRemove: () =>
                                        _removeWarmupExercise(i),
                                  ),
                                );
                              }),
                              // Add warm-up exercise button
                              GestureDetector(
                                onTap: _addWarmupExercise,
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius:
                                        BorderRadius.circular(kRadius),
                                    border: Border.all(
                                      color: c.hairline,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_rounded,
                                          size: 16, color: c.inkDim),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Add warm-up exercise',
                                        style: bodyStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: c.inkDim,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // ── Main exercises section ───────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'EXERCISES',
                              style: bodyStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: c.inkMute,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              '${_exercises.length}',
                              style: bodyStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: c.inkMute,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            ..._exercises.asMap().entries.map((entry) {
                              final i = entry.key;
                              final ex = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ExerciseEditCard(
                                  exercise: ex,
                                  index: i + 1,
                                  onRemove: () => _removeExercise(i),
                                ),
                              );
                            }),
                            GestureDetector(
                              onTap: _addExercise,
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(kRadius),
                                  border: Border.all(
                                    color: c.hairline,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_rounded,
                                        size: 18, color: c.ink),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Add exercise',
                                      style: bodyStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: c.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Sticky bottom CTA
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.6, 1.0],
                    colors: [c.bg, c.bg.withValues(alpha: 0)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: AppButton(
                  label: 'Preview workout →',
                  full: true,
                  onPressed: _goToPreview,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Warm-up exercise card ───────────────────────────────────────────────
class WarmupExerciseCard extends StatefulWidget {
  final Exercise exercise;
  final int index;
  final VoidCallback onRemove;

  const WarmupExerciseCard({
    super.key,
    required this.exercise,
    required this.index,
    required this.onRemove,
  });

  @override
  State<WarmupExerciseCard> createState() => _WarmupExerciseCardState();
}

class _WarmupExerciseCardState extends State<WarmupExerciseCard> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _valueCtrl;
  late bool _isTimed;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    _nameCtrl = TextEditingController(text: e.name);
    _isTimed = e.timedDuration != null;
    _valueCtrl = TextEditingController(
      text: _isTimed
          ? (e.timedDuration!.inSeconds.toString())
          : e.reps.toString(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  void _toggleMode() {
    final e = widget.exercise;
    setState(() {
      _isTimed = !_isTimed;
      if (_isTimed) {
        final secs = int.tryParse(_valueCtrl.text) ?? 30;
        e.timedDuration = Duration(seconds: secs);
        _valueCtrl.text = secs.toString();
      } else {
        e.timedDuration = null;
        e.reps = 10;
        _valueCtrl.text = '10';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final e = widget.exercise;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: c.hairlineSoft),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Index pill
              Container(
                width: 22,
                height: 22,
                decoration:
                    BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '${widget.index}',
                  style:
                      monoStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.inkDim),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  style:
                      bodyStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink),
                  decoration: InputDecoration(
                    hintText: 'Exercise name',
                    hintStyle: bodyStyle(fontSize: 14, color: c.inkMute),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => e.name = v,
                ),
              ),
              // Toggle timed / rep-based
              GestureDetector(
                onTap: _toggleMode,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isTimed ? '⏱ Timed' : '🔢 Reps',
                    style: bodyStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: c.inkDim),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 30,
                height: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.close_rounded, size: 16, color: c.inkMute),
                  onPressed: widget.onRemove,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Duration / reps field
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(kRadius - 6),
              border: Border.all(color: c.hairlineSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isTimed ? 'DURATION' : 'REPS',
                  style: bodyStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: c.inkMute,
                      letterSpacing: 0.6),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _valueCtrl,
                        keyboardType: TextInputType.number,
                        style: displayStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                            letterSpacing: -0.3),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) {
                          if (_isTimed) {
                            e.timedDuration =
                                Duration(seconds: int.tryParse(v) ?? 30);
                          } else {
                            e.reps = int.tryParse(v) ?? e.reps;
                          }
                        },
                      ),
                    ),
                    Text(
                      _isTimed ? 's' : 'reps',
                      style: bodyStyle(
                          fontSize: 11, color: c.inkMute, letterSpacing: 0),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Exercise edit card ──────────────────────────────────────────────────
class ExerciseEditCard extends StatefulWidget {
  final Exercise exercise;
  final int index;
  final VoidCallback onRemove;

  const ExerciseEditCard({
    super.key,
    required this.exercise,
    required this.index,
    required this.onRemove,
  });

  @override
  State<ExerciseEditCard> createState() => _ExerciseEditCardState();
}

class _ExerciseEditCardState extends State<ExerciseEditCard> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _setsCtrl;
  late final TextEditingController _repsCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _restCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    _nameCtrl = TextEditingController(text: e.name);
    _setsCtrl = TextEditingController(text: e.sets.toString());
    _repsCtrl = TextEditingController(text: e.reps.toString());
    _weightCtrl = TextEditingController(text: e.weight.toString());
    _restCtrl =
        TextEditingController(text: e.restTime.inSeconds.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    _restCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final e = widget.exercise;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: c.hairlineSoft),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: index pill + name + remove
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.index}',
                  style: monoStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.inkDim,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  style: bodyStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Exercise name',
                    hintStyle:
                        bodyStyle(fontSize: 15, color: c.inkMute),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => e.name = v,
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: c.inkMute),
                  onPressed: widget.onRemove,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 4-field grid: SETS / REPS / WEIGHT / REST
          Row(
            children: [
              _NumField(
                label: 'SETS',
                ctrl: _setsCtrl,
                unit: null,
                onChanged: (v) => e.sets = int.tryParse(v) ?? e.sets,
              ),
              const SizedBox(width: 6),
              _NumField(
                label: 'REPS',
                ctrl: _repsCtrl,
                unit: null,
                onChanged: (v) => e.reps = int.tryParse(v) ?? e.reps,
              ),
              const SizedBox(width: 6),
              _NumField(
                label: 'WEIGHT',
                ctrl: _weightCtrl,
                unit: 'kg',
                onChanged: (v) =>
                    e.weight = double.tryParse(v) ?? e.weight,
                decimal: true,
              ),
              const SizedBox(width: 6),
              _NumField(
                label: 'REST',
                ctrl: _restCtrl,
                unit: 's',
                onChanged: (v) => e.restTime = Duration(
                    seconds: int.tryParse(v) ?? e.restTime.inSeconds),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? unit;
  final ValueChanged<String> onChanged;
  final bool decimal;

  const _NumField({
    required this.label,
    required this.ctrl,
    required this.unit,
    required this.onChanged,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(kRadius - 6),
          border: Border.all(color: c.hairlineSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: bodyStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: c.inkMute,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    keyboardType: decimal
                        ? const TextInputType.numberWithOptions(
                            decimal: true)
                        : TextInputType.number,
                    style: displayStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      letterSpacing: -0.3,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: onChanged,
                  ),
                ),
                if (unit != null)
                  Text(
                    unit!,
                    style: bodyStyle(
                      fontSize: 11,
                      color: c.inkMute,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Workout Preview Screen ──────────────────────────────────────────────
class WorkoutPreviewScreen extends ConsumerStatefulWidget {
  final Workout workout;
  final List<Exercise> sequence;

  const WorkoutPreviewScreen({
    super.key,
    required this.workout,
    required this.sequence,
  });

  @override
  ConsumerState<WorkoutPreviewScreen> createState() =>
      _WorkoutPreviewScreenState();
}

class _WorkoutPreviewScreenState
    extends ConsumerState<WorkoutPreviewScreen> {
  Future<void> _saveWorkout() async {
    await ref
        .read(workoutsProvider.notifier)
        .saveWorkout(widget.workout);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout saved!')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final w = widget.workout;
    final exercises = w.exercises;

    final totalSets =
        exercises.fold<int>(0, (a, e) => a + e.sets);
    final totalVol = exercises.fold<double>(
        0, (a, e) => a + e.sets * e.reps * e.weight);
    final durMin = w.totalDuration.inMinutes;

    String fmtDur(int min) {
      if (min < 60) return '$min min';
      final h = min ~/ 60, m = min % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }

    final rows = <_SetRow>[];
    for (final ex in exercises) {
      for (int s = 1; s <= ex.sets; s++) {
        rows.add(_SetRow(
          exName: ex.name,
          setNum: s,
          totalSets: ex.sets,
          reps: ex.reps,
          weight: ex.weight,
          restSec: ex.restTime.inSeconds,
          isFirstSet: s == 1,
        ));
      }
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AppHeaderBar(
                  title: 'Preview',
                  leading: AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 110),
                    children: [
                      // Title + stats
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(22, 0, 22, 18),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              w.name,
                              style: displayStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: c.ink,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius:
                                    BorderRadius.circular(kRadius),
                                border: Border.all(
                                    color: c.hairlineSoft),
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _StatCell(
                                        value: durMin > 0
                                            ? fmtDur(durMin)
                                            : '—',
                                        label: 'duration',
                                        leftBorder: false,
                                      ),
                                    ),
                                    Expanded(
                                      child: _StatCell(
                                        value: '$totalSets',
                                        label: 'sets',
                                        leftBorder: true,
                                      ),
                                    ),
                                    Expanded(
                                      child: _StatCell(
                                        value:
                                            '${(totalVol / 1000).toStringAsFixed(1)}t',
                                        label: 'volume',
                                        leftBorder: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Set sequence
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 18),
                        child: Column(
                          children: [
                            for (int i = 0; i < rows.length; i++)
                              _SetRowTile(
                                  row: rows[i],
                                  prevRow:
                                      i > 0 ? rows[i - 1] : null),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Sticky bottom buttons
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.6, 1.0],
                    colors: [c.bg, c.bg.withValues(alpha: 0)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    AppButton(
                      label: 'Edit',
                      kind: ButtonKind.outline,
                      icon: Icons.edit_outlined,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: 'Save workout',
                        full: true,
                        onPressed: _saveWorkout,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final bool leftBorder;

  const _StatCell({
    required this.value,
    required this.label,
    required this.leftBorder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        border: leftBorder
            ? Border(left: BorderSide(color: c.hairlineSoft))
            : null,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: displayStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: c.ink,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: bodyStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: c.inkMute,
              letterSpacing: 0.8,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SetRow {
  final String exName;
  final int setNum;
  final int totalSets;
  final int reps;
  final double weight;
  final int restSec;
  final bool isFirstSet;

  const _SetRow({
    required this.exName,
    required this.setNum,
    required this.totalSets,
    required this.reps,
    required this.weight,
    required this.restSec,
    required this.isFirstSet,
  });
}

class _SetRowTile extends StatelessWidget {
  final _SetRow row;
  final _SetRow? prevRow;

  const _SetRowTile({required this.row, this.prevRow});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (row.isFirstSet) ...[
          SizedBox(height: prevRow != null ? 18 : 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                row.exName,
                style: bodyStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                '${row.totalSets} × ${row.reps} · ${row.weight}kg',
                style: bodyStyle(
                  fontSize: 11,
                  color: c.inkMute,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.hairlineSoft)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  row.setNum.toString().padLeft(2, '0'),
                  style: monoStyle(fontSize: 12, color: c.inkMute),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '${row.reps}',
                      style: displayStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      ' reps',
                      style:
                          bodyStyle(fontSize: 14, color: c.inkMute),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${row.weight}',
                      style: displayStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      ' kg',
                      style:
                          bodyStyle(fontSize: 14, color: c.inkMute),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(Icons.timer_outlined,
                      size: 12, color: c.inkMute),
                  const SizedBox(width: 4),
                  Text(
                    '${row.restSec}s',
                    style:
                        bodyStyle(fontSize: 12, color: c.inkMute),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
