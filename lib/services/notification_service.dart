import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Daily "complete your Daily Sprint" reminder.
///
/// Design notes
/// * Schedules a rolling window of one-shot notifications (the next
///   [_windowDays] days) instead of one repeating alarm. That lets us skip
///   *today's* reminder once the Daily Sprint is already done, which a
///   repeating alarm cannot do.
/// * The window is rebuilt on app start, on app resume, when the settings
///   change and when a sprint is completed, so it keeps rolling forward as long
///   as the app is opened within [_windowDays] days.
/// * Times are computed from the device's own local clock (plain [DateTime])
///   and handed to the plugin as absolute instants, so no time-zone database or
///   hard-coded zone is needed, and each day is DST-correct.
/// * Uses inexact alarms: no SCHEDULE_EXACT_ALARM permission is needed. On
///   Android the reminder may arrive a few minutes late; that is fine here.
/// * "Done today" is read from the same SharedPreferences value the Daily
///   Sprint streak uses ([_kLastCompleted]), so there is one source of truth.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int _windowDays = 30;
  static const int _idBase = 7000; // ids _idBase .. _idBase + _windowDays - 1
  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Daily reminder';

  static const String _kEnabled = 'reminder_enabled';
  static const String _kHour = 'reminder_hour';
  static const String _kMinute = 'reminder_minute';

  /// Same key as StorageService._kLastCompletedDate in main.dart
  /// (yyyy-MM-dd, device-local). Duplicated here to avoid a circular import.
  static const String _kLastCompleted = 'clat_last_completed_date';

  static const int defaultHour = 19; // 7:00 PM
  static const int defaultMinute = 0;

  static const List<String> _messages = [
    "Your Daily Sprint is waiting. Read today's passages and keep your streak alive.",
    "Don't break your streak. Finish today's Daily Sprint.",
    'Small daily reps beat last-minute cramming. Start your Daily Sprint.',
    "Today's editorials are in. Read them and test yourself.",
    'A few minutes of reading now, a better CLAT score later.',
    "Your streak needs you. Complete today's Daily Sprint.",
    'Quick check-in: have you done your Daily Sprint today?',
  ];

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  DateTime Function() _clock = DateTime.now;

  /// Lets tests pin "now" so the scheduling rules are deterministic.
  @visibleForTesting
  set clock(DateTime Function() value) => _clock = value;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Call once from main() after WidgetsFlutterBinding.ensureInitialized().
  /// Never throws: a notification problem must not stop the app from starting.
  Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );
      _ready = true;
      await refresh();
    } catch (e) {
      debugPrint('NotificationService.init failed: $e');
    }
  }

  // ---- settings ----------------------------------------------------------

  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_kEnabled) ?? false;

  Future<({int hour, int minute})> getTime() async {
    final p = await SharedPreferences.getInstance();
    return (
      hour: p.getInt(_kHour) ?? defaultHour,
      minute: p.getInt(_kMinute) ?? defaultMinute,
    );
  }

  /// Turns reminders on/off. Turning on asks for notification permission.
  /// Returns the resulting enabled state (false if permission was refused).
  Future<bool> setEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    if (value && !await requestPermission()) {
      await p.setBool(_kEnabled, false);
      await refresh();
      return false;
    }
    await p.setBool(_kEnabled, value);
    await refresh();
    return value;
  }

  Future<void> setTime(int hour, int minute) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kHour, hour);
    await p.setInt(_kMinute, minute);
    await refresh();
  }

  Future<bool> requestPermission() async {
    if (!_supported || !_ready) return false;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final impl = _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
          return await impl?.requestNotificationsPermission() ?? false;
        case TargetPlatform.iOS:
          final impl = _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
          return await impl?.requestPermissions(
                  alert: true, badge: true, sound: true) ??
              false;
        case TargetPlatform.macOS:
          final impl = _plugin.resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>();
          return await impl?.requestPermissions(
                  alert: true, badge: true, sound: true) ??
              false;
        default:
          return false;
      }
    } catch (e) {
      debugPrint('NotificationService.requestPermission failed: $e');
      return false;
    }
  }

  // ---- scheduling --------------------------------------------------------

  /// Call after a Daily Sprint is recorded so today's reminder is dropped.
  Future<void> onSprintCompleted() => refresh();

  /// Rebuilds the notification window. Safe to call as often as you like.
  Future<void> refresh() async {
    if (!_supported || !_ready) return;
    try {
      for (var i = 0; i < _windowDays; i++) {
        await _plugin.cancel(id: _idBase + i);
      }

      final p = await SharedPreferences.getInstance();
      if (!(p.getBool(_kEnabled) ?? false)) return;

      final hour = p.getInt(_kHour) ?? defaultHour;
      final minute = p.getInt(_kMinute) ?? defaultMinute;
      final now = _clock();
      final doneToday = p.getString(_kLastCompleted) == dateKey(now);

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Daily reminder to complete your Daily Sprint',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );

      for (var i = 0; i < _windowDays; i++) {
        // DateTime() normalises day overflow (e.g. day 32 -> next month).
        final local = DateTime(now.year, now.month, now.day + i, hour, minute);
        if (!local.isAfter(now)) continue; // time already passed today
        if (i == 0 && doneToday) continue; // today's sprint already done
        await _plugin.zonedSchedule(
          id: _idBase + i,
          title: 'CLAT Pacer',
          body: _messages[local.weekday % _messages.length],
          scheduledDate: tz.TZDateTime.from(local, tz.UTC),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('NotificationService.refresh failed: $e');
    }
  }

  /// yyyy-MM-dd in device-local time; matches StorageService's date keys.
  @visibleForTesting
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
