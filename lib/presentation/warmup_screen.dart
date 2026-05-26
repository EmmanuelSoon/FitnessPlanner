import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/presentation/workout_session_screen.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/theme/app_theme.dart';

class WarmupScreen extends StatefulWidget {
  final Workout workout;
  const WarmupScreen({super.key, required this.workout});

  @override
  State<WarmupScreen> createState() => _WarmupScreenState();
}

class _WarmupScreenState extends State<WarmupScreen> {
  int _index = 0;

  // "Get ready" interstitial between exercises
  bool _isGetReady = false;
  int _getReadySeconds = 3;

  // Timed exercise countdown
  int _timedSecondsRemaining = 0;
  int _timedTotal = 0;

  Timer? _timer;

  List<Exercise> get _warmup => widget.workout.warmup;

  @override
  void initState() {
    super.initState();
    if (_warmup.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToWorkout());
    } else {
      _startCurrentExercise();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCurrentExercise() {
    final ex = _warmup[_index];
    if (ex.timedDuration != null) {
      setState(() {
        _timedSecondsRemaining = ex.timedDuration!.inSeconds;
        _timedTotal = ex.timedDuration!.inSeconds;
        _isGetReady = false;
      });
      _startTimer();
    } else {
      setState(() => _isGetReady = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timedSecondsRemaining--);
      if (_timedSecondsRemaining <= 0) {
        t.cancel();
        _advanceExercise();
      }
    });
  }

  void _advanceExercise() {
    _timer?.cancel();
    if (_index >= _warmup.length - 1) {
      _goToWorkout();
      return;
    }
    // Show 3-second "Get ready" interstitial
    setState(() {
      _isGetReady = true;
      _getReadySeconds = 3;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _getReadySeconds - 1;
      if (next > 0) {
        setState(() => _getReadySeconds = next);
      } else {
        t.cancel();
        setState(() {
          _index++;
          _isGetReady = false;
        });
        _startCurrentExercise();
      }
    });
  }

  void _skipExercise() {
    _timer?.cancel();
    _advanceExercise();
  }

  void _goToWorkout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(workout: widget.workout),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_warmup.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_isGetReady) {
      return _buildGetReady();
    }
    final ex = _warmup[_index];
    if (ex.timedDuration != null) {
      return _buildTimedExercise(ex);
    }
    return _buildRepExercise(ex);
  }

  // ─── Get-ready interstitial ───────────────────────────────────────────
  Widget _buildGetReady() {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final nextIndex = _index + 1;
    final nextEx = nextIndex < _warmup.length ? _warmup[nextIndex] : null;

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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.inkMute,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$_getReadySeconds',
                style: monoStyle(fontSize: 96, color: c.ink),
              ),
              if (nextEx != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Up next',
                  style: bodyStyle(fontSize: 12, color: c.inkMute),
                ),
                const SizedBox(height: 6),
                Text(
                  nextEx.name,
                  style: displayStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Timed exercise view ──────────────────────────────────────────────
  Widget _buildTimedExercise(Exercise ex) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final progress = _timedTotal > 0
        ? (1.0 - _timedSecondsRemaining / _timedTotal).clamp(0.0, 1.0)
        : 1.0;

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
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    'WARM-UP · ${_index + 1} / ${_warmup.length}',
                    style: bodyStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.inkDim,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ring timer (200×200)
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(200, 200),
                          painter: _WarmupRingPainter(
                            progress: progress,
                            trackColor: c.hairline,
                            progressColor: c.accent,
                          ),
                        ),
                        Text(
                          '$_timedSecondsRemaining',
                          style: displayStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w400,
                            color: c.ink,
                            letterSpacing: -3,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Exercise name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      ex.name,
                      style: displayStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${ex.timedDuration!.inSeconds}s',
                    style: bodyStyle(
                      fontSize: 13,
                      color: c.inkMute,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  18, 0, 18, 16 + MediaQuery.of(context).padding.bottom),
              child: AppButton(
                label: 'Skip',
                kind: ButtonKind.outline,
                icon: Icons.skip_next_rounded,
                full: true,
                onPressed: _skipExercise,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Rep-based exercise view (future-proof) ───────────────────────────
  Widget _buildRepExercise(Exercise ex) {
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
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    'WARM-UP · ${_index + 1} / ${_warmup.length}',
                    style: bodyStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.inkDim,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ex.name,
                    style: displayStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${ex.reps} reps',
                    style: bodyStyle(
                      fontSize: 20,
                      color: c.inkDim,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  18, 0, 18, 16 + MediaQuery.of(context).padding.bottom),
              child: AppButton(
                label: 'Done',
                icon: Icons.check_rounded,
                full: true,
                onPressed: _skipExercise,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ring painter for warm-up screen ─────────────────────────────────
class _WarmupRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  const _WarmupRingPainter({
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
  bool shouldRepaint(_WarmupRingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}
