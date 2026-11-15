// ============================================================================
// GENERIC QUIZ RESULTS SCREEN
// Score + a reviewable list of all questions with the user's answer, the
// correct answer, and the explanation. Generalized from
// legal_reasoning_results_screen.dart — parameterized by `sectionLabel` so
// the title reads correctly for any section (Legal Reasoning, GK/Current
// Affairs, future Logical Reasoning/Quant).
// ============================================================================

import 'package:flutter/material.dart';
import '../main.dart' show AppColors, IconBadge;
import '../models/quiz_models.dart';

class QuizResultsScreen extends StatelessWidget {
  final List<QuizQuestion> questions;
  final List<int?> selected;
  final int score;
  final String sectionLabel;

  const QuizResultsScreen({
    super.key,
    required this.questions,
    required this.selected,
    required this.score,
    required this.sectionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final total = questions.length;
    return Scaffold(
      appBar: AppBar(title: Text('$sectionLabel Results')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const IconBadge(
                        icon: Icons.emoji_events_rounded,
                        color: AppColors.primaryText,
                        size: 48,
                      ),
                      const SizedBox(width: 16),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$score',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: '/$total correct',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                itemCount: total,
                itemBuilder: (context, i) {
                  final q = questions[i];
                  final userAnswer = selected[i];
                  final isCorrect = userAnswer == q.correctIndex;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCorrect
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: isCorrect
                                    ? AppColors.successText
                                    : AppColors.dangerText,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Question ${i + 1}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
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
                          const SizedBox(height: 8),
                          Text(
                            q.prompt,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Your answer: ${userAnswer == null ? '—' : q.options[userAnswer]}',
                            style: TextStyle(
                              color: isCorrect
                                  ? AppColors.successText
                                  : AppColors.dangerText,
                              fontSize: 13.5,
                            ),
                          ),
                          if (!isCorrect) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Correct answer: ${q.options[q.correctIndex]}',
                              style: const TextStyle(
                                  color: AppColors.successText,
                                  fontSize: 13.5),
                            ),
                          ],
                          if (q.explanation.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              q.explanation,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
