import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/domain/models/workout_slot.dart';
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
  late final List<WorkoutSlot> _sequence;
  late final DateTime _startedAt;

  int _index = 0;
  final List<LoggedSet> _logged = [];

  // Rest timer
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  int _restTotal = 0;
  bool _isResting = false;
  bool _isPaused = false;

  // Elapsed timer
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  // Countdown (Phase 2.3)
  bool _isCountingDown = true;
  int _countdownSeconds = 5;
  Timer? _countdownTimer;

  // Audio (Phase 2.2)
  late final AudioPlayer _audioPlayer;

  final _actualRepsCtrl = TextEditingController();
  final _actualWeightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _sequence = widget.workout.generateWorkoutSlots();
    _startedAt = DateTime.now();
    _audioPlayer = AudioPlayer();
    if (_sequence.isNotEmpty) {
      _prefillControllers();
      _startCountdown();
    } else {
      _isCountingDown = false;
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _restTimer?.cancel();
    _elapsedTimer?.cancel();
    _countdownTimer?.cancel();
    _audioPlayer.dispose();
    _actualRepsCtrl.dispose();
    _actualWeightCtrl.dispose();
    super.dispose();
  }

  // ─── Countdown (Phase 2.3) ───────────────────────────────────────────
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdownSeconds <= 1) {
        t.cancel();
        setState(() {
          _isCountingDown = false;
          _countdownSeconds = 0;
        });
        _vibrate(250);
        HapticFeedback.heavyImpact();
        _startElapsedTimer();
      } else {
        setState(() => _countdownSeconds--);
        _beep();
      }
    });
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  // ─── Feedback helpers (Phase 2.2) ────────────────────────────────────
  Future<void> _beep() async {
    try {
      await _audioPlayer.play(BytesSource(_generateBeepWav()));
    } catch (_) {
      // Ignore if audio fails — vibration is primary feedback
    }
    _vibrate(80);
  }

  void _vibrate(int durationMs) {
    Vibration.hasVibrator().then((has) {
      if (has == true) {
        Vibration.vibrate(duration: durationMs);
      } else {
        HapticFeedback.mediumImpact();
      }
    });
  }

  /// Generates a 250 ms 880 Hz sine-wave WAV in memory — no bundled asset needed.
  Uint8List _generateBeepWav({
    double frequency = 880.0,
    int durationMs = 250,
    int sampleRate = 44100,
  }) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final pcm = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Fade in/out over first/last 10 ms to avoid clicks
      final fadeSamples = (sampleRate * 0.01).round();
      double envelope = 1.0;
      if (i < fadeSamples) envelope = i / fadeSamples;
      if (i > numSamples - fadeSamples) {
        envelope = (numSamples - i) / fadeSamples;
      }
      pcm[i] = (32767 * 0.5 * envelope * math.sin(2 * math.pi * frequency * t))
          .round()
          .clamp(-32768, 32767);
    }

    final header = ByteData(44);
    final dataLen = numSamples * 2;
    // RIFF header
    for (final entry in {
      0: 0x52, 1: 0x49, 2: 0x46, 3: 0x46, // 'RIFF'
      8: 0x57, 9: 0x41, 10: 0x56, 11: 0x45, // 'WAVE'
      12: 0x66, 13: 0x6D, 14: 0x74, 15: 0x20, // 'fmt '
      36: 0x64, 37: 0x61, 38: 0x74, 39: 0x61, // 'data'
    }.entries) {
      header.setUint8(entry.key, entry.value);
    }
    header.setUint32(4, 36 + dataLen, Endian.little);
    header.setUint32(16, 16, Endian.little);  // fmt chunk size
    header.setUint16(20, 1, Endian.little);   // PCM
    header.setUint16(22, 1, Endian.little);   // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little);   // block align
    header.setUint16(34, 16, Endian.little);  // bits per sample
    header.setUint32(40, dataLen, Endian.little);

    final bytes = Uint8List(44 + dataLen);
    bytes.setAll(0, header.buffer.asUint8List());
    bytes.setAll(44, pcm.buffer.asUint8List());
    return bytes;
  }

  // ─── Exercise helpers ────────────────────────────────────────────────
  void _prefillControllers() {
    if (_index < _sequence.length) {
      final e = _sequence[_index].exercise;
      _actualRepsCtrl.text = e.reps.toString();
      _actualWeightCtrl.text = e.weight.toString();
    }
  }

  void _finishSet() {
    final slot = _sequence[_index];
    final e = slot.exercise;
    final actualReps = int.tryParse(_actualRepsCtrl.text) ?? e.reps;
    final actualWeight = double.tryParse(_actualWeightCtrl.text) ?? e.weight;
    _logged.add(LoggedSet(
      exerciseName: e.name,
      targetReps: e.reps,
      targetWeight: e.weight,
      actualReps: actualReps,
      actualWeight: actualWeight,
      skipped: false,
    ));
    _vibrate(150);
    _advance();
  }

  void _skipSet() {
    final slot = _sequence[_index];
    final e = slot.exercise;
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
    final slot = _sequence[_index];
    final restSecs = slot.restAfter.inSeconds;
    if (restSecs <= 0) {
      // Intra-superset instant transition
      setState(() {
        _index++;
        _isResting = false;
      });
      _prefillControllers();
      return;
    }
    setState(() {
      _isResting = true;
      _restSecondsRemaining = restSecs;
      _restTotal = restSecs;
      _isPaused = false;
    });
    _startRestTimer();
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _restSecondsRemaining--);
      if (_restSecondsRemaining <= 3 && _restSecondsRemaining > 0) {
        _beep();
      }
      if (_restSecondsRemaining <= 0) {
        t.cancel();
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

  void _addRestTime(int extra) {
    setState(() => _restSecondsRemaining += extra);
  }

  void _subtractRestTime(int secs) {
    setState(() {
      _restSecondsRemaining =
          (_restSecondsRemaining - secs).clamp(0, _restTotal + 3600);
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
    if (_logged.isEmpty && _isCountingDown) {
      Navigator.of(context).pop();
      return;
    }
    if (_logged.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final choice = await _showExitDialog();
    if (choice == 'save') {
      await _finishWorkout(completed: false);
    } else if (choice == 'discard') {
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
                style: bodyStyle(fontSize: 14, color: c.inkDim, height: 1.5)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: AppButton(
                        label: 'Discard',
                        kind: ButtonKind.outline,
                        onPressed: () => Navigator.pop(ctx, 'discard'))),
                const SizedBox(width: 10),
                Expanded(
                    child: AppButton(
                        label: 'Save progress',
                        onPressed: () => Navigator.pop(ctx, 'save'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Progress helpers ────────────────────────────────────────────────
  List<String> get _orderedSupersetIds {
    final seen = <String>[];
    for (final slot in _sequence) {
      if (!seen.contains(slot.supersetId)) seen.add(slot.supersetId);
    }
    return seen;
  }

  int get _currentSupersetIndex =>
      _orderedSupersetIds.indexOf(_sequence[_index].supersetId);

  int get _totalSupersets => _orderedSupersetIds.length;

  String _fmtElapsed() {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPressed();
      },
      child: _sequence.isEmpty
          ? _buildEmptyState()
          : _isCountingDown
              ? _buildCountdownView()
              : (_isResting ? _buildRestView() : _buildExerciseView()),
    );
  }

  // ─── Empty state ─────────────────────────────────────────────────────
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
                Icon(Icons.warning_amber_rounded, size: 56, color: c.inkMute),
                const SizedBox(height: 18),
                Text(
                  'No sets to perform',
                  style: displayStyle(
                      fontSize: 24, fontWeight: FontWeight.w500, color: c.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Edit the workout to add exercises with sets > 0.',
                  style: bodyStyle(fontSize: 14, color: c.inkDim, height: 1.5),
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

  // ─── Countdown view (Phase 2.3) ───────────────────────────────────────
  Widget _buildCountdownView() {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.close_rounded,
                    onPressed: _handleBackPressed,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'GET READY',
                    style: bodyStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.inkMute,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_countdownSeconds',
                    style: displayStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.w400,
                      color: c.ink,
                      letterSpacing: -8,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.workout.name,
                    style: bodyStyle(fontSize: 15, color: c.inkDim),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Active exercise view ─────────────────────────────────────────────
  Widget _buildExerciseView() {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final slot = _sequence[_index];
    final e = slot.exercise;
    final nextSlot = _index + 1 < _sequence.length ? _sequence[_index + 1] : null;

    final currentSetIndex = slot.setNum - 1;
    final totalSets = slot.totalSets;
    final supersetIdx = _currentSupersetIndex;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header (close button only) ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.close_rounded,
                    onPressed: _handleBackPressed,
                  ),
                ],
              ),
            ),
            // ── Progress bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EXERCISE ${supersetIdx + 1} / $_totalSupersets',
                        style: bodyStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.inkDim,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Set ${currentSetIndex + 1} / $totalSets',
                        style: bodyStyle(fontSize: 12, color: c.inkDim),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(totalSets, (i) {
                      final done = i < currentSetIndex;
                      final active = i == currentSetIndex;
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                              right: i < totalSets - 1 ? 3 : 0),
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
            // ── Elapsed timer — centred, prominent (Phase 1.3) ───────
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _fmtElapsed(),
                style: monoStyle(fontSize: 28, color: c.inkDim),
              ),
            ),
            // ── Hero content ─────────────────────────────────────────
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
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
                    // Reps | [Weight] (Phase 1.2: hide weight when 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _BigNumber(
                          value: _actualRepsCtrl.text.isEmpty
                              ? '${e.reps}'
                              : _actualRepsCtrl.text,
                          label: 'reps',
                          onChanged: (v) =>
                              setState(() => _actualRepsCtrl.text = v),
                        ),
                        if (e.weight > 0) ...[
                          Container(
                            width: 1,
                            height: 64,
                            color: c.hairline,
                            margin: const EdgeInsets.symmetric(horizontal: 28),
                          ),
                          _BigNumber(
                            value: _actualWeightCtrl.text.isEmpty
                                ? '${e.weight}'
                                : _actualWeightCtrl.text,
                            label: 'weight',
                            unit: 'kg',
                            decimal: true,
                            onChanged: (v) =>
                                setState(() => _actualWeightCtrl.text = v),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Next exercise hint
                    if (nextSlot != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            slot.isIntraSuperset
                                ? Icons.swap_horiz_rounded
                                : Icons.chevron_right_rounded,
                            size: 12,
                            color: c.inkMute,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            slot.isIntraSuperset
                                ? 'Then: ${nextSlot.exercise.name}'
                                : 'Next: ${nextSlot.exercise.name}',
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
            // ── CTA ─────────────────────────────────────────────────
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
                        borderRadius: BorderRadius.circular(kRadius + 6),
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

  // ─── Rest view (Phase 1.5 redesign: exercise info above ring) ─────────
  Widget _buildRestView() {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final nextSlot =
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
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
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
            // Elapsed timer (Phase 1.3 — also in rest view)
            Text(
              _fmtElapsed(),
              style: monoStyle(fontSize: 28, color: c.inkDim),
            ),
            const SizedBox(height: 16),
            // Exercise info ABOVE ring (Phase 1.5)
            if (nextSlot != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    Text(
                      'SET ${nextSlot.setNum}',
                      style: bodyStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.inkMute,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nextSlot.exercise.name,
                      style: displayStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    // Phase 1.2: omit weight if 0
                    Text(
                      nextSlot.exercise.weight > 0
                          ? '${nextSlot.exercise.reps} × ${nextSlot.exercise.weight}kg'
                          : '${nextSlot.exercise.reps} reps',
                      style: bodyStyle(fontSize: 14, color: c.inkDim),
                    ),
                    const SizedBox(height: 18),
                    Divider(color: c.hairlineSoft, height: 1),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            // Ring timer
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
            const Spacer(),
            // −15s | +15s | Skip rest (Phase 1.1)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  18, 0, 18, 16 + MediaQuery.of(context).padding.bottom),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: '−15s',
                      kind: ButtonKind.outline,
                      icon: Icons.remove_rounded,
                      onPressed: () => _subtractRestTime(15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: '+15s',
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

// ─── Circular ring painter ────────────────────────────────────────────
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

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}
