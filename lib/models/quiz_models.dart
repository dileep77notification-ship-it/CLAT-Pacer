// ============================================================================
// QUIZ MODELS
// Generalized so every section (Legal Reasoning, GK/Current Affairs,
// Logical Reasoning, Quant, English/RC) shares one question shape and one
// quiz-taking / results flow instead of duplicating it per section.
//
// Three optional fields exist only for Full Mock Test Mode (§8) and §7's
// Brain Gym, which are the first consumers that need them:
//   - `passage`: the English/RC generator groups 5 questions under one
//     reading passage; each of those 5 QuizQuestions carries the SAME
//     passage text here so the (single) quiz-taking UI can show it above
//     the question without needing a separate passage-grouped screen.
//     Every other section's questions are fully self-contained, so this
//     stays null for them.
//   - `section`: the per-section screens already know their own section
//     (passed separately to QuizTakingScreen), so they leave this null.
//     The Mock orchestrator stitches multiple sections' questions into one
//     list and needs each question to carry its own section for the exam's
//     section tabs/palette and for per-section scoring — see copyWith().
//   - `topic`: a finer-grained tag than `section` — e.g. "contract" within
//     Legal Reasoning, "percentage" within Quant, "strengthen" within
//     Logical Reasoning. Every generator now asks Sarvam to set this (see
//     sarvam_service.dart's per-section topic lists), and quiz_taking_screen
//     / mock_taking_screen both log it to TopicPerformanceService on
//     submit. This is what unblocks §7 Brain Gym — without it, accuracy
//     could only be tracked per SECTION, not per weak topic within one.
//     Free-text from the model, not a hard enum: treat it as a best-effort
//     bucket label, not a validated value.

class QuizQuestion {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String? passage;
  final String? section;
  final String? topic;

  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.passage,
    this.section,
    this.topic,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final options = List<String>.from(json['options'] as List);
    final correctIndex = (json['correct_index'] as num).toInt();
    if (options.length != 4) {
      throw FormatException('Expected 4 options, got ${options.length}');
    }
    if (correctIndex < 0 || correctIndex > 3) {
      throw FormatException('correct_index out of range: $correctIndex');
    }
    final rawTopic = json['topic'] as String?;
    return QuizQuestion(
      prompt: json['question'] as String,
      options: options,
      correctIndex: correctIndex,
      explanation: json['explanation'] as String? ?? '',
      passage: json['passage'] as String?,
      section: json['section'] as String?,
      topic: (rawTopic == null || rawTopic.trim().isEmpty)
          ? null
          : rawTopic.trim().toLowerCase().replaceAll(' ', '_'),
    );
  }

  Map<String, dynamic> toJson() => {
        'question': prompt,
        'options': options,
        'correct_index': correctIndex,
        'explanation': explanation,
        if (passage != null) 'passage': passage,
        if (section != null) 'section': section,
        if (topic != null) 'topic': topic,
      };

  /// Returns a copy with [section], [passage] and/or [topic] attached —
  /// used by the Mock orchestrator to tag each generator's otherwise-
  /// identical QuizQuestions with which exam section they belong to.
  QuizQuestion copyWith({String? section, String? passage, String? topic}) =>
      QuizQuestion(
        prompt: prompt,
        options: options,
        correctIndex: correctIndex,
        explanation: explanation,
        passage: passage ?? this.passage,
        section: section ?? this.section,
        topic: topic ?? this.topic,
      );
}

/// Section identifiers used as storage-key prefixes and for filtering
/// attempt history. Keep these stable — they're persisted.
class QuizSection {
  static const legalReasoning = 'legal_reasoning';
  static const gkCurrentAffairs = 'gk_current_affairs';
  static const logicalReasoning = 'logical_reasoning';
  static const quant = 'quant';
  static const english = 'english';
}

class QuizAttempt {
  final String section;
  final String dateIso; // yyyy-MM-dd
  final int score;
  final int total;
  final int durationSeconds;

  const QuizAttempt({
    required this.section,
    required this.dateIso,
    required this.score,
    required this.total,
    required this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
        'section': section,
        'date': dateIso,
        'score': score,
        'total': total,
        'duration_seconds': durationSeconds,
      };

  factory QuizAttempt.fromJson(Map<String, dynamic> json) => QuizAttempt(
        section: json['section'] as String? ?? QuizSection.legalReasoning,
        dateIso: json['date'] as String,
        score: (json['score'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        durationSeconds: (json['duration_seconds'] as num).toInt(),
      );
}
