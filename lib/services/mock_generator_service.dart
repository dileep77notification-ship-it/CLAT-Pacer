// ============================================================================
// MOCK TEST GENERATOR SERVICE
// Orchestrates all 5 section generators in GroqService into one combined,
// section-tagged question list for Full Mock Test Mode (§8). Generation
// happens entirely BEFORE the exam timer starts (see MockLoadingScreen) —
// the exam clock should time the student, not Groq's rate limit.
//
// Two configs are defined below: kHalfMockConfig (~60 Qs / 60 min, halved
// from the real pattern and rounded to keep proportions) and
// kFullMockConfig (the real CLAT UG's ~120-question/120-minute pattern:
// English 20, GK/CA 30, Legal Reasoning 30, Logical Reasoning 28, Quant
// 12). MockLoadingScreen lets the user pick between them before
// generation starts; nothing downstream (this service, the taking screen,
// the results screen) needs to know which one was picked — they all just
// read `sections`/`durationMinutes` off whichever MockConfig they're given.
// ============================================================================

import '../models/quiz_models.dart';
import 'grok_service.dart';
import 'rss_service.dart';

class MockSectionSpec {
  final String section; // a QuizSection.* id
  final String label;
  final int count;
  const MockSectionSpec(
      {required this.section, required this.label, required this.count});
}

class MockConfig {
  final String name;
  final int durationMinutes;
  final List<MockSectionSpec> sections;
  const MockConfig(
      {required this.name,
      required this.durationMinutes,
      required this.sections});

  int get totalQuestions => sections.fold(0, (sum, s) => sum + s.count);
}

const MockConfig kHalfMockConfig = MockConfig(
  name: 'Half-Length Mock',
  durationMinutes: 60,
  sections: [
    MockSectionSpec(
        section: QuizSection.english, label: 'English', count: 10),
    MockSectionSpec(
        section: QuizSection.gkCurrentAffairs,
        label: 'GK / Current Affairs',
        count: 15),
    MockSectionSpec(
        section: QuizSection.legalReasoning,
        label: 'Legal Reasoning',
        count: 15),
    MockSectionSpec(
        section: QuizSection.logicalReasoning,
        label: 'Logical Reasoning',
        count: 14),
    MockSectionSpec(section: QuizSection.quant, label: 'Quant', count: 6),
  ],
);

/// Full-scale mock, matching the real CLAT UG's ~120-question/120-minute
/// pattern: English 20, GK/CA 30, Legal Reasoning 30, Logical Reasoning 28,
/// Quant 12 = 120 total. Generation paces itself exactly like the half
/// config (same per-section/per-batch pauses in GroqService and
/// _kSectionPause below) — it just takes roughly twice as long to generate,
/// since nothing about the batching/backoff machinery changes with size.
const MockConfig kFullMockConfig = MockConfig(
  name: 'Full-Length Mock',
  durationMinutes: 120,
  sections: [
    MockSectionSpec(
        section: QuizSection.english, label: 'English', count: 20),
    MockSectionSpec(
        section: QuizSection.gkCurrentAffairs,
        label: 'GK / Current Affairs',
        count: 30),
    MockSectionSpec(
        section: QuizSection.legalReasoning,
        label: 'Legal Reasoning',
        count: 30),
    MockSectionSpec(
        section: QuizSection.logicalReasoning,
        label: 'Logical Reasoning',
        count: 28),
    MockSectionSpec(section: QuizSection.quant, label: 'Quant', count: 12),
  ],
);

/// Progress snapshot handed to the UI during generation.
class MockGenerationProgress {
  final String sectionLabel;
  final int sectionIndex; // 0-based
  final int totalSections;
  final int overallGenerated;
  final int overallTotal;

  const MockGenerationProgress({
    required this.sectionLabel,
    required this.sectionIndex,
    required this.totalSections,
    required this.overallGenerated,
    required this.overallTotal,
  });
}

// Same pacing constant Groq's own generators use between batches — applied
// here too between SECTIONS, since switching sections is still back-to-back
// Groq traffic against the same free-tier tokens/minute cap.
const Duration _kSectionPause = Duration(seconds: 10);

class MockGeneratorService {
  static Future<List<QuizQuestion>> generate({
    required String apiKey,
    required MockConfig config,
    void Function(MockGenerationProgress progress)? onProgress,
  }) async {
    final overallTotal = config.totalQuestions;
    final all = <QuizQuestion>[];
    List<RssHeadline>? headlines;

    for (var i = 0; i < config.sections.length; i++) {
      final spec = config.sections[i];

      if (i > 0) {
        await Future.delayed(_kSectionPause);
      }

      void reportSectionProgress(int generatedInSection, int sectionTotal) {
        onProgress?.call(MockGenerationProgress(
          sectionLabel: spec.label,
          sectionIndex: i,
          totalSections: config.sections.length,
          overallGenerated: all.length + generatedInSection,
          overallTotal: overallTotal,
        ));
      }

      List<QuizQuestion> sectionQuestions;
      switch (spec.section) {
        case QuizSection.english:
          sectionQuestions = await GroqService.generateEnglishQuestions(
            apiKey: apiKey,
            count: spec.count,
            onProgress: reportSectionProgress,
          );
          break;

        case QuizSection.gkCurrentAffairs:
          headlines ??= await RssService.fetchAllHeadlines();
          sectionQuestions = await GroqService.generateGkQuestions(
            apiKey: apiKey,
            headlines: headlines,
            count: spec.count,
            onProgress: reportSectionProgress,
          );
          break;

        case QuizSection.legalReasoning:
          sectionQuestions = await GroqService.generateQuestions(
            apiKey: apiKey,
            count: spec.count,
            onProgress: reportSectionProgress,
          );
          break;

        case QuizSection.logicalReasoning:
          sectionQuestions =
              await GroqService.generateLogicalReasoningQuestions(
            apiKey: apiKey,
            count: spec.count,
            onProgress: reportSectionProgress,
          );
          break;

        case QuizSection.quant:
          sectionQuestions = await GroqService.generateQuantQuestions(
            apiKey: apiKey,
            count: spec.count,
            onProgress: reportSectionProgress,
          );
          break;

        default:
          throw StateError('Unknown mock section: ${spec.section}');
      }

      all.addAll(sectionQuestions.map((q) => q.copyWith(section: spec.section)));
    }

    return all;
  }
}
