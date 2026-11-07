// ============================================================================
// TOPIC PERFORMANCE MODELS
// The data layer §7 Brain Gym needs: a flat, append-only log of individual
// question outcomes tagged by section AND topic (not just section — see
// QuizQuestion.topic in quiz_models.dart for why). Brain Gym itself (the
// screen that generates targeted practice on whatever topic this log says
// is weakest) is not built yet; this is the log it will read.
// ============================================================================

class TopicRecord {
  final String section; // a QuizSection.* id
  final String topic; // free-text bucket label, e.g. "contract", "percentage"
  final bool correct;
  final String dateIso; // yyyy-MM-dd

  const TopicRecord({
    required this.section,
    required this.topic,
    required this.correct,
    required this.dateIso,
  });

  Map<String, dynamic> toJson() => {
        'section': section,
        'topic': topic,
        'correct': correct,
        'date': dateIso,
      };

  factory TopicRecord.fromJson(Map<String, dynamic> json) => TopicRecord(
        section: json['section'] as String,
        topic: json['topic'] as String,
        correct: json['correct'] as bool,
        dateIso: json['date'] as String,
      );
}

/// Aggregated accuracy for one (section, topic) pair — what Brain Gym will
/// sort by to find what's weakest.
class TopicStats {
  final String section;
  final String topic;
  final int attempts;
  final int correct;

  const TopicStats({
    required this.section,
    required this.topic,
    required this.attempts,
    required this.correct,
  });

  double get accuracy => attempts == 0 ? 0 : correct / attempts;
}
