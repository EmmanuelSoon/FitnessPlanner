import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/superset.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/domain/models/default_warmup.dart';
import 'package:fitness_planner/providers/workout_providers.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/theme/app_theme.dart';

// ─── Flat edit row (one exercise in the list) ─────────────────────────
class _ExRow {
  final String uid;
  final TextEditingController nameCtrl;
  final TextEditingController repsCtrl;
  final TextEditingController weightCtrl;
  // Sets & rest live at the LAST exercise of a superset group
  final TextEditingController setsCtrl;
  final TextEditingController restCtrl;
  bool groupedWithNext; // true → connects this row to the next row

  _ExRow({
    required this.uid,
    required this.nameCtrl,
    required this.repsCtrl,
    required this.weightCtrl,
    required this.setsCtrl,
    required this.restCtrl,
    this.groupedWithNext = false,
  });

  void dispose() {
    nameCtrl.dispose();
    repsCtrl.dispose();
    weightCtrl.dispose();
    setsCtrl.dispose();
    restCtrl.dispose();
  }
}

// ─── Warmup row data ──────────────────────────────────────────────────
class _WuRow {
  final TextEditingController nameCtrl;
  final TextEditingController durationCtrl; // seconds
  bool isTimed;

  _WuRow({
    required this.nameCtrl,
    required this.durationCtrl,
    this.isTimed = true,
  });

  void dispose() {
    nameCtrl.dispose();
    durationCtrl.dispose();
  }
}

// ─── CreateWorkoutScreen ──────────────────────────────────────────────
class CreateWorkoutScreen extends StatefulWidget {
  final Workout? existingWorkout;
  const CreateWorkoutScreen({super.key, this.existingWorkout});

  @override
  State<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final _nameCtrl = TextEditingController();
  final List<_ExRow> _rows = [];
  final List<_WuRow> _warmupRows = [];
  bool _warmupExpanded = false;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existingWorkout;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _loadSupersets(existing.exercises);
      for (final ex in existing.warmup) {
        _warmupRows.add(_WuRow(
          nameCtrl: TextEditingController(text: ex.name),
          durationCtrl: TextEditingController(
              text: ex.timedDuration?.inSeconds.toString() ?? '30'),
          isTimed: ex.timedDuration != null,
        ));
      }
    } else {
      // Pre-populate default warmup for new workouts
      for (final ex in defaultWarmupExercises()) {
        _warmupRows.add(_WuRow(
          nameCtrl: TextEditingController(text: ex.name),
          durationCtrl: TextEditingController(
              text: ex.timedDuration!.inSeconds.toString()),
          isTimed: true,
        ));
      }
    }
  }

  void _loadSupersets(List<Superset> supersets) {
    for (final superset in supersets) {
      for (int i = 0; i < superset.exercises.length; i++) {
        final ex = superset.exercises[i];
        final isLast = i == superset.exercises.length - 1;
        _rows.add(_ExRow(
          uid: '${superset.id}_$i',
          nameCtrl: TextEditingController(text: ex.name),
          repsCtrl: TextEditingController(text: ex.reps.toString()),
          weightCtrl: TextEditingController(text: ex.weight.toString()),
          setsCtrl: TextEditingController(
              text: isLast ? superset.sets.toString() : '3'),
          restCtrl: TextEditingController(
              text: isLast ? superset.restAfterSet.inSeconds.toString() : '60'),
          groupedWithNext: !isLast,
        ));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scrollCtrl.dispose();
    for (final r in _rows) { r.dispose(); }
    for (final r in _warmupRows) { r.dispose(); }
    super.dispose();
  }

  void _addExercise() {
    setState(() {
      _rows.add(_ExRow(
        uid: DateTime.now().microsecondsSinceEpoch.toString(),
        nameCtrl: TextEditingController(),
        repsCtrl: TextEditingController(text: '10'),
        weightCtrl: TextEditingController(text: '0'),
        setsCtrl: TextEditingController(text: '3'),
        restCtrl: TextEditingController(text: '60'),
      ));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeExercise(int i) {
    setState(() {
      // If the row before was grouped with this, remove the group flag
      if (i > 0 && _rows[i - 1].groupedWithNext) {
        _rows[i - 1].groupedWithNext = false;
      }
      _rows[i].dispose();
      _rows.removeAt(i);
    });
  }

  void _addWarmupExercise() {
    setState(() {
      _warmupRows.add(_WuRow(
        nameCtrl: TextEditingController(),
        durationCtrl: TextEditingController(text: '30'),
        isTimed: true,
      ));
    });
  }

  void _removeWarmupExercise(int i) {
    setState(() {
      _warmupRows[i].dispose();
      _warmupRows.removeAt(i);
    });
  }

  /// Converts flat rows to Superset list, grouping consecutive connected rows.
  List<Superset> _buildSupersets() {
    final supersets = <Superset>[];
    int i = 0;
    while (i < _rows.length) {
      final exList = <Exercise>[];
      int j = i;
      while (j < _rows.length) {
        final row = _rows[j];
        exList.add(Exercise(
          name: row.nameCtrl.text.trim(),
          reps: int.tryParse(row.repsCtrl.text) ?? 10,
          weight: double.tryParse(row.weightCtrl.text) ?? 0.0,
        ));
        if (j < _rows.length - 1 && row.groupedWithNext) {
          j++;
        } else {
          break;
        }
      }
      final lastRow = _rows[j];
      supersets.add(Superset(
        id: '${lastRow.uid}_ss',
        exercises: exList,
        sets: int.tryParse(lastRow.setsCtrl.text) ?? 3,
        restAfterSet:
            Duration(seconds: int.tryParse(lastRow.restCtrl.text) ?? 60),
      ));
      i = j + 1;
    }
    return supersets;
  }

  List<Exercise> _buildWarmup() {
    return _warmupRows.map((r) {
      final secs = int.tryParse(r.durationCtrl.text) ?? 30;
      return Exercise(
        name: r.nameCtrl.text.trim(),
        reps: 0,
        timedDuration: r.isTimed ? Duration(seconds: secs) : null,
      );
    }).toList();
  }

  bool _isLastInGroup(int i) {
    if (i >= _rows.length - 1) return true;
    return !_rows[i].groupedWithNext;
  }

  void _goToPreview() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a workout name')),
      );
      return;
    }
    if (_rows.any((r) => r.nameCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All exercises must have a name')),
      );
      return;
    }

    final workout = Workout(
      id: widget.existingWorkout?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      exercises: _buildSupersets(),
      warmup: _buildWarmup(),
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
          // Editing: single pop back to list/detail
          Navigator.pop(context);
        } else {
          // New workout: pop all the way to workout list (Phase 1.4)
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
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.only(bottom: 110),
                    children: [
                      // ── Workout name ─────────────────────────────────
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
                                    borderSide:
                                        BorderSide(color: c.hairline)),
                                enabledBorder: UnderlineInputBorder(
                                    borderSide:
                                        BorderSide(color: c.hairline)),
                                focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: c.accent, width: 1.5)),
                                contentPadding:
                                    const EdgeInsets.only(bottom: 8),
                              ),
                              onSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                            ),
                          ],
                        ),
                      ),

                      // ── Warm-up section ──────────────────────────────
                      _WarmupSection(
                        rows: _warmupRows,
                        expanded: _warmupExpanded,
                        onToggle: () =>
                            setState(() => _warmupExpanded = !_warmupExpanded),
                        onAdd: _addWarmupExercise,
                        onRemove: _removeWarmupExercise,
                        c: c,
                      ),

                      // ── Exercises header ─────────────────────────────
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(22, 12, 22, 10),
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
                              '${_rows.length}',
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

                      // ── Exercise cards ───────────────────────────────
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            for (int i = 0; i < _rows.length; i++) ...[
                              _ExerciseEditCard(
                                key: ValueKey(_rows[i].uid),
                                row: _rows[i],
                                index: i + 1,
                                isLastInGroup: _isLastInGroup(i),
                                isGrouped: i > 0 &&
                                    _rows[i - 1].groupedWithNext,
                                showGroupToggle: false,
                                onRemove: () => _removeExercise(i),
                                onGroupToggle: () {},
                                c: c,
                              ),
                              if (i < _rows.length - 1)
                                _SupersetConnector(
                                  isLinked: _rows[i].groupedWithNext,
                                  onToggle: () => setState(() {
                                    _rows[i].groupedWithNext =
                                        !_rows[i].groupedWithNext;
                                  }),
                                  c: c,
                                ),
                            ],
                            // Add exercise button
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
            // ── Sticky bottom CTA ──────────────────────────────────────
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

// ─── Warm-up collapsible section ───────────────────────────────────────
class _WarmupSection extends StatelessWidget {
  final List<_WuRow> rows;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final AppColors c;

  const _WarmupSection({
    required this.rows,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.onRemove,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        GestureDetector(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                    const SizedBox(width: 6),
                    Text(
                      '${rows.length}',
                      style: bodyStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: c.inkMute,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: c.inkMute,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _WarmupEditCard(
                      row: rows[i],
                      index: i + 1,
                      onRemove: () => onRemove(i),
                      c: c,
                    ),
                  ),
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(kRadius),
                      border: Border.all(color: c.hairline, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: c.inkDim),
                        const SizedBox(width: 6),
                        Text(
                          'Add warm-up exercise',
                          style: bodyStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.inkDim),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Warmup exercise card (name + duration only) ──────────────────────
class _WarmupEditCard extends StatelessWidget {
  final _WuRow row;
  final int index;
  final VoidCallback onRemove;
  final AppColors c;

  const _WarmupEditCard({
    required this.row,
    required this.index,
    required this.onRemove,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: c.hairlineSoft),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: monoStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: c.inkDim),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: row.nameCtrl,
              style: bodyStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: c.ink),
              decoration: InputDecoration(
                hintText: 'Exercise name',
                hintStyle: bodyStyle(fontSize: 14, color: c.inkMute),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: TextField(
              controller: row.durationCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: displayStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: c.ink),
              decoration: InputDecoration(
                suffix: Text('s',
                    style: bodyStyle(fontSize: 11, color: c.inkMute)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.close_rounded, size: 16, color: c.inkMute),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Exercise edit card (with superset grouping) ──────────────────────
class _ExerciseEditCard extends StatelessWidget {
  final _ExRow row;
  final int index;
  final bool isLastInGroup;
  final bool isGrouped;
  final bool showGroupToggle;
  final VoidCallback onRemove;
  final VoidCallback onGroupToggle;
  final AppColors c;

  const _ExerciseEditCard({
    super.key,
    required this.row,
    required this.index,
    required this.isLastInGroup,
    required this.isGrouped,
    required this.showGroupToggle,
    required this.onRemove,
    required this.onGroupToggle,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final isSuperset = isGrouped || row.groupedWithNext;

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Superset accent bar
          if (isSuperset)
            Container(
              width: 3,
              margin: const EdgeInsets.only(right: 6, bottom: 4),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Expanded(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(kRadius),
                    border: Border.all(color: c.hairlineSoft),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSuperset
                                  ? c.accent.withValues(alpha: 0.12)
                                  : c.surfaceAlt,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$index',
                              style: monoStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSuperset ? c.accent : c.inkDim,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: row.nameCtrl,
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
                            ),
                          ),
                          // Group-with-next toggle (not on last overall row)
                          if (showGroupToggle)
                            GestureDetector(
                              onTap: onGroupToggle,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4, right: 4),
                                child: Icon(
                                  row.groupedWithNext
                                      ? Icons.link_rounded
                                      : Icons.link_off_rounded,
                                  size: 18,
                                  color: row.groupedWithNext
                                      ? c.accent
                                      : c.inkMute,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.close_rounded,
                                  size: 18, color: c.inkMute),
                              onPressed: onRemove,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Number fields row
                      Row(
                        children: [
                          // REPS always shown
                          _NumField(
                            label: 'REPS',
                            ctrl: row.repsCtrl,
                            unit: null,
                            onChanged: (_) {},
                          ),
                          const SizedBox(width: 6),
                          // WEIGHT always shown
                          _NumField(
                            label: 'WEIGHT',
                            ctrl: row.weightCtrl,
                            unit: 'kg',
                            onChanged: (_) {},
                            decimal: true,
                          ),
                          // SETS and REST only on last in group
                          if (isLastInGroup) ...[
                            const SizedBox(width: 6),
                            _NumField(
                              label: 'SETS',
                              ctrl: row.setsCtrl,
                              unit: null,
                              onChanged: (_) {},
                            ),
                            const SizedBox(width: 6),
                            _NumField(
                              label: 'REST',
                              ctrl: row.restCtrl,
                              unit: 's',
                              onChanged: (_) {},
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Superset connector (between exercise cards) ──────────────────────
class _SupersetConnector extends StatelessWidget {
  final bool isLinked;
  final VoidCallback onToggle;
  final AppColors c;

  const _SupersetConnector({
    required this.isLinked,
    required this.onToggle,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: isLinked
                    ? c.accent.withValues(alpha: 0.3)
                    : c.hairlineSoft,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isLinked
                    ? c.accent.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isLinked
                      ? c.accent.withValues(alpha: 0.5)
                      : c.hairline,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLinked ? Icons.link_rounded : Icons.add_link_rounded,
                    size: 12,
                    color: isLinked ? c.accent : c.inkMute,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isLinked ? 'SUPERSET' : 'ADD SUPERSET',
                    style: bodyStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isLinked ? c.accent : c.inkMute,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: isLinked
                    ? c.accent.withValues(alpha: 0.3)
                    : c.hairlineSoft,
              ),
            ),
          ],
        ),
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
                        ? const TextInputType.numberWithOptions(decimal: true)
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
                    style:
                        bodyStyle(fontSize: 11, color: c.inkMute, letterSpacing: 0),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Workout Preview Screen ────────────────────────────────────────────
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
    final supersets = w.exercises;

    final totalSets =
        supersets.fold<int>(0, (a, s) => a + s.sets * s.exercises.length);
    final totalVol = supersets.fold<double>(
      0,
      (a, s) => a +
          s.exercises.fold<double>(
            0,
            (b, e) => b + s.sets * e.reps * e.weight,
          ),
    );
    final durMin = w.totalDuration.inMinutes;

    String fmtDur(int min) {
      if (min < 60) return '$min min';
      final h = min ~/ 60, m = min % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }

    // Build preview rows
    final rows = <_PreviewRow>[];
    for (final ss in supersets) {
      for (int set = 1; set <= ss.sets; set++) {
        for (final ex in ss.exercises) {
          rows.add(_PreviewRow(
            exName: ex.name,
            setNum: set,
            totalSets: ss.sets,
            reps: ex.reps,
            weight: ex.weight,
            restSec: ex.weight > 0 ? ss.restAfterSet.inSeconds : 0,
            isFirstOfSuperset: set == 1 && ex == ss.exercises.first,
            isSupersetMember: ss.isSuperset,
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
                                        value: totalVol > 0
                                            ? '${(totalVol / 1000).toStringAsFixed(1)}t'
                                            : '—',
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
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18),
                        child: Column(
                          children: [
                            for (int i = 0; i < rows.length; i++)
                              _PreviewRowTile(
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

class _PreviewRow {
  final String exName;
  final int setNum;
  final int totalSets;
  final int reps;
  final double weight;
  final int restSec;
  final bool isFirstOfSuperset;
  final bool isSupersetMember;

  const _PreviewRow({
    required this.exName,
    required this.setNum,
    required this.totalSets,
    required this.reps,
    required this.weight,
    required this.restSec,
    required this.isFirstOfSuperset,
    required this.isSupersetMember,
  });
}

class _PreviewRowTile extends StatelessWidget {
  final _PreviewRow row;
  final _PreviewRow? prevRow;

  const _PreviewRowTile({required this.row, this.prevRow});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (row.isFirstOfSuperset) ...[
          SizedBox(height: prevRow != null ? 18 : 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Row(
                children: [
                  if (row.isSupersetMember)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.link_rounded,
                          size: 12, color: c.accent),
                    ),
                  Text(
                    row.exName,
                    style: bodyStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Text(
                row.weight > 0
                    ? '${row.totalSets} × ${row.reps} · ${row.weight}kg'
                    : '${row.totalSets} × ${row.reps} reps',
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
                        style:
                            bodyStyle(fontSize: 14, color: c.inkMute)),
                    if (row.weight > 0) ...[
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
                          style: bodyStyle(
                              fontSize: 14, color: c.inkMute)),
                    ],
                  ],
                ),
              ),
              if (row.restSec > 0)
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
