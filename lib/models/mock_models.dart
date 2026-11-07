// ============================================================================
// MOCK TEST MODELS
// Full Mock Test Mode (§8) scores differently from the per-section practice
// screens: +1 for a correct answer, -0.25 for a wrong one, 0 for an
// unattempted one (standard CLAT UG scheme) — and it needs a per-section
// breakdown, not just one overall count. QuizAttempt (quiz_models.dart) is
// a simple count-correct/total shape used by the 5 practice screens; it
// can't hold either of those, so Mock Test results get their own model
// instead of being forced into that shape.
// ============================================================================

class MockSectionResult {
  final String section; // a QuizSection.* id
  final String label; // display name, e.g. "Legal Reasoning"
  final int totalQuestions;
  final int correct;
  final int wrong;
  final int unattempted;

  const MockSectionResult({
    required this.section,
    required this.label,
    required this.totalQuestions,
    required this.correct,
    required this.wrong,
    required this.unattempted,
  });

  /// +1 per correct, -0.25 per wrong, 0 per unattempted.
  double get netScore => correct - (wrong * 0.25);
  double get maxScore => totalQuestions.toDouble();

  Map<String, dynamic> toJson() => {
        'section': section,
        'label': label,
        'total_questions': totalQuestions,
        'correct': correct,
        'wrong': wrong,
        'unattempted': unattempted,
      };

  factory MockSectionResult.fromJson(Map<String, dynamic> json) =>
      MockSectionResult(
        section: json['section'] as String,
        label: json['label'] as String,
        totalQuestions: (json['total_questions'] as num).toInt(),
        correct: (json['correct'] as num).toInt(),
        wrong: (json['wrong'] as num).toInt(),
        unattempted: (json['unattempted'] as num).toInt(),
      );
}

class MockAttempt {
  final String dateIso; // yyyy-MM-dd
  final int durationSeconds;
  final int totalQuestions;
  final List<MockSectionResult> sections;

  const MockAttempt({
    required this.dateIso,
    required this.durationSeconds,
    required this.totalQuestions,
    required this.sections,
  });

  double get overallNetScore =>
      sections.fold(0.0, (sum, s) => sum + s.netScore);
  double get overallMaxScore => totalQuestions.toDouble();
  int get overallCorrect => sections.fold(0, (sum, s) => sum + s.correct);
  int get overallWrong => sections.fold(0, (sum, s) => sum + s.wrong);
  int get overallUnattempted =>
      sections.fold(0, (sum, s) => sum + s.unattempted);

  Map<String, dynamic> toJson() => {
        'date': dateIso,
        'duration_seconds': durationSeconds,
        'total_questions': totalQuestions,
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  factory MockAttempt.fromJson(Map<String, dynamic> json) => MockAttempt(
        dateIso: json['date'] as String,
        durationSeconds: (json['duration_seconds'] as num).toInt(),
        totalQuestions: (json['total_questions'] as num).toInt(),
        sections: (json['sections'] as List)
            .map((s) => MockSectionResult.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
