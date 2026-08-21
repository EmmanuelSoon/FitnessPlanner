import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fitness_planner/theme/app_theme.dart';

// ─── Whole-number scroll-wheel pickers ────────────────────────────────────
//
// Sets, reps and weight are all whole numbers, so they share one wheel sheet
// styled to match the existing rest/duration time pickers.

const int _kMaxSets = 10;
const int _kMaxReps = 50;
const int _kMaxWeightKg = 300;

/// Weights are whole kilograms — render them without a trailing `.0`.
String fmtWeight(double weight) => weight.round().toString();

void openSetsPicker(
  BuildContext context,
  int current,
  void Function(int) onSelect,
) {
  _openWholeNumberPicker(
    context: context,
    label: 'SETS',
    min: 1,
    max: _kMaxSets,
    current: current,
    onSelect: onSelect,
  );
}

void openRepsPicker(
  BuildContext context,
  int current,
  void Function(int) onSelect,
) {
  _openWholeNumberPicker(
    context: context,
    label: 'REPS',
    min: 1,
    max: _kMaxReps,
    current: current,
    onSelect: onSelect,
  );
}

void openWeightPicker(
  BuildContext context,
  double current,
  void Function(double) onSelect,
) {
  _openWholeNumberPicker(
    context: context,
    label: 'WEIGHT',
    unit: 'kg',
    min: 0,
    max: _kMaxWeightKg,
    current: current.round(),
    onSelect: (v) => onSelect(v.toDouble()),
  );
}

/// Minute:second wheel picker for rest/hold durations — shared between
/// create_workout.dart and workout_start_preview_screen.dart.
void openDurationPicker(
  BuildContext context,
  String label,
  Duration current,
  void Function(Duration) onSelect,
) {
  int selMin = current.inMinutes.clamp(0, 9);
  int selSecIdx = ((current.inSeconds % 60) ~/ 5).clamp(0, 11);

  showModalBottomSheet<void>(
    context: context,
    builder: (sheetCtx) {
      final c = AppThemeData.of(context).c;
      return SizedBox(
        height: 280,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: bodyStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.inkMute,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onSelect(
                        Duration(minutes: selMin, seconds: selSecIdx * 5),
                      );
                      Navigator.pop(sheetCtx);
                    },
                    child: Text(
                      'Done',
                      style: bodyStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'min',
                        style: bodyStyle(
                          fontSize: 11,
                          color: c.inkMute,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'sec',
                        style: bodyStyle(
                          fontSize: 11,
                          color: c.inkMute,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: selMin,
                      ),
                      itemExtent: 44,
                      onSelectedItemChanged: (i) => selMin = i,
                      children: List.generate(
                        10,
                        (i) => Center(
                          child: Text(
                            '$i',
                            style: displayStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: c.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: selSecIdx,
                      ),
                      itemExtent: 44,
                      onSelectedItemChanged: (i) => selSecIdx = i,
                      children: List.generate(
                        12,
                        (i) => Center(
                          child: Text(
                            (i * 5).toString().padLeft(2, '0'),
                            style: displayStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: c.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _openWholeNumberPicker({
  required BuildContext context,
  required String label,
  required int min,
  required int max,
  required int current,
  required void Function(int) onSelect,
  String? unit,
}) {
  int selected = current.clamp(min, max);
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetCtx) {
      final c = AppThemeData.of(context).c;
      return SizedBox(
        height: 280,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    unit == null ? label : '$label ($unit)',
                    style: bodyStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.inkMute,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onSelect(selected);
                      Navigator.pop(sheetCtx);
                    },
                    child: Text(
                      'Done',
                      style: bodyStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: selected - min,
                ),
                itemExtent: 44,
                onSelectedItemChanged: (i) => selected = i + min,
                children: List.generate(
                  max - min + 1,
                  (i) => Center(
                    child: Text(
                      '${i + min}',
                      style: displayStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
