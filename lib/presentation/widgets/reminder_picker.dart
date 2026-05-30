import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/mesocycle_providers.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

void showReminderPicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ReminderPickerSheet(),
  );
}

class _ReminderPickerSheet extends ConsumerStatefulWidget {
  const _ReminderPickerSheet();

  @override
  ConsumerState<_ReminderPickerSheet> createState() => _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends ConsumerState<_ReminderPickerSheet> {
  late bool _enabled;
  late TimeOfDay _time;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final reminderAsync = ref.watch(reminderProvider);
    final c = AppThemeData.of(context).c;

    return reminderAsync.when(
      loading: () => Container(
        color: c.surface,
        height: 200,
        child: Center(child: CircularProgressIndicator(color: c.accent)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (reminder) {
        if (!_loaded) {
          _enabled = reminder.enabled;
          _time = reminder.time;
          _loaded = true;
        }
        return _buildSheet(context, c);
      },
    );
  }

  Widget _buildSheet(BuildContext context, AppColors c) {
    final timeLabel = _time.format(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius + 8)),
      ),
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 20,
        bottom: 28 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.notifications_outlined, size: 20, color: c.accent),
              const SizedBox(width: 10),
              Text(
                'Pre-workout reminder',
                style: displayStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: c.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Switch(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                activeThumbColor: c.accent,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Get notified at the time you want to start preparing for your workout.',
            style: bodyStyle(fontSize: 13, color: c.inkDim, height: 1.4),
          ),
          if (_enabled) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (picked != null) setState(() => _time = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(kRadius - 4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 18, color: c.inkDim),
                    const SizedBox(width: 12),
                    Text(
                      'Reminder time',
                      style: bodyStyle(fontSize: 14, color: c.inkDim),
                    ),
                    const Spacer(),
                    Text(
                      timeLabel,
                      style: displayStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, size: 18, color: c.inkMute),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          AppButton(
            label: 'Save',
            full: true,
            onPressed: () async {
              final notifier = ref.read(reminderProvider.notifier);
              if (_enabled && !ref.read(reminderProvider).value!.enabled) {
                // Newly enabled — request permission first.
                final granted =
                    await NotificationService.instance.requestPermissions();
                if (!granted) {
                  if (context.mounted) Navigator.pop(context);
                  return;
                }
              }
              await notifier.setEnabled(_enabled);
              await notifier.setTime(_time);
              await ref.read(mesocyclesProvider.notifier).reschedule();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
