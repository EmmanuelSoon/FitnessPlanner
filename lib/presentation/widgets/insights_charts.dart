import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/material.dart';
import 'package:fitness_planner/theme/app_theme.dart';

/// A number with no meaningful decimal part shows as a bare integer
/// ("75"); otherwise one decimal place ("62.5"). Shared by every insights
/// card that prints a raw trend or record value.
String fmtTrimmedNumber(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

// ─── Nice-number axis scale ─────────────────────────────────────────────
//
// Classic Heckbert "nice numbers for graph labels" algorithm: gridlines land
// on numbers a person would actually choose (10, 20, 30 — never 13, 26.4,
// 39.8), and the range is padded outward to the nearest step rather than
// clipped exactly to the data's own min/max.

const int _kTargetYAxisTicks = 4;
const int _kMaxXAxisTicks = 4;
const double _kYAxisGutter = 34.0;
const double _kPadTop = 12.0;
const double _kPadBottom = 8.0;

double _niceNum(double range, {required bool round}) {
  if (range <= 0) return 1;
  final exponent = (math.log(range) / math.ln10).floor();
  final magnitude = math.pow(10, exponent).toDouble();
  final fraction = range / magnitude;

  final double niceFraction;
  if (round) {
    if (fraction < 1.5) {
      niceFraction = 1;
    } else if (fraction < 3) {
      niceFraction = 2;
    } else if (fraction < 7) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }
  } else {
    if (fraction <= 1) {
      niceFraction = 1;
    } else if (fraction <= 2) {
      niceFraction = 2;
    } else if (fraction <= 5) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }
  }
  return niceFraction * magnitude;
}

/// A padded, round-number axis: [min]/[max] bound at least [dataMin]/
/// [dataMax], [step] apart at [ticks].
class NiceScale {
  final double min;
  final double max;
  final double step;

  const NiceScale({required this.min, required this.max, required this.step});

  /// Every gridline value from [min] to [max] inclusive, [step] apart.
  List<double> get ticks {
    final count = ((max - min) / step).round();
    return [for (var i = 0; i <= count; i++) min + i * step];
  }
}

/// Computes a [NiceScale] spanning at least [dataMin]..[dataMax] with
/// roughly [targetTicks] gridlines. A flat series ([dataMin] == [dataMax])
/// is padded to a small range around the value instead of collapsing to a
/// zero-width, divide-by-zero axis.
NiceScale computeNiceScale(double dataMin, double dataMax, {int targetTicks = _kTargetYAxisTicks}) {
  var min = dataMin;
  var max = dataMax;
  if (min == max) {
    final pad = min == 0 ? 1.0 : min.abs() * 0.1;
    min -= pad;
    max += pad;
  }

  final range = _niceNum(max - min, round: false);
  final step = _niceNum(range / (targetTicks - 1), round: true);
  final niceMin = (min / step).floor() * step;
  final niceMax = (max / step).ceil() * step;
  return NiceScale(min: niceMin, max: niceMax, step: step);
}

/// Evenly spaced indices into a series of length [n] for x-axis date ticks,
/// always including the first and last index, up to [maxTicks] total. A
/// series no longer than [maxTicks] returns every index.
List<int> chartTickIndices(int n, {int maxTicks = _kMaxXAxisTicks}) {
  if (n <= 0) return const [];
  if (n <= maxTicks) return [for (var i = 0; i < n; i++) i];
  return {
    for (var k = 0; k < maxTicks; k++) (k * (n - 1) / (maxTicks - 1)).round(),
  }.toList()
    ..sort();
}

/// Fraction of the plot height from the top at which [v] falls between
/// [min] and [max] — 0 at the top, 1 at the bottom. On an inverted
/// (lower-is-better) axis the min value plots nearest the top.
double _fracFromTop(double v, double min, double max, bool invert) {
  final span = (max - min) == 0 ? 1 : (max - min);
  final t = (v - min) / span;
  return invert ? t : 1 - t;
}

// ─── Soft-area trend chart ─────────────────────────────────────────────
//
// A line with a soft gradient fill underneath, a baseline hairline, a live
// dot on the last point, and optional ringed markers for personal records.
// Hand-rolled (no chart package) to match the app's existing hand-rolled
// widget style.

class AreaTrendChart extends StatefulWidget {
  final List<double> series;
  final List<String>? pointLabels;
  final Set<int> prIndices;
  final bool invert;
  final double height;
  final String Function(double)? valueFormatter;
  final String? unitLabel;

  const AreaTrendChart({
    super.key,
    required this.series,
    this.pointLabels,
    this.prIndices = const {},
    this.invert = false,
    this.height = 108,
    this.valueFormatter,
    this.unitLabel,
  });

  @override
  State<AreaTrendChart> createState() => AreaTrendChartState();
}

/// Public so widget tests can read [touchedIndex] directly — the tooltip
/// itself is drawn on the canvas, not as inspectable widgets.
class AreaTrendChartState extends State<AreaTrendChart> {
  int? _touchedIndex;

  int? get touchedIndex => _touchedIndex;

  @override
  void didUpdateWidget(covariant AreaTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A pinned tooltip index is only meaningful for the dataset it was
    // touched on — e.g. switching the exercise-trend card's chip selects a
    // new series entirely, and a stale index could point at the wrong (or a
    // now out-of-range) point.
    if (!listEquals(oldWidget.series, widget.series) ||
        !listEquals(oldWidget.pointLabels, widget.pointLabels)) {
      _touchedIndex = null;
    }
  }

  void _handleTouch(Offset localPosition, double width) {
    final n = widget.series.length;
    final labels = widget.pointLabels;
    if (n == 0 || labels == null || labels.length != n) return;

    final plotWidth = width - _kYAxisGutter;
    if (plotWidth <= 0) return;

    final relativeDx = localPosition.dx - _kYAxisGutter;
    final idx = n <= 1
        ? 0
        : (relativeDx / plotWidth * (n - 1)).round().clamp(0, n - 1);
    if (idx != _touchedIndex) setState(() => _touchedIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    final series = widget.series;
    final valueFormatter = widget.valueFormatter ?? fmtTrimmedNumber;
    final labelStyle = bodyStyle(fontSize: 10, color: c.inkMute);

    final scale = series.isEmpty
        ? null
        : computeNiceScale(
            series.reduce((a, b) => a < b ? a : b),
            series.reduce((a, b) => a > b ? a : b),
          );

    final plotHeight = widget.height - _kPadTop - _kPadBottom;
    final pointLabels = widget.pointLabels;
    final tickIndices = pointLabels != null && pointLabels.isNotEmpty
        ? chartTickIndices(pointLabels.length)
        : const <int>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      // Horizontal-only (not onPan*) so a vertical swipe
                      // over the chart still loses the gesture arena to the
                      // page's own vertical ListView instead of scrubbing
                      // the tooltip.
                      onHorizontalDragDown: (d) => _handleTouch(d.localPosition, constraints.maxWidth),
                      onHorizontalDragUpdate: (d) => _handleTouch(d.localPosition, constraints.maxWidth),
                      child: CustomPaint(
                        painter: _AreaTrendPainter(
                          series: widget.series,
                          scale: scale,
                          prIndices: widget.prIndices,
                          invert: widget.invert,
                          accent: c.accent,
                          surface: c.surface,
                          hairline: c.hairline,
                          ink: c.ink,
                          touchedIndex: _touchedIndex,
                          pointLabels: widget.pointLabels,
                          valueFormatter: valueFormatter,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // IgnorePointer so a plain Text (whose RenderParagraph always
              // claims hitTestSelf) never steals a touch from the
              // GestureDetector beneath it — otherwise a drag starting on
              // top of a gridline label would silently fail to register.
              if (scale != null)
                for (final tick in scale.ticks)
                  Positioned(
                    top: (_kPadTop + _fracFromTop(tick, scale.min, scale.max, widget.invert) * plotHeight - 6)
                        .clamp(0.0, widget.height - 12),
                    left: 0,
                    child: IgnorePointer(child: Text(valueFormatter(tick), style: labelStyle)),
                  ),
              if (widget.unitLabel != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IgnorePointer(child: Text(widget.unitLabel!, style: labelStyle)),
                ),
            ],
          ),
        ),
        if (pointLabels != null && tickIndices.isNotEmpty) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 14,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final n = pointLabels.length;
                final plotLeft = _kYAxisGutter;
                final plotWidth = constraints.maxWidth - plotLeft;
                return Stack(
                  children: [
                    for (final i in tickIndices)
                      Positioned(
                        left: n <= 1 ? plotLeft : plotLeft + (i / (n - 1)) * plotWidth,
                        child: FractionalTranslation(
                          translation: Offset(i == 0 ? 0 : (i == n - 1 ? -1 : -0.5), 0),
                          child: Text(pointLabels[i], style: labelStyle),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _AreaTrendPainter extends CustomPainter {
  final List<double> series;
  final NiceScale? scale;
  final Set<int> prIndices;
  final bool invert;
  final Color accent;
  final Color surface;
  final Color hairline;
  final Color ink;
  final int? touchedIndex;
  final List<String>? pointLabels;
  final String Function(double) valueFormatter;

  const _AreaTrendPainter({
    required this.series,
    required this.scale,
    required this.prIndices,
    required this.invert,
    required this.accent,
    required this.surface,
    required this.hairline,
    required this.ink,
    this.touchedIndex,
    this.pointLabels,
    required this.valueFormatter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final scale = this.scale!;

    final plotLeft = _kYAxisGutter;
    final plotBottomY = size.height - _kPadBottom;
    final n = series.length;

    double x(int i) => n <= 1 ? plotLeft + (size.width - plotLeft) / 2 : plotLeft + (i / (n - 1)) * (size.width - plotLeft);
    double y(double v) => _kPadTop + _fracFromTop(v, scale.min, scale.max, invert) * (size.height - _kPadTop - _kPadBottom);

    final gridlinePaint = Paint()
      ..color = hairline
      ..strokeWidth = 1;
    for (final tick in scale.ticks) {
      final ty = y(tick);
      canvas.drawLine(Offset(plotLeft, ty), Offset(size.width, ty), gridlinePaint);
    }

    final points = [
      for (var i = 0; i < n; i++) Offset(x(i), y(series[i])),
    ];

    if (points.length > 1) {
      final fillPath = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath
        ..lineTo(points.last.dx, plotBottomY)
        ..lineTo(points.first.dx, plotBottomY)
        ..close();

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent.withValues(alpha: 0.20),
              accent.withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );

      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        linePath.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (final i in prIndices) {
      if (i < 0 || i >= points.length) continue;
      canvas.drawCircle(points[i], 4.5, Paint()..color = surface);
      canvas.drawCircle(
        points[i],
        4.5,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(points[i], 1.6, Paint()..color = accent);
    }

    canvas.drawCircle(points.last, 4, Paint()..color = accent);

    final labels = pointLabels;
    final touched = touchedIndex;
    if (touched != null &&
        labels != null &&
        labels.length == n &&
        touched >= 0 &&
        touched < points.length) {
      _paintTooltip(canvas, size, points[touched], labels[touched], series[touched]);
    }
  }

  void _paintTooltip(
    Canvas canvas,
    Size size,
    Offset point,
    String label,
    double value,
  ) {
    canvas.drawLine(
      Offset(point.dx, 0),
      Offset(point.dx, size.height),
      Paint()
        ..color = hairline
        ..strokeWidth = 1,
    );
    canvas.drawCircle(point, 5, Paint()..color = surface);
    canvas.drawCircle(
      point,
      5,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(point, 2, Paint()..color = ink);

    final text = '$label · ${valueFormatter(value)}';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: bodyStyle(fontSize: 11, fontWeight: FontWeight.w600, color: surface),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const paddingH = 8.0;
    const paddingV = 5.0;
    final pillWidth = textPainter.width + paddingH * 2;
    final pillHeight = textPainter.height + paddingV * 2;
    var pillLeft = point.dx - pillWidth / 2;
    final maxLeft = size.width - pillWidth > 0 ? size.width - pillWidth : 0.0;
    pillLeft = pillLeft.clamp(0.0, maxLeft);
    const pillTop = 0.0;

    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pillLeft, pillTop, pillWidth, pillHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(pillRect, Paint()..color = ink);
    textPainter.paint(canvas, Offset(pillLeft + paddingH, pillTop + paddingV));
  }

  @override
  bool shouldRepaint(covariant _AreaTrendPainter oldDelegate) =>
      !listEquals(oldDelegate.series, series) ||
      !setEquals(oldDelegate.prIndices, prIndices) ||
      oldDelegate.touchedIndex != touchedIndex ||
      !listEquals(oldDelegate.pointLabels, pointLabels) ||
      oldDelegate.invert != invert ||
      oldDelegate.accent != accent ||
      oldDelegate.ink != ink;
}

// ─── Pill segmented control ─────────────────────────────────────────────

class SegmentedControl extends StatelessWidget {
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool small;

  const SegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                    vertical: small ? 6 : 9,
                    horizontal: small ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: option == value ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: option == value ? cardShadow(theme.isDark) : null,
                  ),
                  child: Text(
                    option,
                    textAlign: TextAlign.center,
                    style: bodyStyle(
                      fontSize: small ? 12 : 13,
                      fontWeight:
                          option == value ? FontWeight.w600 : FontWeight.w500,
                      color: option == value ? c.ink : c.inkDim,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
