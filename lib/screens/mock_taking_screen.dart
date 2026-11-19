// ============================================================================
// FULL MOCK TEST — TAKING SCREEN
// Unlike the per-section practice screens (one question, answer, Next —
// strictly forward), a real CLAT sitting lets the candidate jump freely
// between questions and sections, mark questions for review, and submit at
// any time. This screen matches that: section tabs, Previous/Next, a
// question palette (bottom sheet), mark-for-review, and a countdown timer
// that auto-submits at zero.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart' show AppColors, AppStyle;
import '../models/mock_models.dart';
import '../models/quiz_models.dart';
import '../models/topic_performance_models.dart';
import '../services/mock_storage_service.dart';
import '../services/mock_generator_service.dart';
import '../services/topic_performance_service.dart';
import 'mock_results_screen.dart';

class _SectionRange {
  final String section;
  final String label;
  final int start; // inclusive
  final int end; // inclusive
  const _SectionRange(
      {required this.section,
      required this.label,
      required this.start,
      required this.end});
}

class MockTakingScreen extends StatefulWidget {
  final List<QuizQuestion> questions;
  final MockConfig config;

  const MockTakingScreen({
    super.key,
    required this.questions,
    required this.config,
  });

  @override
  State<MockTakingScreen> createState() => _MockTakingScreenState();
}

class _MockTakingScreenState extends State<MockTakingScreen> {
  late List<int?> _selected;
  final Set<int> _markedForReview = {};
  int _currentIndex = 0;
  late int _remainingSeconds;
  Timer? _timer;
  bool _submitting = false;
  late List<_SectionRange> _sectionRanges;
  late DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _selected = List<int?>.filled(widget.questions.length, null);
    _sectionRanges = _computeSectionRanges();
    _remainingSeconds = widget.config.durationMinutes * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        setState(() => _remainingSeconds = 0);
        _submit(auto: true);
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<_SectionRange> _computeSectionRanges() {
    final ranges = <_SectionRange>[];
    var sectionStart = 0;
    String? currentSection = widget.questions.isEmpty
        ? null
        : (widget.questions.first.section ?? 'unknown');

    String labelFor(String? section) {
      return widget.config.sections
          .firstWhere(
            (s) => s.section == section,
            orElse: () => MockSectionSpec(
                section: section ?? 'unknown',
                label: section ?? 'Unknown',
                count: 0),
          )
          .label;
    }

    for (var i = 1; i <= widget.questions.length; i++) {
      final section =
          i < widget.questions.length ? (widget.questions[i].section ?? 'unknown') : null;
      if (i == widget.questions.length || section != currentSection) {
        ranges.add(_SectionRange(
          section: currentSection ?? 'unknown',
          label: labelFor(currentSection),
          start: sectionStart,
          end: i - 1,
        ));
        sectionStart = i;
        currentSection = section;
      }
    }
    return ranges;
  }

  int get _currentSectionIndex =>
      _sectionRanges.indexWhere((r) => _currentIndex >= r.start && _currentIndex <= r.end);

  void _select(int optionIndex) =>
      setState(() => _selected[_currentIndex] = optionIndex);

  void _toggleMarkForReview() {
    setState(() {
      if (_markedForReview.contains(_currentIndex)) {
        _markedForReview.remove(_currentIndex);
      } else {
        _markedForReview.add(_currentIndex);
      }
    });
  }

  void _goTo(int index) {
    setState(() => _currentIndex = index.clamp(0, widget.questions.length - 1));
  }

  void _jumpToSection(int sectionIndex) {
    final range = _sectionRanges[sectionIndex];
    // Prefer the first unanswered question in that section; else its start.
    for (var i = range.start; i <= range.end; i++) {
      if (_selected[i] == null) {
        _goTo(i);
        return;
      }
    }
    _goTo(range.start);
  }

  int get _answeredCount => _selected.where((s) => s != null).length;

  Future<void> _confirmAndSubmit() async {
    final unattempted = widget.questions.length - _answeredCount;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Submit mock test?'),
        content: Text(
          unattempted > 0
              ? '$unattempted question${unattempted == 1 ? '' : 's'} left unattempted. Submit anyway?'
              : 'All questions attempted. Submit now?',
          style: const TextStyle(color: AppColors.textBody),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep going')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (proceed == true) {
      await _submit(auto: false);
    }
  }

  Future<void> _submit({required bool auto}) async {
    if (_submitting) return;
    _submitting = true;
    _timer?.cancel();

    final sectionResults = _sectionRanges.map((range) {
      var correct = 0, wrong = 0, unattempted = 0;
      for (var i = range.start; i <= range.end; i++) {
        final sel = _selected[i];
        if (sel == null) {
          unattempted++;
        } else if (sel == widget.questions[i].correctIndex) {
          correct++;
        } else {
          wrong++;
        }
      }
      return MockSectionResult(
        section: range.section,
        label: range.label,
        totalQuestions: range.end - range.start + 1,
        correct: correct,
        wrong: wrong,
        unattempted: unattempted,
      );
    }).toList();

    final durationSeconds =
        DateTime.now().difference(_startedAt).inSeconds;
    final dateIso = DateTime.now().toIso8601String().substring(0, 10);

    final attempt = MockAttempt(
      dateIso: dateIso,
      durationSeconds: durationSeconds,
      totalQuestions: widget.questions.length,
      sections: sectionResults,
    );

    await MockStorageService.recordAttempt(attempt);

    // Only attempted questions are logged here — an unattempted question
    // tells Brain Gym nothing about whether the candidate knows that topic,
    // and would just dilute the accuracy numbers with blanks.
    final topicRecords = <TopicRecord>[];
    for (var i = 0; i < widget.questions.length; i++) {
      final sel = _selected[i];
      final topic = widget.questions[i].topic;
      if (sel == null || topic == null) continue;
      topicRecords.add(TopicRecord(
        section: widget.questions[i].section ?? 'unknown',
        topic: topic,
        correct: sel == widget.questions[i].correctIndex,
        dateIso: dateIso,
      ));
    }
    await TopicPerformanceService.recordAnswers(topicRecords);

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MockResultsScreen(
          attempt: attempt,
          questions: widget.questions,
          selected: _selected,
          autoSubmitted: auto,
        ),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Exit mock test?'),
        content: const Text(
          'Your progress will be lost — this attempt will not be scored or saved.',
          style: TextStyle(color: AppColors.textBody),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Stay')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Exit')),
        ],
      ),
    );
    return leave ?? false;
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _timerColor() {
    if (_remainingSeconds <= 60) return AppColors.dangerText;
    if (_remainingSeconds <= 5 * 60) return AppColors.warningText;
    return AppColors.textBody;
  }

  void _showPalette() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Questions',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  for (final range in _sectionRanges) ...[
                    Text(range.label,
                        style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = range.start; i <= range.end; i++)
                          _paletteCell(i, ctx),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _paletteCell(int index, BuildContext sheetContext) {
    final isCurrent = index == _currentIndex;
    final isAnswered = _selected[index] != null;
    final isMarked = _markedForReview.contains(index);

    Color bg = AppColors.tint;
    Color border = AppColors.lineStrong;
    Color text = AppColors.textBody;
    if (isAnswered) {
      bg = AppColors.primary;
      border = AppColors.primary;
      text = Colors.white;
    }
    if (isMarked) {
      border = AppColors.warning;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(AppStyle.radiusSm),
      onTap: () {
        Navigator.of(sheetContext).pop();
        _goTo(index);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppStyle.radiusSm),
          border: Border.all(
              color: border, width: isCurrent ? 2.2 : (isMarked ? 1.8 : 1)),
        ),
        alignment: Alignment.center,
        child: Text('${index + 1}',
            style: TextStyle(
                color: text, fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentIndex];
    final selectedIndex = _selected[_currentIndex];
    final isLastOverall = _currentIndex == widget.questions.length - 1;
    final currentSectionIdx = _currentSectionIndex;

    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(currentSectionIdx >= 0
              ? _sectionRanges[currentSectionIdx].label
              : 'Mock Test'),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppStyle.radiusSm),
                border: Border.all(color: AppColors.tint),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 15, color: _timerColor()),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                        color: _timerColor(),
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _confirmAndSubmit,
              child: const Text('Submit'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Section tabs
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _sectionRanges.length,
                  itemBuilder: (context, i) {
                    final range = _sectionRanges[i];
                    final isActive = i == currentSectionIdx;
                    var answered = 0;
                    for (var q = range.start; q <= range.end; q++) {
                      if (_selected[q] != null) answered++;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppStyle.radiusSm),
                        onTap: () => _jumpToSection(i),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary.withOpacity(0.18)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppStyle.radiusSm),
                            border: Border.all(
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.tint),
                          ),
                          child: Text(
                            '${range.label} ($answered/${range.end - range.start + 1})',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppColors.primaryText
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: AppColors.tint),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Question ${_currentIndex + 1} of ${widget.questions.length}',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12.5)),
                          const Spacer(),
                          if (_markedForReview.contains(_currentIndex))
                            const Icon(Icons.bookmark_rounded,
                                size: 16, color: AppColors.warning),
                        ],
                      ),
                      const SizedBox(height: 10),

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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),

                      ...List.generate(question.options.length, (i) {
                        final isSelected = selectedIndex == i;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.09)
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
                                            color: AppColors.lineStrong, width: 1),
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
                                          fontSize: 15,
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

              const Divider(height: 1, color: AppColors.tint),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _currentIndex == 0
                          ? null
                          : () => _goTo(_currentIndex - 1),
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: 'Previous',
                    ),
                    IconButton(
                      onPressed: _toggleMarkForReview,
                      icon: Icon(
                        _markedForReview.contains(_currentIndex)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: _markedForReview.contains(_currentIndex)
                            ? AppColors.warning
                            : AppColors.textMuted,
                      ),
                      tooltip: 'Mark for review',
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showPalette,
                        icon: const Icon(Icons.grid_view_rounded, size: 16),
                        label: Text('${_answeredCount}/${widget.questions.length}'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.lineStrong),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLastOverall
                              ? _confirmAndSubmit
                              : () => _goTo(_currentIndex + 1),
                          child: Text(isLastOverall ? 'Review & Submit' : 'Next'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
