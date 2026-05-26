import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// ─── Header bar (replaces AppBar) ─────────────────────────────────────
class AppHeaderBar extends StatelessWidget {
  final String? title;
  final Widget? leading;
  final Widget? trailing;

  const AppHeaderBar({
    super.key,
    this.title,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
      child: Row(
        children: [
          leading ?? const SizedBox(width: 36),
          Expanded(
            child: title != null
                ? Text(
                    title!,
                    textAlign: TextAlign.center,
                    style: bodyStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.c.inkDim,
                      letterSpacing: 0.3,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          trailing ?? const SizedBox(width: 36),
        ],
      ),
    );
  }
}

// ─── Icon button (square, borderless) ─────────────────────────────────
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool danger;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.danger = false,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20),
        color: danger ? theme.c.danger : theme.c.ink,
        onPressed: onPressed,
      ),
    );
  }
}

// ─── Primary button (full-width or inline) ────────────────────────────
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final bool full;
  final IconData? icon;
  final bool small;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = ButtonKind.primary,
    this.full = false,
    this.icon,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final height = small ? 36.0 : 50.0;

    Color bg, fg;
    Border? border;

    switch (kind) {
      case ButtonKind.primary:
        bg = c.accent;
        fg = c.accentInk;
        border = null;
      case ButtonKind.secondary:
        bg = c.surfaceAlt;
        fg = c.ink;
        border = null;
      case ButtonKind.outline:
        bg = Colors.transparent;
        fg = c.ink;
        border = Border.all(color: c.hairline);
      case ButtonKind.ghost:
        bg = Colors.transparent;
        fg = c.ink;
        border = null;
      case ButtonKind.danger:
        bg = c.danger;
        fg = Colors.white;
        border = null;
      case ButtonKind.dangerOutline:
        bg = Colors.transparent;
        fg = c.danger;
        border = Border.all(color: c.hairline);
    }

    Widget child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 16 : 18, color: fg),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: bodyStyle(
              fontSize: small ? 13 : 15,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: height,
        width: full ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: small ? 14 : 22),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kRadius),
          border: border,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

enum ButtonKind { primary, secondary, outline, ghost, danger, dangerOutline }

// ─── Workout card ──────────────────────────────────────────────────────
class WorkoutListCard extends StatelessWidget {
  final String name;
  final int exerciseCount;
  final int? durationMinutes;
  final String? lastSession;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const WorkoutListCard({
    super.key,
    required this.name,
    required this.exerciseCount,
    this.durationMinutes,
    this.lastSession,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(kRadius),
          border: theme.isDark
              ? Border.all(color: c.hairlineSoft)
              : null,
          boxShadow: cardShadow(theme.isDark),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Row(
          children: [
            // Icon tile
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(
                    (kRadius - 8).clamp(8.0, double.infinity)),
              ),
              child: Icon(Icons.fitness_center_rounded,
                  size: 22, color: c.accent),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: displayStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '$exerciseCount exercises',
                        style: bodyStyle(
                            fontSize: 13, color: c.inkDim, letterSpacing: 0.1),
                      ),
                      if (durationMinutes != null) ...[
                        Text(' · ',
                            style: bodyStyle(
                                fontSize: 13,
                                color: c.inkMute,
                                letterSpacing: 0)),
                        Text(
                          _fmtDur(durationMinutes!),
                          style: bodyStyle(
                              fontSize: 13,
                              color: c.inkDim,
                              letterSpacing: 0.1),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.edit_outlined, size: 18, color: c.inkMute),
                      onPressed: onEdit,
                    ),
                  ),
                if (onDelete != null)
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.inkMute),
                      onPressed: onDelete,
                    ),
                  ),
                Icon(Icons.chevron_right_rounded, size: 18, color: c.inkMute),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDur(int min) {
    if (min < 60) return '$min min';
    final h = min ~/ 60;
    final m = min % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
}

// ─── Swatch glyph (4 dots arranged in 2×2) ────────────────────────────
class SwatchGlyph extends StatelessWidget {
  final double size;
  final Color accentColor;
  final Color inkColor;

  const SwatchGlyph({
    super.key,
    this.size = 20,
    required this.accentColor,
    required this.inkColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = size / 5;
    return CustomPaint(
      size: Size(size, size),
      painter: _SwatchPainter(r: r, accentColor: accentColor, inkColor: inkColor),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  final double r;
  final Color accentColor;
  final Color inkColor;

  _SwatchPainter({required this.r, required this.accentColor, required this.inkColor});

  @override
  void paint(Canvas canvas, Size size) {
    final dots = [
      (size.width * 0.3, size.height * 0.35, accentColor, 1.0),
      (size.width * 0.65, size.height * 0.35, inkColor, 0.85),
      (size.width * 0.3, size.height * 0.7, inkColor, 0.55),
      (size.width * 0.65, size.height * 0.7, inkColor, 0.25),
    ];
    for (final (x, y, color, opacity) in dots) {
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.accentColor != accentColor || old.inkColor != inkColor;
}

// ─── FAB ──────────────────────────────────────────────────────────────
class AppFab extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;

  const AppFab({
    super.key,
    this.onPressed,
    this.icon = Icons.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: theme.c.accent,
          borderRadius: BorderRadius.circular(kRadius + 12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 12),
              spreadRadius: -8,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Icon(icon, color: theme.c.accentInk, size: 22),
      ),
    );
  }
}

// ─── Stat chip (used in preview screen) ───────────────────────────────
class StatChip extends StatelessWidget {
  final String value;
  final String label;

  const StatChip({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    return Column(
      children: [
        Text(
          value,
          style: displayStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: theme.c.ink,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: bodyStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: theme.c.inkMute,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
