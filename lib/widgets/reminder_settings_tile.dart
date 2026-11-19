import 'package:flutter/material.dart';

import '../services/notification_service.dart';

/// Drop this into the Settings screen's list of children:
///   const ReminderSettingsTile(),
class ReminderSettingsTile extends StatefulWidget {
  const ReminderSettingsTile({super.key});

  @override
  State<ReminderSettingsTile> createState() => _ReminderSettingsTileState();
}

class _ReminderSettingsTileState extends State<ReminderSettingsTile> {
  final _svc = NotificationService.instance;
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(
    hour: NotificationService.defaultHour,
    minute: NotificationService.defaultMinute,
  );
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _svc.isEnabled();
    final t = await _svc.getTime();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _time = TimeOfDay(hour: t.hour, minute: t.minute);
      _loaded = true;
    });
  }

  Future<void> _toggle(bool value) async {
    final result = await _svc.setEnabled(value);
    if (!mounted) return;
    setState(() => _enabled = result);
    if (value && !result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are blocked. Enable them for CLAT Pacer in system settings.',
          ),
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null) return;
    await _svc.setTime(picked.hour, picked.minute);
    if (!mounted) return;
    setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('Daily reminder'),
          subtitle: const Text('A nudge to finish your Daily Sprint'),
          value: _enabled,
          onChanged: _toggle,
        ),
        ListTile(
          enabled: _enabled,
          leading: const Icon(Icons.schedule),
          title: const Text('Reminder time'),
          subtitle: Text(_time.format(context)),
          onTap: _enabled ? _pickTime : null,
        ),
      ],
    );
  }
}
