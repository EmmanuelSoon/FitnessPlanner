import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/providers/session_providers.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/presentation/workout_complete_screen.dart';
import 'package:fitness_planner/theme/app_theme.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  final Workout workout;
  const WorkoutSessionScreen({super.key, required this.workout});

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState
    extends ConsumerState<WorkoutSessionScreen> {
  late final List<Exercise> _sequence;
  late final DateTime _startedAt;

  int _index = 0;
  final List<LoggedSet> _logged = [];

  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  int _restTotal = 0;
  bool _isResting = false;
  bool _isPaused = false;

  // Elapsed timer
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  // 5-second countdown before workout begins (Item 2.3)
  Timer? _countdownTimer;
  int _countdownSeconds = 5;
  bool _isCountingDown = false;

  // Audio (Item 2.2)
  AudioPlayer? _audioPlayer;

  final _actualRepsCtrl = TextEditingController();
  final _actualWeightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sequence = widget.workout.generateWorkoutSequence();
    _startedAt = DateTime.now();
    _prefillControllers();
    _audioPlayer = AudioPlayer();
    WakelockPlus.enable(); // Item 2.1
    if (_sequence.isNotEmpty) {
      _startCountdown(); // Item 2.3
    } else {
      _startElapsedTimer();
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _elapsedTimer?.cancel();
    _countdownTimer?.cancel();
    _audioPlayer?.dispose();
    WakelockPlus.disable(); // Item 2.1
    _actualRepsCtrl.dispose();
    _actualWeightCtrl.dispose();
    super.dispose();
  }

  void _prefillControllers() {
    if (_index < _sequence.length) {
      final e = _sequence[_index];
      _actualRepsCtrl.text = e.reps.toString();
      _actualWeightCtrl.text = e.weight.toString();
    }
  }

  // ─── Countdown (Item 2.3) ─────────────────────────────────────────────
  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdownSeconds = 5;
    });
    _playBeep();
    HapticFeedback.mediumImpact();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _countdownSeconds - 1;
      if (next > 0) {
        setState(() => _countdownSeconds = next);
        _playBeep();
        HapticFeedback.mediumImpact();
      } else {
        t.cancel();
        setState(() {
          _countdownSeconds = 0;
          _isCountingDown = false;
        });
        HapticFeedback.heavyImpact();
        _startElapsedTimer();
      }
    });
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  // ─── Sound & haptic helpers (Item 2.2) ───────────────────────────────
  Future<void> _playBeep() async {
    try {
      await _audioPlayer?.stop();
      await _audioPlayer?.play(AssetSource('sounds/beep.wav'));
    } catch (_) {}
  }

  void _vibrate(int ms) {
    Vibration.vibrate(duration: ms).catchError((_) {});
  }

  // ─── Set actions ──────────────────────────────────────────────────────
  void _finishSet() {
    final e = _sequence[_index];
    final actualReps =
        int.tryParse(_actualRepsCtrl.text) ?? e.reps;
    final actualWeight =
        double.tryParse(_actualWeightCtrl.text) ?? e.weight;
    _logged.add(LoggedSet(
      exerciseName: e.name,
      targetReps: e.reps,
      targetWeight: e.weight,
      actualReps: actualReps,
      actualWeight: actualWeight,
      skipped: false,
    ));
    _vibrate(250); // Item 2.2 — set complete feedback
    _advance();
  }

  void _skipSet() {
    final e = _sequence[_index];
    _logged.add(LoggedSet(
      exerciseName: e.name,
      targetReps: e.reps,
      targetWeight: e.weight,
      actualReps: 0,
      actualWeight: 0,
      skipped: true,
    ));
    _advance();
  }

  void _advance() {
    if (_index >= _sequence.length - 1) {
      _finishWorkout(completed: true);
      return;
    }
    final restSeconds = _sequence[_index].restTime.inSeconds;
    if (restSeconds <= 0) {
      _endRest();
      return;
    }
    setState(() {
      _isResting = true;
      _restSecondsRemaining = restSeconds;
      _restTotal = restSeconds;
      _isPaused = false;
    });
    _startRestTimer();
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _restSecondsRemaining--);
      // Item 2.2 — countdown beeps in final 3 seconds
      if (_restSecondsRemaining <= 3 &&
          _restSecondsRemaining > 0) {
        _playBeep();
        _vibrate(100);
      }
      if (_restSecondsRemaining <= 0) {
        t.cancel();
        _vibrate(250); // Item 2.2 — rest ended
        _endRest();
      }
    });
  }

  void _togglePause() {
    if (_isPaused) {
      setState(() => _isPaused = false);
      _startRestTimer();
    } else {
      _restTimer?.cancel();
      setState(() => _isPaused = true);
    }
  }

  void _skipRest() {
    _restTimer?.cancel();
    _endRest();
  }

  void _addRestTime(int extraSeconds) {
    setState(() => _restSecondsRemaining += extraSeconds);
  }

  // Item 1.1 — subtract rest time, clamped to 0
  void _subtractRestTime(int seconds) {
    setState(() {
      _restSecondsRemaining =
          (_restSecondsRemaining - seconds).clamp(0, _restTotal + 3600);
    });
  }

  void _endRest() {
    setState(() {
      _index++;
      _isResting = false;
      _isPaused = false;
    });
    _prefillControllers();
  }

  Future<void> _finishWorkout({required bool completed}) async {
    _restTimer?.cancel();
    _elapsedTimer?.cancel();
    _countdownTimer?.cancel();
    WakelockPlus.disable();
    final session = WorkoutSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      workoutId: widget.workout.id,
      workoutName: widget.workout.name,
      startedAt: _startedAt,
      endedAt: DateTime.now(),
      completed: completed,
      sets: List.unmodifiable(_logged),
    );
    await ref.read(sessionsProvider.notifier).saveSession(session);
    if (!mounted) return;
    if (completed) {
      // Item 3.2 — push workout complete screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkoutCompleteScreen(session: session),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress saved.')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleBackPressed() async {
    if (_isCountingDown) {
      _countdownTimer?.cancel();
      WakelockPlus.disable();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (_logged.isEmpty) {
      WakelockPlus.disable();
      Navigator.of(context).pop();
      return;
    }
    final choice = await _showExitDialog();
    if (choice == 'save') {
      await _finishWorkout(completed: false);
    } else if (choice == 'discard') {
      WakelockPlus.disable();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<String?> _showExitDialog() async {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(kRadius + 8)),
        ),
        padding: EdgeInsets.fromLTRB(
            22, 20, 22, 28 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Exit workout?',
                style: displayStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                    letterSpacing: -0.3)),
            const SizedBox(height: 10),
            Text('Save your partial progress to history?',
                style: bodyStyle(
                    fontSize: 14, color: c.inkDim, height: 1.5)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: AppButton(
                        label: 'Discard',
                        kind: ButtonKind.outline,
                        onPressed: () =>
                            Navigator.pop(ctx, 'discard'))),
                const SizedBox(width: 10),
                Expanded(
                    child: AppButton(
                        label: 'Save progress',
                        onPressed: () =>
                            Navigator.pop(ctx, 'save'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtElapsed() {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPressed();
      },
      child: _sequence.isEmpty
          ? _buildEmptyState()
          : (_isCountingDown
              ? _buildCountdownView()
              : (_isResting ? _buildRestView() : _buildExerciseView())),
    );
  }

  // ─── Countdown view (Item 2.3) ────────────────────────────────────────
  Widget _buildCountdownView() {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'GET READY',
                style: bodyStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.inkMute,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$_countdownSeconds',
                style: monoStyle(
                  fontSize: 112,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.workout.name,
                style: displayStyle(
                  fontSize: 20,
                  color: c.inkDim,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 56, color: c.inkMute),
                const SizedBox(height: 18),
                Text(
                  'No sets to perform',
                  style: displayStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: c.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Edit the workout to add exercises with sets > 0.',
                  style: bodyStyle(
                      fontSize: 14, color: c.inkDim, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Go back',
                  kind: ButtonKind.outline,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Active exercise view ─────────────────────────────────────────────
  Widget _buildExerciseView() {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final e = _sequence[_index];
    final nextEx =
        _index + 1 < _sequence.length ? _sequence[_index + 1] : null;

    final completedSetsSoFar = _logged
        .where((l) => l.exerciseName == e.name)
        .length;
    final totalSetsForExercise =
        _sequence.where((s) => s.name == e.name).length;
    final currentSetIndex = completedSetsSoFar;

    final exercisesDone = _logged
        .map((l) => l.exerciseName)
        .toSet()
        .where((name) =>
            _sequence.where((s) => s.name == name).length ==
            _logged.where((l) => l.exerciseName == name).length)
        .length;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: close button only (timer moved below progress bar)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.close_rounded,
                    onPressed: _handleBackPressed,
                  ),
                ],
              ),
            ),
            // Progress info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EXERCISE ${exercisesDone + 1} / $_totalExercises',
                        style: bodyStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.inkDim,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Set ${currentSetIndex + 1} / $totalSetsForExercise',
                        style: bodyStyle(fontSize: 12, color: c.inkDim),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(totalSetsForExercise, (i) {
                      final done = i < currentSetIndex;
                      final active = i == currentSetIndex;
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                              right: i < totalSetsForExercise - 1 ? 3 : 0),
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: done
                                ? c.accent
                                : active
                                    ? c.ink
                                    : c.hairline,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Item 1.3 — centred elapsed timer below progress bar
            Text(
              _fmtElapsed(),
              style: monoStyle(fontSize: 28, color: c.inkDim),
            ),
            const SizedBox(height: 2),
            // Hero content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Exercise name
                    Text(
                      e.name,
                      style: displayStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -0.6,
                        height: 1.05,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    // Hero numbers — Item 1.2: hide weight when 0
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _BigNumber(
                          value: _actualRepsCtrl.text.isEmpty
                              ? '${e.reps}'
                              : _actualRepsCtrl.text,
                          label: 'reps',
                          onChanged: (v) => setState(
                              () => _actualRepsCtrl.text = v),
                        ),
                        if (e.weight > 0) ...[
                          Container(
                            width: 1,
                            height: 64,
                            color: c.hairline,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 28),
                          ),
                          _BigNumber(
                            value: _actualWeightCtrl.text.isEmpty
                                ? '${e.weight}'
                                : _actualWeightCtrl.text,
                            label: 'weight',
                            unit: 'kg',
                            decimal: true,
                            onChanged: (v) => setState(
                                () => _actualWeightCtrl.text = v),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (nextEx != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chevron_right_rounded,
                              size: 12, color: c.inkMute),
                          const SizedBox(width: 4),
                          Text(
                            'Next: ${nextEx.name}',
                            style: bodyStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: c.inkMute,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            // CTA + skip
            Padding(
              padding: EdgeInsets.fromLTRB(
                  18, 0, 18, 16 + MediaQuery.of(context).padding.bottom),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _finishSet,
                    child: Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius:
                            BorderRadius.circular(kRadius + 6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded,
                              size: 22, color: c.accentInk),
                          const SizedBox(width: 10),
                          Text(
                            'Set complete',
                            style: bodyStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: c.accentInk,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Skip set',
                    kind: ButtonKind.ghost,
                    onPressed: _skipSet,
                    full: true,
                    small: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _totalExercises =>
      _sequence.map((e) => e.name).toSet().length;

  // ─── Rest timer view ──────────────────────────────────────────────────
  Widget _buildRestView() {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final nextEx =
        _index + 1 < _sequence.length ? _sequence[_index + 1] : null;
    final progress = _restTotal > 0
        ? (1.0 - _restSecondsRemaining / _restTotal).clamp(0.0, 1.0)
        : 1.0;

    String fmtSec(int s) {
      final m = s ~/ 60, r = s % 60;
      return '$m:${r.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.close_rounded,
                    onPressed: _handleBackPressed,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _togglePause,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _isPaused ? 'RESUME' : 'RESTING',
                        style: bodyStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.inkDim,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Item 1.3 — centred elapsed timer (rest view)
            Text(
              _fmtElapsed(),
              style: monoStyle(fontSize: 28, color: c.inkDim),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Item 1.5 — exercise info ABOVE the ring
                    if (nextEx != null) ...[
                      Text(
                        'SET ${_loggedSetsFor(nextEx.name) + 1}',
                        style: bodyStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: c.inkMute,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        nextEx.name,
                        style: displayStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                          color: c.ink,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      // Item 1.2 — omit weight if 0
                      Text(
                        nextEx.weight > 0
                            ? '${nextEx.reps} × ${nextEx.weight}kg'
                            : '${nextEx.reps} reps',
                        style: bodyStyle(
                          fontSize: 15,
                          color: c.inkDim,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: c.hairline, thickness: 1),
                      const SizedBox(height: 16),
                    ],
                    // Circular timer — constrained to 200×200
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(200, 200),
                            painter: _RingPainter(
                              progress: progress,
                              trackColor: c.hairline,
                              progressColor: c.accent,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                fmtSec(_restSecondsRemaining),
                                style: displayStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w400,
                                  color: c.ink,
                                  letterSpacing: -3,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'of ${_restTotal}s rest',
                                style: bodyStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: c.inkMute,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Item 1.1 — −15s | +15s | Skip rest
            Padding(
              padding: EdgeInsets.fromLTRB(
                  18, 0, 18, 16 + MediaQuery.of(context).padding.bottom),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: '15s',
                      kind: ButtonKind.outline,
                      icon: Icons.remove_rounded,
                      onPressed: () => _subtractRestTime(15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: '15s',
                      kind: ButtonKind.outline,
                      icon: Icons.add_rounded,
                      onPressed: () => _addRestTime(15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'Skip rest',
                      icon: Icons.skip_next_rounded,
                      onPressed: _skipRest,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _loggedSetsFor(String name) =>
      _logged.where((l) => l.exerciseName == name).length;
}

// ─── Big editable number widget ───────────────────────────────────────
class _BigNumber extends StatefulWidget {
  final String value;
  final String label;
  final String? unit;
  final bool decimal;
  final ValueChanged<String> onChanged;

  const _BigNumber({
    required this.value,
    required this.label,
    this.unit,
    this.decimal = false,
    required this.onChanged,
  });

  @override
  State<_BigNumber> createState() => _BigNumberState();
}

class _BigNumberState extends State<_BigNumber> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_BigNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 90,
              child: TextField(
                controller: _ctrl,
                keyboardType: widget.decimal
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.number,
                textAlign: TextAlign.center,
                style: displayStyle(
                  fontSize: 84,
                  fontWeight: FontWeight.w400,
                  color: c.ink,
                  letterSpacing: -3,
                  height: 0.9,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: widget.onChanged,
              ),
            ),
            if (widget.unit != null)
              Text(
                widget.unit!,
                style: bodyStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: c.inkDim,
                  letterSpacing: 0,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.label.toUpperCase(),
          style: bodyStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: c.inkMute,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ─── Circular ring painter ─────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 3.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}
