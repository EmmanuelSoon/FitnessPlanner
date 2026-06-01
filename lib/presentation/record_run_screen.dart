import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/providers/run_providers.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/theme/app_theme.dart';

class RecordRunScreen extends ConsumerStatefulWidget {
  /// If provided the screen opens in edit mode, pre-filling all fields.
  final RunSession? existingRun;

  /// If provided the date picker will start on this date (used from calendar day-sheet).
  final DateTime? initialDate;

  const RecordRunScreen({super.key, this.existingRun, this.initialDate});

  @override
  ConsumerState<RecordRunScreen> createState() => _RecordRunScreenState();
}

class _RecordRunScreenState extends ConsumerState<RecordRunScreen> {
  late DateTime _date;
  late TimeOfDay _time;

  // Duration inputs (MM:SS or H:MM:SS stored as individual fields)
  int _durationHours = 0;
  int _durationMinutes = 0;
  int _durationSeconds = 0;

  final _distanceCtrl = TextEditingController(); // km
  final _hrCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _cadenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  RunType _runType = RunType.other;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingRun;
    if (existing != null) {
      _date = DateTime(existing.startedAt.year, existing.startedAt.month,
          existing.startedAt.day);
      _time = TimeOfDay.fromDateTime(existing.startedAt);
      final d = existing.duration;
      _durationHours = d.inHours;
      _durationMinutes = d.inMinutes % 60;
      _durationSeconds = d.inSeconds % 60;
      _distanceCtrl.text = existing.distanceKm.toStringAsFixed(2);
      if (existing.avgHeartRate != null) {
        _hrCtrl.text = existing.avgHeartRate.toString();
      }
      if (existing.calories != null) {
        _caloriesCtrl.text = existing.calories!.round().toString();
      }
      if (existing.cadenceSpm != null) {
        _cadenceCtrl.text = existing.cadenceSpm.toString();
      }
      _notesCtrl.text = existing.notes ?? '';
      _runType = existing.runType;
    } else {
      final now = DateTime.now();
      _date = widget.initialDate ??
          DateTime(now.year, now.month, now.day);
      _time = TimeOfDay.fromDateTime(now);
    }
  }

  @override
  void dispose() {
    _distanceCtrl.dispose();
    _hrCtrl.dispose();
    _caloriesCtrl.dispose();
    _cadenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ─── Derived pace (live preview) ──────────────────────────────────────
  String get _livePace {
    final km = double.tryParse(_distanceCtrl.text);
    if (km == null || km <= 0) return '--:--';
    final totalSecs =
        _durationHours * 3600 + _durationMinutes * 60 + _durationSeconds;
    if (totalSecs == 0) return '--:--';
    final secsPerKm = totalSecs / km;
    final m = (secsPerKm ~/ 60);
    final s = (secsPerKm % 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ─── Validation & save ────────────────────────────────────────────────
  Future<void> _save() async {
    // Validate distance
    final km = double.tryParse(_distanceCtrl.text);
    if (km == null || km <= 0) {
      _showError('Enter a valid distance.');
      return;
    }

    final totalSecs =
        _durationHours * 3600 + _durationMinutes * 60 + _durationSeconds;
    if (totalSecs == 0) {
      _showError('Enter a duration greater than zero.');
      return;
    }

    setState(() => _saving = true);
    try {
      final startedAt = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );
      final endedAt = startedAt.add(Duration(seconds: totalSecs));

      final hr = int.tryParse(_hrCtrl.text);
      final cal = double.tryParse(_caloriesCtrl.text);
      final cad = int.tryParse(_cadenceCtrl.text);

      final existing = widget.existingRun;
      final run = RunSession(
        id: existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        startedAt: startedAt,
        endedAt: endedAt,
        distanceMeters: km * 1000,
        avgHeartRate: hr,
        calories: cal,
        cadenceSpm: cad,
        runType: _runType,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        // Preserve source/externalId when editing an imported run so it won't
        // be re-imported on the next sync.
        source: existing?.source ?? RunSource.manual,
        externalId: existing?.externalId,
      );

      await ref.read(runsProvider.notifier).saveRun(run);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppThemeData.of(context).c.surface,
        content: Text(
          message,
          style: bodyStyle(
              fontSize: 14, color: AppThemeData.of(context).c.danger),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final isEdit = widget.existingRun != null;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            AppHeaderBar(
              leading: AppIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isEdit ? 'Edit Run' : 'Log Run',
                  style: displayStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                    letterSpacing: -1.2,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                children: [
                  // ── Date & time ─────────────────────────────────────
                  _SectionLabel('Date & Time', c: c),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _TappableField(
                          label: _formatDate(_date),
                          icon: Icons.calendar_today_outlined,
                          c: c,
                          isDark: theme.isDark,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _date = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: _TappableField(
                          label: _time.format(context),
                          icon: Icons.access_time_rounded,
                          c: c,
                          isDark: theme.isDark,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _time,
                            );
                            if (picked != null) {
                              setState(() => _time = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Duration ────────────────────────────────────────
                  _SectionLabel('Duration', c: c),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DurationField(
                          label: 'HH',
                          value: _durationHours,
                          max: 23,
                          c: c,
                          isDark: theme.isDark,
                          onChanged: (v) =>
                              setState(() => _durationHours = v),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(':',
                            style: displayStyle(
                                fontSize: 24,
                                color: c.inkMute,
                                fontWeight: FontWeight.w400)),
                      ),
                      Expanded(
                        child: _DurationField(
                          label: 'MM',
                          value: _durationMinutes,
                          max: 59,
                          c: c,
                          isDark: theme.isDark,
                          onChanged: (v) =>
                              setState(() => _durationMinutes = v),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(':',
                            style: displayStyle(
                                fontSize: 24,
                                color: c.inkMute,
                                fontWeight: FontWeight.w400)),
                      ),
                      Expanded(
                        child: _DurationField(
                          label: 'SS',
                          value: _durationSeconds,
                          max: 59,
                          c: c,
                          isDark: theme.isDark,
                          onChanged: (v) =>
                              setState(() => _durationSeconds = v),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Distance ────────────────────────────────────────
                  _SectionLabel('Distance', c: c),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _distanceCtrl,
                    hint: '0.00',
                    suffix: 'km',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    c: c,
                    isDark: theme.isDark,
                    onChanged: (_) => setState(() {}),
                  ),

                  // Live pace preview
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      'Pace: $_livePace /km',
                      style: bodyStyle(
                        fontSize: 13,
                        color: c.inkDim,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Run type ────────────────────────────────────────
                  _SectionLabel('Run Type', c: c),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: RunType.values.map((t) {
                      final selected = _runType == t;
                      return GestureDetector(
                        onTap: () => setState(() => _runType = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? c.accent : c.surface,
                            borderRadius: BorderRadius.circular(100),
                            border: selected
                                ? null
                                : Border.all(color: c.hairline),
                          ),
                          child: Text(
                            _runTypeLabel(t),
                            style: bodyStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: selected ? c.accentInk : c.inkDim,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ── Optional metrics ────────────────────────────────
                  _SectionLabel('Optional', c: c),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _InputField(
                          controller: _hrCtrl,
                          hint: 'Heart rate',
                          suffix: 'bpm',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          c: c,
                          isDark: theme.isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InputField(
                          controller: _caloriesCtrl,
                          hint: 'Calories',
                          suffix: 'kcal',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          c: c,
                          isDark: theme.isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _InputField(
                    controller: _cadenceCtrl,
                    hint: 'Cadence (steps per minute)',
                    suffix: 'spm',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    c: c,
                    isDark: theme.isDark,
                  ),

                  const SizedBox(height: 20),

                  // ── Notes ───────────────────────────────────────────
                  _SectionLabel('Notes', c: c),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(kRadius),
                      border: theme.isDark
                          ? Border.all(color: c.hairlineSoft)
                          : Border.all(color: c.hairline),
                      boxShadow: cardShadow(theme.isDark),
                    ),
                    child: TextField(
                      controller: _notesCtrl,
                      minLines: 3,
                      maxLines: 6,
                      style: bodyStyle(fontSize: 15, color: c.ink),
                      decoration: InputDecoration(
                        hintText: 'How did the run feel?',
                        hintStyle: bodyStyle(fontSize: 15, color: c.inkMute),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Save ────────────────────────────────────────────
                  AppButton(
                    label: _saving
                        ? 'Saving…'
                        : isEdit
                            ? 'Save changes'
                            : 'Save run',
                    icon: Icons.check_rounded,
                    full: true,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _runTypeLabel(RunType t) {
    switch (t) {
      case RunType.easy: return 'Easy';
      case RunType.tempo: return 'Tempo';
      case RunType.interval: return 'Interval';
      case RunType.long: return 'Long';
      case RunType.race: return 'Race';
      case RunType.other: return 'Other';
    }
  }
}

// ─── Section label ────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final AppColors c;
  const _SectionLabel(this.text, {required this.c});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: bodyStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: c.inkMute,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── Tappable field (date/time) ───────────────────────────────────────
class _TappableField extends StatelessWidget {
  final String label;
  final IconData icon;
  final AppColors c;
  final bool isDark;
  final VoidCallback onTap;

  const _TappableField({
    required this.label,
    required this.icon,
    required this.c,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(kRadius),
          border: isDark
              ? Border.all(color: c.hairlineSoft)
              : Border.all(color: c.hairline),
          boxShadow: cardShadow(isDark),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: c.inkMute),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: bodyStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.ink,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Duration field ───────────────────────────────────────────────────
class _DurationField extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final AppColors c;
  final bool isDark;
  final ValueChanged<int> onChanged;

  const _DurationField({
    required this.label,
    required this.value,
    required this.max,
    required this.c,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: isDark
            ? Border.all(color: c.hairlineSoft)
            : Border.all(color: c.hairline),
        boxShadow: cardShadow(isDark),
      ),
      child: Column(
        children: [
          // Increment
          _ArrowBtn(
            icon: Icons.keyboard_arrow_up_rounded,
            c: c,
            onTap: () => onChanged((value + 1).clamp(0, max)),
          ),
          Text(
            value.toString().padLeft(2, '0'),
            style: monoStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: c.ink,
            ),
          ),
          Text(
            label,
            style: bodyStyle(fontSize: 9, color: c.inkMute, letterSpacing: 0.5),
          ),
          // Decrement
          _ArrowBtn(
            icon: Icons.keyboard_arrow_down_rounded,
            c: c,
            onTap: () => onChanged((value - 1).clamp(0, max)),
          ),
        ],
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final AppColors c;
  final VoidCallback onTap;

  const _ArrowBtn({required this.icon, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 36,
        child: Center(
          child: Icon(icon, size: 20, color: c.inkDim),
        ),
      ),
    );
  }
}

// ─── Input field ─────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String suffix;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final AppColors c;
  final bool isDark;
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.suffix,
    required this.keyboardType,
    required this.inputFormatters,
    required this.c,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: isDark
            ? Border.all(color: c.hairlineSoft)
            : Border.all(color: c.hairline),
        boxShadow: cardShadow(isDark),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              style: bodyStyle(fontSize: 15, color: c.ink),
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: bodyStyle(fontSize: 15, color: c.inkMute),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Text(
              suffix,
              style: bodyStyle(
                  fontSize: 13,
                  color: c.inkMute,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
