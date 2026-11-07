// ============================================================================
// QUIZ STORAGE SERVICE
// Generalized to work for any section (Legal Reasoning, GK/Current Affairs,
// and future Logical Reasoning / Quant) rather than being hardcoded to
// Legal Reasoning.
//
// In-progress questions are kept per-section (a student could in theory have
// both a Legal Reasoning test and a GK quiz pending at once), keyed as
// '<section>_inprogress_questions'.
//
// Attempts are stored in ONE list under a single key, each entry tagged with
// its `section`. This is deliberate: §7's Brain Gym needs to look at
// accuracy across sections together (e.g. "weakest topic overall"), which is
// far easier against one combined, section-tagged list than N separate
// per-section lists. loadAttempts(section) filters client-side; omit the
// section to get everything.
// ============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quiz_models.dart';

class QuizStorageService {
  static const _kAttempts = 'quiz_attempts';

  static String _inProgressKey(String section) =>
      '${section}_inprogress_questions';

  /// Saves the just-generated question set so it survives the app closing
  /// mid-test.
  static Future<void> saveInProgressQuestions(
      String section, List<QuizQuestion> questions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _inProgressKey(section),
      jsonEncode(questions.map((q) => q.toJson()).toList()),
    );
  }

  static Future<List<QuizQuestion>?> loadInProgressQuestions(
      String section) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_inProgressKey(section));
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> clearInProgressQuestions(String section) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_inProgressKey(section));
  }

  static Future<void> recordAttempt(QuizAttempt attempt) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAttempts);
    final list = raw == null ? <dynamic>[] : jsonDecode(raw) as List;
    list.add(attempt.toJson());
    await prefs.setString(_kAttempts, jsonEncode(list));
  }

  /// Pass a section to filter (e.g. QuizSection.legalReasoning); omit for
  /// every attempt across all sections.
  static Future<List<QuizAttempt>> loadAttempts([String? section]) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAttempts);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    final attempts = list
        .map((e) => QuizAttempt.fromJson(e as Map<String, dynamic>))
        .toList();
    if (section == null) return attempts;
    return attempts.where((a) => a.section == section).toList();
  }
}
