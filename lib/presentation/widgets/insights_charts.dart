import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/material.dart';
import 'package:fitness_planner/theme/app_theme.dart';

// ─── Soft-area trend chart ─────────────────────────────────────────────
//
// A line with a soft gradient fill underneath, a baseline hairline, a live
// dot on the last point, and optional ringed markers for personal records.
// Hand-rolled (no chart package) to match the app's existing hand-rolled
// widget style.

class AreaTrendChart extends StatelessWidget {
  final List<double> series;
  final List<String>? edgeLabels;
  final Set<int> prIndices;
  final bool invert;
  final double height;

  const AreaTrendChart({
    super.key,
    required this.series,
    this.edgeLabels,
    this.prIndices = const {},
    this.invert = false,
    this.height = 108,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _AreaTrendPainter(
              series: series,
              prIndices: prIndices,
              invert: invert,
              accent: c.accent,
              surface: c.surface,
              hairline: c.hairline,
            ),
          ),
        ),
        if (edgeLabels != null && edgeLabels!.length >= 2) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(edgeLabels!.first,
                  style: bodyStyle(fontSize: 10, color: c.inkMute)),
              Text(edgeLabels!.last,
                  style: bodyStyle(fontSize: 10, color: c.inkMute)),
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

  const _AreaTrendPainter({
    required this.series,
    required this.prIndices,
    required this.invert,
    required this.accent,
    required this.surface,
    required this.hairline,
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
  }

  @override
  bool shouldRepaint(covariant _AreaTrendPainter oldDelegate) =>
      !listEquals(oldDelegate.series, series) ||
      !setEquals(oldDelegate.prIndices, prIndices) ||
      oldDelegate.invert != invert ||
      oldDelegate.accent != accent;
}

// ─── Two-number stat strip ───────────────────────────────────────────────
//
// Cells sit side by side with a hairline divider between them — used for
// "This week" summaries where the figures (e.g. tonnage vs. reps) are
// deliberately never added together.

class StatCell {
  final String value;
  final String? unit;
  final String label;

  const StatCell({required this.value, this.unit, required this.label});
}

class StatStrip extends StatelessWidget {
  final List<StatCell> cells;

  const StatStrip({super.key, required this.cells});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: theme.isDark ? Border.all(color: c.hairlineSoft) : null,
        boxShadow: cardShadow(theme.isDark),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : Border(left: BorderSide(color: c.hairlineSoft)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          cells[i].value,
                          style: displayStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (cells[i].unit != null) ...[
                          const SizedBox(width: 2),
                          Text(
                            cells[i].unit!,
                            style: bodyStyle(fontSize: 12, color: c.inkDim),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cells[i].label.toUpperCase(),
                      style: bodyStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: c.inkMute,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
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
