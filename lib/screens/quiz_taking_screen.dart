// ============================================================================
// GENERIC QUIZ-TAKING SCREEN
// One question at a time, single-select, no going back once answered.
// Generalized from legal_reasoning_quiz_screen.dart so every section
// (Legal Reasoning, GK/Current Affairs, Logical Reasoning, Quant, English)
// shares this one screen instead of a per-section copy — parameterized by
// `section` (storage key / attempt tag) and `sectionLabel` (shown on the
// results screen title). Shows `question.passage` above the question when
// present (English/RC questions carry their shared passage text there).
// ============================================================================

import 'package:flutter/material.dart';
import '../main.dart' show AppColors, AppStyle;
import '../models/quiz_models.dart';
import '../models/topic_performance_models.dart';
import '../services/quiz_storage_service.dart';
import '../services/topic_performance_service.dart';
import 'quiz_results_screen.dart';

class QuizTakingScreen extends StatefulWidget {
  final List<QuizQuestion> questions;
  final String section;
  final String sectionLabel;

  const QuizTakingScreen({
    super.key,
    required this.questions,
    required this.section,
    required this.sectionLabel,
  });

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> {
  late List<int?> _selected;
  int _currentIndex = 0;
  final DateTime _startTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selected = List<int?>.filled(widget.questions.length, null);
  }

  void _select(int i) => setState(() => _selected[_currentIndex] = i);

  Future<void> _goNext() async {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      await _submit();
    }
  }

  Future<void> _submit() async {
    int score = 0;
    final dateIso = DateTime.now().toIso8601String().substring(0, 10);
    final topicRecords = <TopicRecord>[];
    for (var i = 0; i < widget.questions.length; i++) {
      final isCorrect = _selected[i] == widget.questions[i].correctIndex;
      if (isCorrect) score++;
      final topic = widget.questions[i].topic;
      if (topic != null) {
        topicRecords.add(TopicRecord(
          section: widget.questions[i].section ?? widget.section,
          topic: topic,
          correct: isCorrect,
          dateIso: dateIso,
        ));
      }
    }
    final durationSeconds = DateTime.now().difference(_startTime).inSeconds;
    await QuizStorageService.recordAttempt(
      QuizAttempt(
        section: widget.section,
        dateIso: dateIso,
        score: score,
        total: widget.questions.length,
        durationSeconds: durationSeconds,
      ),
    );
    await TopicPerformanceService.recordAnswers(topicRecords);
    await QuizStorageService.clearInProgressQuestions(widget.section);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizResultsScreen(
          questions: widget.questions,
          selected: _selected,
          score: score,
          sectionLabel: widget.sectionLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentIndex];
    final total = widget.questions.length;
    final selectedIndex = _selected[_currentIndex];
    final isLast = _currentIndex == total - 1;

    return Scaffold(
      appBar: AppBar(title: Text('Question ${_currentIndex + 1} of $total')),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / total,
              minHeight: 3,
              backgroundColor: AppColors.tint,
              color: AppColors.primary,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (question.passage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppStyle.radiusLg),
                          border: Border.all(color: AppColors.tint),
                        ),
                        child: Text(
                          question.passage!,
                          style: const TextStyle(
                              color: AppColors.textBody,
                              fontSize: 13.5,
                              height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      question.prompt,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(question.options.length, (i) {
                      final isSelected = selectedIndex == i;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.15)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppStyle.radiusMd),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppStyle.radiusMd),
                            onTap: () => _select(i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 15),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppStyle.radiusMd),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.tint,
                                  width: isSelected ? 1.6 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.tint,
                                      border: Border.all(
                                          color: AppColors.lineStrong,
                                          width: 1),
                                    ),
                                    child: Text(
                                      String.fromCharCode(65 + i),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      question.options[i],
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        height: 1.4,
                                        color: AppColors.textSoft,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                height: 58,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedIndex == null ? null : _goNext,
                  child: Text(isLast ? 'Submit' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
