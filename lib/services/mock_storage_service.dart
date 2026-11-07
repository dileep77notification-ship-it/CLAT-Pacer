// ============================================================================
// MOCK TEST STORAGE SERVICE
// Separate from quiz_storage_service.dart because MockAttempt's shape
// (negative marking, per-section breakdown) differs from QuizAttempt's
// simple count-correct/total shape — see mock_models.dart.
// ============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mock_models.dart';

class MockStorageService {
  static const _kAttempts = 'mock_attempts';
  static const _kInProgressQuestions = 'mock_inprogress_questions';
  static const _kInProgressMeta = 'mock_inprogress_meta';

  static Future<void> recordAttempt(MockAttempt attempt) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAttempts);
    final list = raw == null ? <dynamic>[] : jsonDecode(raw) as List;
    list.add(attempt.toJson());
    await prefs.setString(_kAttempts, jsonEncode(list));
  }

  static Future<List<MockAttempt>> loadAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAttempts);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => MockAttempt.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // In-progress question storage is deliberately NOT implemented in v1:
  // if the app is killed mid-mock, the attempt is lost and the student
  // starts over. A real CLAT sitting isn't pausable either, so this is an
  // acceptable gap for now rather than something to build around; revisit
  // if backgrounding turns out to happen often in practice.
  static Future<void> clearInProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kInProgressQuestions);
    await prefs.remove(_kInProgressMeta);
  }
}
