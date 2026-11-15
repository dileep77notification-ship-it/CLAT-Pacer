// ============================================================================
// FULL MOCK TEST — RESULTS SCREEN
// Net score (with negative marking) + a per-section breakdown table, then a
// full review grouped by section. Separate from quiz_results_screen.dart
// because the scoring here (negative marking, per-section breakdown) is a
// different shape — see mock_models.dart.
// ============================================================================

import 'package:flutter/material.dart';
import '../main.dart' show AppColors, AppStyle;
import '../models/mock_models.dart';
import '../models/quiz_models.dart';

class MockResultsScreen extends StatelessWidget {
  final MockAttempt attempt;
  final List<QuizQuestion> questions;
  final List<int?> selected;
  final bool autoSubmitted;

  const MockResultsScreen({
    super.key,
    required this.attempt,
    required this.questions,
    required this.selected,
    this.autoSubmitted = false,
  });

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final netScore = attempt.overallNetScore;
    final maxScore = attempt.overallMaxScore;
    final percent = maxScore == 0 ? 0.0 : (netScore / maxScore).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Mock Test Results')),
      body: SafeArea(
        child: Column(
          children: [
            if (autoSubmitted)
              Container(
                width: double.infinity,
                color: AppColors.warning.withOpacity(0.12),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: const Text(
                  "Time's up — this attempt was submitted automatically.",
                  style: TextStyle(color: AppColors.warning, fontSize: 12.5),
                  textAlign: TextAlign.center,
                ),
              ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  // Overall score card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: CircularProgressIndicator(
                                        value: percent,
                                        strokeWidth: 6,
                                        backgroundColor: AppColors.tint,
                                        color: percent >= 0.5
                                            ? AppColors.successText
                                            : AppColors.dangerText,
                                      ),
                                    ),
                                    Text(
                                      '${(percent * 100).round()}%',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${netScore.toStringAsFixed(2)} / ${maxScore.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Net score · ${_formatDuration(attempt.durationSeconds)}',
                                      style: const TextStyle(
                                          color: AppColors.textMuted, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _miniStat('${attempt.overallCorrect}', 'correct',
                                  AppColors.successText),
                              const SizedBox(width: 10),
                              _miniStat('${attempt.overallWrong}', 'wrong',
                                  AppColors.dangerText),
                              const SizedBox(width: 10),
                              _miniStat('${attempt.overallUnattempted}',
                                  'unattempted', AppColors.textMuted),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text('Section breakdown',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),

                  ...attempt.sections.map((s) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.label,
                                        style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${s.correct} correct · ${s.wrong} wrong · ${s.unattempted} unattempted',
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${s.netScore.toStringAsFixed(2)}/${s.maxScore.toStringAsFixed(0)}',
                                style: TextStyle(
                                    color: s.netScore >= 0
                                        ? AppColors.successText
                                        : AppColors.dangerText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      )),

                  const SizedBox(height: 16),
                  const Text('Review',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),

                  ...List.generate(questions.length, (i) {
                    final q = questions[i];
                    final userAnswer = selected[i];
                    final isCorrect = userAnswer == q.correctIndex;
                    final isUnattempted = userAnswer == null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isUnattempted
                                      ? Icons.remove_circle_outline_rounded
                                      : (isCorrect
                                          ? Icons.check_circle_rounded
                                          : Icons.cancel_rounded),
                                  color: isUnattempted
                                      ? AppColors.textFaint
                                      : (isCorrect
                                          ? AppColors.successText
                                          : AppColors.dangerText),
                                  size: 17,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Q${i + 1} · ${q.section ?? ''}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            if (q.passage != null) ...[
                              const SizedBox(height: 8),
                              Theme(
                                data: Theme.of(context)
                                    .copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: const Text('View passage',
                                      style: TextStyle(
                                          color: AppColors.primaryText,
                                          fontSize: 12.5)),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        q.passage!,
                                        style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12.5,
                                            height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              q.prompt,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isUnattempted
                                  ? 'Not attempted'
                                  : 'Your answer: ${q.options[userAnswer]}',
                              style: TextStyle(
                                color: isUnattempted
                                    ? AppColors.textMuted
                                    : (isCorrect
                                        ? AppColors.successText
                                        : AppColors.dangerText),
                                fontSize: 13,
                              ),
                            ),
                            if (!isCorrect) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Correct answer: ${q.options[q.correctIndex]}',
                                style: const TextStyle(
                                    color: AppColors.successText, fontSize: 13),
                              ),
                            ],
                            if (q.explanation.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                q.explanation,
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12.5,
                                    height: 1.4),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.lineStrong),
                      ),
                      child: const Text('Back to Home'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppStyle.radiusSm),
          border: Border.all(color: AppColors.tint),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}
