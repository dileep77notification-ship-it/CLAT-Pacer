// ============================================================================
// TOPIC PERFORMANCE SERVICE
// Appends one TopicRecord per answered question (from both the per-section
// practice screens and the Mock Test), and aggregates them into per-topic
// accuracy — the input §7 Brain Gym needs to find weak topics. Brain Gym's
// own practice-generation screen is not built yet; this just keeps the log
// so it isn't missing data once that screen exists.
// ============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/topic_performance_models.dart';

class TopicPerformanceService {
  static const _kRecords = 'topic_performance_records';

  /// Appends a batch of records in one write (one per answered question in
  /// a completed set/mock — never per keystroke).
  static Future<void> recordAnswers(List<TopicRecord> records) async {
    if (records.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRecords);
    final list = raw == null ? <dynamic>[] : jsonDecode(raw) as List;
    list.addAll(records.map((r) => r.toJson()));
    await prefs.setString(_kRecords, jsonEncode(list));
  }

  static Future<List<TopicRecord>> loadRecords({String? section}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRecords);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    final records = list
        .map((e) => TopicRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    if (section == null) return records;
    return records.where((r) => r.section == section).toList();
  }

  /// Aggregates into per-(section, topic) accuracy, sorted weakest first.
  /// Pass [minAttempts] to exclude topics with too little data to be
  /// meaningful (default 3).
  static Future<List<TopicStats>> weakestTopics({
    String? section,
    int minAttempts = 3,
  }) async {
    final records = await loadRecords(section: section);
    final buckets = <String, List<TopicRecord>>{};
    for (final r in records) {
      buckets.putIfAbsent('${r.section}::${r.topic}', () => []).add(r);
    }

    final stats = buckets.entries.map((e) {
      final recs = e.value;
      final correct = recs.where((r) => r.correct).length;
      return TopicStats(
        section: recs.first.section,
        topic: recs.first.topic,
        attempts: recs.length,
        correct: correct,
      );
    }).where((s) => s.attempts >= minAttempts).toList();

    stats.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return stats;
  }
}
