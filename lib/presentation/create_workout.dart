import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/superset.dart';
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
  final _scrollCtrl = ScrollController();
  final List<Superset> _exercises = [];
  final List<Exercise> _warmup = [];
  bool _warmupExpanded = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingWorkout;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      // Deep-copy each superset so edits don't mutate the cached Workout.
      _exercises.addAll(existing.exercises.map((s) => Superset(
            id: s.id,
            exercises: s.exercises
                .map((e) => Exercise(
                      name: e.name,
                      reps: e.reps,
                      sets: e.sets,
                      restTime: e.restTime,
                      weight: e.weight,
                      timedDuration: e.timedDuration,
                    ))
                .toList(),
            sets: s.sets,
            restAfterSet: s.restAfterSet,
          )));
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
      _warmup.addAll(createDefaultWarmup());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Exercise list mutations ─────────────────────────────────────────

  void _addExercise() {
    setState(() {
      _exercises.add(Superset(
        exercises: [
          Exercise(
            name: '',
            reps: 10,
            sets: 1,
            restTime: Duration.zero,
            weight: 0,
          )
        ],
        sets: 3,
        restAfterSet: const Duration(seconds: 60),
      ));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  void _removeExerciseFromSuperset(int supersetIdx, int exIdx) {
    setState(() {
      final s = _exercises[supersetIdx];
      if (s.exercises.length == 1) {
        _exercises.removeAt(supersetIdx);
      } else {
        s.exercises.removeAt(exIdx);
      }
    });
  }

  /// Merges superset[supersetIdx] and superset[supersetIdx+1] into one group.
  void _groupWithNext(int supersetIdx) {
    setState(() {
      final current = _exercises[supersetIdx];
      final next = _exercises[supersetIdx + 1];
      current.exercises.addAll(next.exercises);
      _exercises.removeAt(supersetIdx + 1);
    });
  }

  /// Splits superset[supersetIdx] at [afterExIdx]:
  /// exercises[0..afterExIdx] stay; exercises[afterExIdx+1..] become a new superset.
  void _ungroupAt(int supersetIdx, int afterExIdx) {
    setState(() {
      final s = _exercises[supersetIdx];
      final after = s.exercises.sublist(afterExIdx + 1);
      s.exercises.removeRange(afterExIdx + 1, s.exercises.length);
      _exercises.insert(
        supersetIdx + 1,
        Superset(
          exercises: after,
          sets: s.sets,
          restAfterSet: s.restAfterSet,
        ),
      );
    });
  }

  void _addWarmupExercise() {
    setState(() {
      _warmup.add(Exercise(
        name: '',
        reps: 0,
        sets: 1,
        restTime: Duration.zero,
        timedDuration: const Duration(seconds: 30),
      ));
    });
  }

  void _removeWarmupExercise(int index) {
    setState(() => _warmup.removeAt(index));
  }

  // ─── Navigation ──────────────────────────────────────────────────────

  void _goToPreview() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a workout name')),
      );
      return;
    }
    if (_exercises.any(
        (s) => s.exercises.any((e) => e.name.trim().isEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All exercises must have a name')),
      );
      return;
    }
    if (_warmup.any((e) => e.name.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('All warm-up exercises must have a name')),
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
        builder: (_) => WorkoutPreviewScreen(workout: workout),
      ),
    ).then((saved) {
      if (!mounted) return;
      if (saved == true) {
        if (widget.existingWorkout != null) {
          Navigator.pop(context);
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
  }

  // ─── Exercise list rendering ─────────────────────────────────────────

  List<Widget> _buildExerciseCards() {
    final items = <({
      int supersetIdx,
      Superset superset,
      int exIdx,
      Exercise exercise
    })>[];

    for (int si = 0; si < _exercises.length; si++) {
      for (int ei = 0; ei < _exercises[si].exercises.length; ei++) {
        items.add((
          supersetIdx: si,
          superset: _exercises[si],
          exIdx: ei,
          exercise: _exercises[si].exercises[ei],
        ));
      }
    }

    final result = <Widget>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isSingle = item.superset.exercises.length == 1;
      final isFirstInGroup = item.exIdx == 0;
      final isLastInGroup =
          item.exIdx == item.superset.exercises.length - 1;

      result.add(_ExerciseSlotCard(
        key: ValueKey('${item.supersetIdx}-${item.exIdx}'),
        superset: item.superset,
        exercise: item.exercise,
        displayIndex: i + 1,
        showSets: isSingle || isFirstInGroup,
        showRest: isSingle || isLastInGroup,
        onRemove: () =>
            _removeExerciseFromSuperset(item.supersetIdx, item.exIdx),
      ));

      final isLastExerciseOverall = i == items.length - 1;
      if (!isLastExerciseOverall) {
        final nextItem = items[i + 1];
        final isLinked =
            item.supersetIdx == nextItem.supersetIdx;

        result.add(_LinkRow(
          isLinked: isLinked,
          onLink: isLinked
              ? null
              : () => _groupWithNext(item.supersetIdx),
          onUnlink: isLinked
              ? () => _ungroupAt(item.supersetIdx, item.exIdx)
              : null,
        ));
      } else {
        result.add(const SizedBox(height: 12));
      }
    }

    return result;
  }

  // ─── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final isEdit = widget.existingWorkout != null;
    final totalExercises =
        _exercises.fold(0, (sum, s) => sum + s.exercises.length);

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
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.only(bottom: 110),
                    children: [
                      // Workout name field
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(18, 8, 18, 18),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
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
                                  borderSide:
                                      BorderSide(color: c.hairline),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide:
                                      BorderSide(color: c.hairline),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: c.accent, width: 1.5),
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

                      // ── Warm-up section ──────────────────────────
                      GestureDetector(
                        onTap: () => setState(
                            () => _warmupExpanded = !_warmupExpanded),
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(22, 4, 22, 4),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
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

                      // ── Main exercises section ────────────────────
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(22, 4, 22, 10),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
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
                              '$totalExercises',
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        child: Column(
                          children: [
                            ..._buildExerciseCards(),
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
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 16),
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

// ─── Warm-up exercise card (unchanged) ───────────────────────────────────
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
  late bool _isTimed;
  late int _repsValue;
  late Duration _timedValue;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    _nameCtrl = TextEditingController(text: e.name);
    _isTimed = e.timedDuration != null;
    _repsValue = e.reps;
    _timedValue = e.timedDuration ?? const Duration(seconds: 30);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _toggleMode() {
    final e = widget.exercise;
    setState(() {
      _isTimed = !_isTimed;
      if (_isTimed) {
        e.timedDuration = _timedValue;
      } else {
        e.timedDuration = null;
        _repsValue = 10;
        e.reps = 10;
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
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                    color: c.surfaceAlt, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '${widget.index}',
                  style: monoStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: c.inkDim),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: bodyStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.ink),
                  decoration: InputDecoration(
                    hintText: 'Exercise name',
                    hintStyle:
                        bodyStyle(fontSize: 14, color: c.inkMute),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => e.name = v,
                ),
              ),
              GestureDetector(
                onTap: _toggleMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
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
                  icon:
                      Icon(Icons.close_rounded, size: 16, color: c.inkMute),
                  onPressed: widget.onRemove,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _PickerField(
                label: _isTimed ? 'DURATION' : 'REPS',
                value: _isTimed
                    ? _fmtDuration(_timedValue)
                    : '$_repsValue',
                onTap: () => _isTimed
                    ? _openTimePicker(
                        context, _timedValue, 'DURATION', (v) {
                        setState(() {
                          _timedValue = v;
                          e.timedDuration = v;
                        });
                      })
                    : _openRepsPicker(context, _repsValue, (v) {
                        setState(() {
                          _repsValue = v;
                          e.reps = v;
                        });
                      }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Exercise slot card ───────────────────────────────────────────────────
//
// Renders one exercise within a (possibly multi-exercise) Superset.
//   showSets  → true for single-exercise supersets and the FIRST exercise of a group.
//   showRest  → true for single-exercise supersets and the LAST exercise of a group.
//
class _ExerciseSlotCard extends StatefulWidget {
  final Superset superset;
  final Exercise exercise;
  final int displayIndex; // 1-based global position for the number pill
  final bool showSets;
  final bool showRest;
  final VoidCallback onRemove;

  const _ExerciseSlotCard({
    super.key,
    required this.superset,
    required this.exercise,
    required this.displayIndex,
    required this.showSets,
    required this.showRest,
    required this.onRemove,
  });

  @override
  State<_ExerciseSlotCard> createState() => _ExerciseSlotCardState();
}

class _ExerciseSlotCardState extends State<_ExerciseSlotCard> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _setsCtrl;
  late final TextEditingController _weightCtrl;
  late int _repsValue;
  late Duration _restDuration;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    final s = widget.superset;
    _nameCtrl = TextEditingController(text: e.name);
    _setsCtrl = TextEditingController(text: s.sets.toString());
    _weightCtrl = TextEditingController(text: e.weight.toString());
    _repsValue = e.reps;
    _restDuration = s.restAfterSet;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _setsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final e = widget.exercise;
    final s = widget.superset;
    final isInGroup = s.exercises.length > 1;

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
          // Header row: index pill + name + (superset badge) + remove
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isInGroup ? c.accent.withValues(alpha: 0.15) : c.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.displayIndex}',
                  style: monoStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isInGroup ? c.accent : c.inkDim,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: bodyStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Exercise name',
                    hintStyle: bodyStyle(fontSize: 15, color: c.inkMute),
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
          // Field grid: conditional SETS + REPS + WEIGHT + conditional REST
          Row(
            children: [
              if (widget.showSets) ...[
                _NumField(
                  label: 'SETS',
                  ctrl: _setsCtrl,
                  unit: null,
                  onChanged: (v) =>
                      s.sets = int.tryParse(v) ?? s.sets,
                ),
                const SizedBox(width: 6),
              ],
              _PickerField(
                label: 'REPS',
                value: '$_repsValue',
                onTap: () => _openRepsPicker(context, _repsValue, (v) {
                  setState(() {
                    _repsValue = v;
                    e.reps = v;
                  });
                }),
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
              if (widget.showRest) ...[
                const SizedBox(width: 6),
                _PickerField(
                  label: 'REST',
                  value: _fmtDuration(_restDuration),
                  onTap: () => _openTimePicker(
                      context, _restDuration, 'REST', (v) {
                    setState(() {
                      _restDuration = v;
                      s.restAfterSet = v;
                    });
                  }),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Link row (between exercise cards) ───────────────────────────────────
//
// Shows a visual connector when two consecutive exercises are in the same
// superset (isLinked = true), or a subtle "group with next" action otherwise.
//
class _LinkRow extends StatelessWidget {
  final bool isLinked;
  final VoidCallback? onLink;
  final VoidCallback? onUnlink;

  const _LinkRow({
    required this.isLinked,
    this.onLink,
    this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    if (isLinked) {
      // Accent connector: visual chain between grouped cards
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 3,
              height: 28,
              margin: const EdgeInsets.only(left: 20),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'SUPERSET',
                style: bodyStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: c.accent,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onUnlink,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                child: Row(
                  children: [
                    Icon(Icons.link_off_rounded,
                        size: 13, color: c.inkMute),
                    const SizedBox(width: 4),
                    Text(
                      'Ungroup',
                      style: bodyStyle(
                          fontSize: 11,
                          color: c.inkMute,
                          letterSpacing: 0.2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Subtle "group with next" option
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onLink,
              child: Row(
                children: [
                  Icon(Icons.link_rounded, size: 13, color: c.inkMute),
                  const SizedBox(width: 5),
                  Text(
                    'Group with next',
                    style: bodyStyle(
                        fontSize: 11,
                        color: c.inkMute,
                        letterSpacing: 0.2),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}

// ─── Shared numeric field widget ──────────────────────────────────────────
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

// ─── Workout Preview Screen ───────────────────────────────────────────────
class WorkoutPreviewScreen extends ConsumerStatefulWidget {
  final Workout workout;

  const WorkoutPreviewScreen({
    super.key,
    required this.workout,
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
    final exercises = w.exercises; // List<Superset>

    // Stats: total individual set count and total volume
    final totalSets = exercises.fold<int>(
        0, (a, s) => a + s.sets * s.exercises.length);
    final totalVol = exercises.fold<double>(
        0,
        (a, s) =>
            a +
            s.sets *
                s.exercises.fold(
                    0.0, (sum, e) => sum + e.reps * e.weight));
    final durMin = w.totalDuration.inMinutes;

    String fmtDur(int min) {
      if (min < 60) return '$min min';
      final h = min ~/ 60, m = min % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }

    // Build preview rows grouped by superset, exercise-by-exercise.
    // Within a superset: intra-group exercises show '→' instead of a rest time.
    final rows = <_SetRow>[];
    for (int ssi = 0; ssi < exercises.length; ssi++) {
      final ss = exercises[ssi];
      for (int ei = 0; ei < ss.exercises.length; ei++) {
        final ex = ss.exercises[ei];
        final isLastInSuperset = ei == ss.exercises.length - 1;
        final restSec =
            isLastInSuperset ? ss.restAfterSet.inSeconds : 0;

        for (int s = 1; s <= ss.sets; s++) {
          rows.add(_SetRow(
            exName: ex.name,
            setNum: s,
            totalSets: ss.sets,
            reps: ex.reps,
            weight: ex.weight,
            restSec: restSec,
            isFirstSet: s == 1,
            isSupersetTransition: !isLastInSuperset,
            supersetBadge:
                s == 1 && ei == 0 && ss.isSuperset ? 'SUPERSET' : null,
          ));
        }
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
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                border: Border.all(color: c.hairlineSoft),
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
                                prevRow: i > 0 ? rows[i - 1] : null,
                              ),
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
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
  /// True when this exercise transitions directly into the next (no rest).
  final bool isSupersetTransition;
  /// Non-null on the very first set of the first exercise of a multi-exercise
  /// superset — used to render the "SUPERSET" badge in the preview.
  final String? supersetBadge;

  const _SetRow({
    required this.exName,
    required this.setNum,
    required this.totalSets,
    required this.reps,
    required this.weight,
    required this.restSec,
    required this.isFirstSet,
    this.isSupersetTransition = false,
    this.supersetBadge,
  });
}

// ─── Duration formatter ───────────────────────────────────────────────────
String _fmtDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ─── Picker bottom sheets ─────────────────────────────────────────────────
void _openRepsPicker(
    BuildContext context, int current, void Function(int) onSelect) {
  int selected = current.clamp(1, 50);
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetCtx) {
      final c = AppThemeData.of(context).c;
      return SizedBox(
        height: 280,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'REPS',
                    style: bodyStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.inkMute,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onSelect(selected);
                      Navigator.pop(sheetCtx);
                    },
                    child: Text(
                      'Done',
                      style: bodyStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController:
                    FixedExtentScrollController(initialItem: selected - 1),
                itemExtent: 44,
                onSelectedItemChanged: (i) => selected = i + 1,
                children: List.generate(
                  50,
                  (i) => Center(
                    child: Text(
                      '${i + 1}',
                      style: displayStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _openTimePicker(BuildContext context, Duration current, String label,
    void Function(Duration) onSelect) {
  int selMin = current.inMinutes.clamp(0, 9);
  int selSecIdx = ((current.inSeconds % 60) ~/ 5).clamp(0, 11);

  showModalBottomSheet<void>(
    context: context,
    builder: (sheetCtx) {
      final c = AppThemeData.of(context).c;
      return SizedBox(
        height: 280,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: bodyStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.inkMute,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onSelect(Duration(
                          minutes: selMin, seconds: selSecIdx * 5));
                      Navigator.pop(sheetCtx);
                    },
                    child: Text(
                      'Done',
                      style: bodyStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'min',
                        style: bodyStyle(
                          fontSize: 11,
                          color: c.inkMute,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'sec',
                        style: bodyStyle(
                          fontSize: 11,
                          color: c.inkMute,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController:
                          FixedExtentScrollController(initialItem: selMin),
                      itemExtent: 44,
                      onSelectedItemChanged: (i) => selMin = i,
                      children: List.generate(
                        10,
                        (i) => Center(
                          child: Text(
                            '$i',
                            style: displayStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: c.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                          initialItem: selSecIdx),
                      itemExtent: 44,
                      onSelectedItemChanged: (i) => selSecIdx = i,
                      children: List.generate(
                        12,
                        (i) => Center(
                          child: Text(
                            (i * 5).toString().padLeft(2, '0'),
                            style: displayStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: c.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ─── Picker field (tap-to-open, same visual style as _NumField) ───────────
class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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
              Text(
                value,
                style: displayStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          // Optional SUPERSET badge above the exercise header
          if (row.supersetBadge != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  row.supersetBadge!,
                  style: bodyStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
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
                    Text(' reps',
                        style: bodyStyle(fontSize: 14, color: c.inkMute)),
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
                    Text(' kg',
                        style: bodyStyle(fontSize: 14, color: c.inkMute)),
                  ],
                ),
              ),
              // Rest / superset-transition indicator
              if (row.isSupersetTransition)
                Row(
                  children: [
                    Icon(Icons.arrow_forward_rounded,
                        size: 12, color: c.accent),
                    const SizedBox(width: 3),
                    Text(
                      'superset',
                      style: bodyStyle(
                          fontSize: 11,
                          color: c.accent,
                          letterSpacing: 0.2),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 12, color: c.inkMute),
                    const SizedBox(width: 4),
                    Text(
                      '${row.restSec}s',
                      style: bodyStyle(fontSize: 12, color: c.inkMute),
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
