import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/material.dart';
import 'package:fitness_planner/theme/app_theme.dart';

/// A number with no meaningful decimal part shows as a bare integer
/// ("75"); otherwise one decimal place ("62.5"). Shared by every insights
/// card that prints a raw trend or record value.
String fmtTrimmedNumber(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

// ─── Soft-area trend chart ─────────────────────────────────────────────
//
// A line with a soft gradient fill underneath, a baseline hairline, a live
// dot on the last point, and optional ringed markers for personal records.
// Hand-rolled (no chart package) to match the app's existing hand-rolled
// widget style.

class AreaTrendChart extends StatefulWidget {
  final List<double> series;
  final List<String>? edgeLabels;
  final List<String>? pointLabels;
  final Set<int> prIndices;
  final bool invert;
  final double height;

  const AreaTrendChart({
    super.key,
    required this.series,
    this.edgeLabels,
    this.pointLabels,
    this.prIndices = const {},
    this.invert = false,
    this.height = 108,
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
    if (n == 0 || width <= 0 || labels == null || labels.length != n) return;

    final idx = n <= 1
        ? 0
        : (localPosition.dx / width * (n - 1)).round().clamp(0, n - 1);
    if (idx != _touchedIndex) setState(() => _touchedIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    final series = widget.series;
    final maxV = series.isEmpty ? null : series.reduce((a, b) => a > b ? a : b);
    final minV = series.isEmpty ? null : series.reduce((a, b) => a < b ? a : b);
    // On an inverted (lower-is-better) chart, the min value plots highest —
    // the label at the top of the box should match whatever visually reads
    // as "the top of the line".
    final topValue = widget.invert ? minV : maxV;
    final bottomValue = widget.invert ? maxV : minV;
    final labelStyle = bodyStyle(fontSize: 10, color: c.inkMute);
    // Every call site's edgeLabels are just the first/last of its
    // pointLabels — derive them here instead of repeating that at each of
    // the four chart call sites.
    final edgeLabels = widget.edgeLabels ??
        (widget.pointLabels != null && widget.pointLabels!.length >= 2
            ? [widget.pointLabels!.first, widget.pointLabels!.last]
            : null);

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
                          prIndices: widget.prIndices,
                          invert: widget.invert,
                          accent: c.accent,
                          surface: c.surface,
                          hairline: c.hairline,
                          ink: c.ink,
                          touchedIndex: _touchedIndex,
                          pointLabels: widget.pointLabels,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (topValue != null)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Text(fmtTrimmedNumber(topValue), style: labelStyle),
                ),
              if (bottomValue != null && bottomValue != topValue)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Text(fmtTrimmedNumber(bottomValue), style: labelStyle),
                ),
            ],
          ),
        ),
        if (edgeLabels != null && edgeLabels.length >= 2) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(edgeLabels.first, style: labelStyle),
              Text(edgeLabels.last, style: labelStyle),
            ],
          ),
        ],
      ],
    );
  }
}

class _AreaTrendPainter extends CustomPainter {
  final List<double> series;
  final Set<int> prIndices;
  final bool invert;
  final Color accent;
  final Color surface;
  final Color hairline;
  final Color ink;
  final int? touchedIndex;
  final List<String>? pointLabels;

  const _AreaTrendPainter({
    required this.series,
    required this.prIndices,
    required this.invert,
    required this.accent,
    required this.surface,
    required this.hairline,
    required this.ink,
    this.touchedIndex,
    this.pointLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padTop = 6.0;
    const padBottom = 8.0;
    final baselineY = size.height - padBottom;

    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      Paint()
        ..color = hairline
        ..strokeWidth = 1,
    );

    if (series.isEmpty) return;

    final min = series.reduce((a, b) => a < b ? a : b);
    final max = series.reduce((a, b) => a > b ? a : b);
    final span = (max - min) == 0 ? 1 : (max - min);
    final n = series.length;

    double x(int i) => n <= 1 ? size.width / 2 : (i / (n - 1)) * size.width;
    double y(double v) {
      var t = (v - min) / span;
      if (invert) t = 1 - t;
      return padTop + (1 - t) * (size.height - padTop - padBottom);
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
        ..lineTo(points.last.dx, baselineY)
        ..lineTo(points.first.dx, baselineY)
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

    final text = '$label · ${fmtTrimmedNumber(value)}';
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
