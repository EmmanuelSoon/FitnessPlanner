import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/theme_provider.dart';

/// Bottom sheet that lets the user pick a color theme + light/dark mode.
/// Call via showAppearancePicker(context) from any ConsumerWidget.
void showAppearancePicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AppearancePicker(),
  );
}

class _AppearancePicker extends ConsumerWidget {
  const _AppearancePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider).value;
    if (themeState == null) return const SizedBox.shrink();

    final appTheme = themeState.appThemeData;
    final c = appTheme.c;
    final notifier = ref.read(themeProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(kRadius + 8),
        ),
      ),
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 12,
        bottom: 28 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Appearance',
                style: displayStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.close, size: 20, color: c.ink),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Theme label
          Text(
            'THEME',
            style: bodyStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.inkMute,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          // Theme tile grid (4×2)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
            itemCount: kAppColorThemes.length,
            itemBuilder: (context, index) {
              final entry = kAppColorThemes.entries.elementAt(index);
              final key = entry.key;
              final def = entry.value;
              final palette = themeState.isDark ? def.dark : def.light;
              final isSelected = key == themeState.themeKey;

              return GestureDetector(
                onTap: () => notifier.setThemeKey(key),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: palette.bg,
                          borderRadius:
                              BorderRadius.circular((kRadius - 6).clamp(10.0, double.infinity)),
                          border: Border.all(
                            color: isSelected ? palette.accent : c.hairline,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Mini card mockup
                            Positioned(
                              left: 7,
                              right: 7,
                              top: 8,
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color: palette.surface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: palette.hairlineSoft,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            // Title line
                            Positioned(
                              left: 7,
                              top: 27,
                              child: Container(
                                width: 22,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: palette.ink.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // Sub line
                            Positioned(
                              left: 7,
                              top: 35,
                              child: Container(
                                width: 14,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: palette.ink.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // FAB dot
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: palette.accent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      def.name,
                      style: bodyStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: 0.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // Mode label
          Text(
            'MODE',
            style: bodyStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.inkMute,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          // Light / Dark segmented control
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(kRadius),
            ),
            child: Row(
              children: [
                _ModeSegment(
                  label: 'Light',
                  icon: Icons.light_mode_outlined,
                  selected: !themeState.isDark,
                  onTap: () => notifier.setDark(false),
                  theme: appTheme,
                ),
                _ModeSegment(
                  label: 'Dark',
                  icon: Icons.dark_mode_outlined,
                  selected: themeState.isDark,
                  onTap: () => notifier.setDark(true),
                  theme: appTheme,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Done button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(kRadius),
              ),
              alignment: Alignment.center,
              child: Text(
                'Done',
                style: bodyStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.accentInk,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final AppThemeData theme;

  const _ModeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final c = theme.c;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadius - 3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? c.ink : c.inkMute,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: bodyStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? c.ink : c.inkMute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
