import 'package:flutter/material.dart';
import '../../domain/models/workout.dart';
import '../../theme/app_theme.dart';

void showWorkoutPicker({
  required BuildContext context,
  required List<Workout> workouts,
  String? selectedWorkoutId,
  required void Function(String? workoutId) onSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WorkoutPickerSheet(
      workouts: workouts,
      selectedWorkoutId: selectedWorkoutId,
      onSelected: onSelected,
    ),
  );
}

class _WorkoutPickerSheet extends StatelessWidget {
  final List<Workout> workouts;
  final String? selectedWorkoutId;
  final void Function(String? workoutId) onSelected;

  const _WorkoutPickerSheet({
    required this.workouts,
    required this.selectedWorkoutId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    final isDark = AppThemeData.of(context).isDark;
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius + 8)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              'Choose workout',
              style: displayStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: c.ink,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Rest day option
                _PickerTile(
                  icon: Icons.hotel_rounded,
                  label: 'Rest day',
                  isSelected: selectedWorkoutId == null,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(null);
                  },
                ),
                if (workouts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Divider(color: c.hairline, height: 1),
                  const SizedBox(height: 8),
                  ...workouts.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _PickerTile(
                      icon: Icons.fitness_center_rounded,
                      label: w.name,
                      isSelected: selectedWorkoutId == w.id,
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(context);
                        onSelected(w.id);
                      },
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? c.accent.withValues(alpha: 0.12) : c.surfaceAlt,
          borderRadius: BorderRadius.circular(kRadius - 4),
          border: isSelected ? Border.all(color: c.accent.withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? c.accent.withValues(alpha: 0.2) : c.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: isSelected ? c.accent : c.inkDim),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: bodyStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? c.accent : c.ink,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, size: 18, color: c.accent),
          ],
        ),
      ),
    );
  }
}
