// ============================================================================
// DAILY SPRINT MODELS
// Moved out of main.dart (where they were originally inline, alongside a
// single hardcoded PassageModel) so DailyArticleService can build a
// PassageModel from live RSS + Sarvam content without main.dart importing a
// service file.
// ============================================================================

class QuestionModel {
  final String prompt;
  final List<String> options;
  final int correctIndex;

  const QuestionModel({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });
}

class FlashcardModel {
  final String title;
  final String fact;

  const FlashcardModel({required this.title, required this.fact});
}

class PassageModel {
  final String title;
  final String body;
  final List<QuestionModel> questions;
  final List<FlashcardModel> flashcards;

  const PassageModel({
    required this.title,
    required this.body,
    required this.questions,
    required this.flashcards,
  });

  int get wordCount => body.trim().split(RegExp(r'\s+')).length;
}
