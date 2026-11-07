// ============================================================================
// DAILY SPRINT — LIST SCREEN
// Pushed (replacing DailySprintLoadingScreen) once today's passages (3 by
// default, see kDailySprintPassageCount) are generated. Shows one card per
// passage; tapping a card pushes the existing
// PassagePacerScreen -> QuestionsScreen -> ResultsScreen -> FlashcardsScreen
// flow unchanged, for that one passage. When that flow fully unwinds (user
// backs out or finishes), control returns here so another passage can be
// picked, or the user backs out to Home.
//
// Deliberately stateless about completion persistence — "visited" is just a
// local, session-only highlight (not written to storage) so a user re-
// opening the app tomorrow doesn't see stale state; StorageService already
// records the real stats (words read, WPM, sessions) per completed passage
// inside the existing flow, untouched by this screen.
// ============================================================================

import 'package:flutter/material.dart';
import '../main.dart' show AppColors, AppStyle, PassagePacerScreen;
import '../models/daily_sprint_models.dart';

class DailySprintListScreen extends StatefulWidget {
  final List<PassageModel> passages;
  const DailySprintListScreen({super.key, required this.passages});

  @override
  State<DailySprintListScreen> createState() => _DailySprintListScreenState();
}

class _DailySprintListScreenState extends State<DailySprintListScreen> {
  final Set<int> _visited = {};

  Future<void> _openPassage(int index) async {
    final passage = widget.passages[index];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PassagePacerScreen(passage: passage),
      ),
    );
    if (mounted) setState(() => _visited.add(index));
  }

  @override
  Widget build(BuildContext context) {
    final passages = widget.passages;
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Reading")),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppStyle.pagePadding),
          children: [
            Text(
              '${passages.length} stor${passages.length == 1 ? 'y' : 'ies'} picked for today, '
              'most CLAT-relevant first.',
              style: const TextStyle(color: AppColors.slate400, fontSize: 14),
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < passages.length; i++) ...[
              _PassageCard(
                index: i,
                passage: passages[i],
                visited: _visited.contains(i),
                onTap: () => _openPassage(i),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _PassageCard extends StatelessWidget {
  final int index;
  final PassageModel passage;
  final bool visited;
  final VoidCallback onTap;

  const _PassageCard({
    required this.index,
    required this.passage,
    required this.visited,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.slate900,
      borderRadius: BorderRadius.circular(AppStyle.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppStyle.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppStyle.radiusMd),
            border: Border.all(
              color: visited ? AppColors.emerald500.withOpacity(0.35) : AppColors.slate800,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: visited
                      ? AppColors.emerald500.withOpacity(0.15)
                      : AppColors.indigo500.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppStyle.radiusSm),
                ),
                child: visited
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.emerald400, size: 18)
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppColors.indigo400,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passage.title,
                      style: const TextStyle(
                        color: AppColors.slate100,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${passage.wordCount} words · ${passage.questions.length} questions',
                      style: const TextStyle(
                        color: AppColors.slate400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate600),
            ],
          ),
        ),
      ),
    );
  }
}
