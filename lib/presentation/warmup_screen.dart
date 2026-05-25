import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final List<Exercise> _warmup;
  int _index = 0;

  // Countdown between exercises (3s "Get ready" interstitial)
  bool _isInterstitial = false;
  int _interstitialSeconds = 3;
  Timer? _interstitialTimer;

  // Timed exercise countdown
  int _timedSecondsRemaining = 0;
  int _timedTotal = 0;
  Timer? _timedTimer;

  @override
  void initState() {
    super.initState();
    _warmup = widget.workout.warmup;
    _startCurrentExercise();
  }

  @override
  void dispose() {
    _interstitialTimer?.cancel();
    _timedTimer?.cancel();
    super.dispose();
  }

  Exercise get _current => _warmup[_index];

  void _startCurrentExercise() {
    _timedTimer?.cancel();
    final ex = _warmup[_index];
    if (ex.timedDuration != null) {
      setState(() {
        _timedSecondsRemaining = ex.timedDuration!.inSeconds;
        _timedTotal = ex.timedDuration!.inSeconds;
      });
      _timedTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        if (_timedSecondsRemaining <= 1) {
          t.cancel();
          _onExerciseDone();
        } else {
          setState(() => _timedSecondsRemaining--);
          if (_timedSecondsRemaining <= 3) {
            HapticFeedback.lightImpact();
          }
        }
      });
    }
  }

  void _onExerciseDone() {
    if (_index >= _warmup.length - 1) {
      _goToWorkout();
      return;
    }
    // Show 3-second interstitial
    setState(() {
      _isInterstitial = true;
      _interstitialSeconds = 3;
    });
    _interstitialTimer?.cancel();
    _interstitialTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_interstitialSeconds <= 1) {
        t.cancel();
        setState(() {
          _isInterstitial = false;
          _index++;
        });
        _startCurrentExercise();
      } else {
        setState(() => _interstitialSeconds--);
      }
    });
  }

  void _skipCurrent() {
    _timedTimer?.cancel();
    _interstitialTimer?.cancel();
    if (_isInterstitial) {
      setState(() { _isInterstitial = false; _index++; });
      _startCurrentExercise();
    } else {
      _onExerciseDone();
    }
  }

  void _goToWorkout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => WorkoutSessionScreen(workout: widget.workout)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    if (_isInterstitial) return _buildInterstitial(c);
    return _buildExercise(c);
  }

  // ─── 3-second "get ready" screen ─────────────────────────────────────
  Widget _buildInterstitial(AppColors c) {
    final next = _index + 1 < _warmup.length ? _warmup[_index + 1] : null;
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
                    onPressed: () => Navigator.of(context).pop(),
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
                    '$_interstitialSeconds',
                    style: displayStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.w400,
                      color: c.ink,
                      letterSpacing: -6,
                      height: 1.0,
                    ),
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      next.name,
                      style: displayStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: c.inkDim,
                        letterSpacing: -0.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 16 + MediaQuery.of(context).padding.bottom),
              child: AppButton(
                label: 'Skip',
                kind: ButtonKind.ghost,
                full: true,
                small: true,
                onPressed: _skipCurrent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Active warmup exercise ───────────────────────────────────────────
  Widget _buildExercise(AppColors c) {
    final ex = _current;
    final isTimed = ex.timedDuration != null;
    final progress = isTimed && _timedTotal > 0
        ? (1.0 - _timedSecondsRemaining / _timedTotal).clamp(0.0, 1.0)
        : 0.0;

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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    'WARM-UP  ${_index + 1} / ${_warmup.length}',
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ex.name,
                      style: displayStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -0.6,
                        height: 1.05,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (isTimed) ...[
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
                                  '$_timedSecondsRemaining',
                                  style: displayStyle(
                                    fontSize: 72,
                                    fontWeight: FontWeight.w400,
                                    color: c.ink,
                                    letterSpacing: -3,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  'seconds',
                                  style: bodyStyle(
                                    fontSize: 11,
                                    color: c.inkMute,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Rep-based (future use)
                      Text(
                        '${ex.reps}',
                        style: displayStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w400,
                          color: c.ink,
                          letterSpacing: -3,
                        ),
                      ),
                      Text(
                        'reps',
                        style: bodyStyle(fontSize: 14, color: c.inkMute),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 16 + MediaQuery.of(context).padding.bottom),
              child: Column(
                children: [
                  if (!isTimed)
                    AppButton(
                      label: 'Done',
                      full: true,
                      onPressed: _onExerciseDone,
                    ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Skip',
                    kind: ButtonKind.ghost,
                    full: true,
                    small: true,
                    onPressed: _skipCurrent,
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

// ─── Ring painter (same as session screen) ────────────────────────────
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
