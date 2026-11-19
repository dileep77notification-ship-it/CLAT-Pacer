import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clat_pacer/services/notification_service.dart';

/// Exercises the real scheduling rules against a mocked plugin channel, so we
/// assert on exactly what would be handed to Android.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];

  // Far-future "now" so the plugin's own "date must be in the future" check
  // passes no matter when the test is run.
  final morning = DateTime(2030, 3, 10, 10, 0);
  final evening = DateTime(2030, 3, 10, 20, 0);

  late NotificationService service;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'initialize' ? true : null;
    });
    service = NotificationService.instance;
    service.clock = () => morning;
    await service.init();
    calls.clear(); // ignore calls made during init
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<MethodCall> scheduled() =>
      calls.where((c) => c.method == 'zonedSchedule').toList();

  test('disabled: cancels the window and schedules nothing', () async {
    SharedPreferences.setMockInitialValues({});
    await service.refresh();
    expect(scheduled(), isEmpty);
    expect(calls.where((c) => c.method == 'cancel').length, 30);
  });

  test('enabled at 19:00, before 19:00: schedules today + next 29 days',
      () async {
    SharedPreferences.setMockInitialValues({
      'reminder_enabled': true,
      'reminder_hour': 19,
      'reminder_minute': 0,
    });
    await service.refresh();
    final s = scheduled();
    expect(s.length, 30);
    expect(s.first.arguments['id'], 7000);
    expect(s.last.arguments['id'], 7029);
    expect(s.first.arguments['scheduledDateTime'], contains('2030-03-10T19:00'));
    expect(s.last.arguments['scheduledDateTime'], contains('2030-04-08T19:00'));
  });

  test("enabled but 19:00 already passed today: starts tomorrow", () async {
    service.clock = () => evening;
    SharedPreferences.setMockInitialValues({
      'reminder_enabled': true,
      'reminder_hour': 19,
      'reminder_minute': 0,
    });
    await service.refresh();
    final s = scheduled();
    expect(s.length, 29);
    expect(s.first.arguments['id'], 7001);
    expect(s.first.arguments['scheduledDateTime'], contains('2030-03-11T19:00'));
  });

  test("sprint already done today: skips today's reminder only", () async {
    SharedPreferences.setMockInitialValues({
      'reminder_enabled': true,
      'reminder_hour': 19,
      'reminder_minute': 0,
      'clat_last_completed_date': '2030-03-10',
    });
    await service.refresh();
    final s = scheduled();
    expect(s.length, 29);
    expect(s.first.arguments['id'], 7001);
    expect(s.first.arguments['scheduledDateTime'], contains('2030-03-11T19:00'));
  });

  test('a sprint finished yesterday does not suppress today', () async {
    SharedPreferences.setMockInitialValues({
      'reminder_enabled': true,
      'reminder_hour': 19,
      'reminder_minute': 0,
      'clat_last_completed_date': '2030-03-09',
    });
    await service.refresh();
    expect(scheduled().length, 30);
  });

  test('window rolls over month and year boundaries', () async {
    service.clock = () => DateTime(2030, 12, 20, 10, 0);
    SharedPreferences.setMockInitialValues({
      'reminder_enabled': true,
      'reminder_hour': 21,
      'reminder_minute': 15,
    });
    await service.refresh();
    final s = scheduled();
    expect(s.length, 30);
    expect(s.last.arguments['scheduledDateTime'], contains('2031-01-18T21:15'));
  });

  test('dateKey matches the app\'s yyyy-MM-dd format', () {
    expect(NotificationService.dateKey(DateTime(2030, 3, 5)), '2030-03-05');
  });
}
