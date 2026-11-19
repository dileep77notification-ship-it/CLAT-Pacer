// ============================================================================
// CLAT Daily Sprint — Reading Speed, Stamina & Elimination Trainer
// ----------------------------------------------------------------------------
// Single-file Flutter app (paste directly into FlutLab / any online builder,
// or drop into a fresh `flutter create` project's lib/main.dart).
//
// Flow: Home → Passage Pacer (timed read + WPM) → Questions (elimination UI)
//       → Results → Flashcards (current-affairs context) → back to Home
//
// Persistence: shared_preferences only (fully offline, no backend).
// State management: plain StatefulWidget + a static StorageService singleton.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/settings_screen.dart';
import 'screens/legal_reasoning_screen.dart';
import 'screens/gk_quiz_screen.dart';
import 'screens/logical_reasoning_screen.dart';
import 'screens/quant_screen.dart';
import 'screens/english_screen.dart';
import 'screens/mock_loading_screen.dart';
import 'screens/daily_sprint_loading_screen.dart';
import 'screens/brain_gym_screen.dart';
import 'models/daily_sprint_models.dart';
import 'services/daily_article_service.dart' show kDailySprintPassageCount;
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/home_widgets.dart';

// Existing screens import AppColors / AppStyle / IconBadge / SectionHeader from
// here; the definitions now live in theme/app_theme.dart.
export 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const ClatPacerApp());
}

class ClatPacerApp extends StatelessWidget {
  const ClatPacerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CLAT Daily Sprint',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}

// ============================================================================
// SECTION 2 — MODELS
// Moved to models/daily_sprint_models.dart (imported above) so the new
// DailyArticleService can build a PassageModel without importing main.dart.
// ============================================================================

// ============================================================================
// SECTION 3 — LEGACY DUMMY DATA
// No longer wired to the Start button (see SECTION 5 — HOME SCREEN, which
// now routes through DailySprintLoadingScreen for live RSS + Sarvam content).
// Left in place, unused, as a quick offline reference/fixture if needed.
// ============================================================================

final PassageModel todaysSprint = PassageModel(
  title: "The Basic Structure Doctrine",
  body: '''
The Basic Structure Doctrine stands as one of the most consequential judicial
inventions in Indian constitutional history, fundamentally altering the
relationship between Parliament's amending power and the judiciary's role as
guardian of the Constitution. Article 368 grants Parliament wide powers to
amend the Constitution, and for the first two decades after independence, the
prevailing view, affirmed in Shankari Prasad and Sajjan Singh, was that this
power extended even to fundamental rights. This position was overturned in
Golak Nath v. State of Punjab (1967), where the Supreme Court held that
Parliament could not amend Part III of the Constitution, treating fundamental
rights as transcendental and beyond legislative reach. The resulting tension
between parliamentary supremacy and constitutional rigidity culminated in the
landmark case of Kesavananda Bharati v. State of Kerala (1973), decided by
the largest bench ever assembled by the Supreme Court, comprising thirteen
judges. By a narrow majority of seven to six, the Court ruled that while
Parliament possesses the power to amend any part of the Constitution,
including fundamental rights, this power is not unlimited. It cannot be used
to alter or destroy the "basic structure" or framework of the Constitution.
The judgment, however, did not provide an exhaustive list of what constitutes
this basic structure, leaving it to subsequent benches to identify its
contours on a case-by-case basis. Over the following decades, the Supreme
Court has held that several features form part of this basic structure,
including the supremacy of the Constitution, the rule of law, the principle
of separation of powers, judicial review, federalism, secularism, and free
and fair elections. The doctrine was tested severely during the Emergency
era, most notably in Indira Nehru Gandhi v. Raj Narain (1975), where the
Court struck down a constitutional amendment that sought to place the
election of the Prime Minister beyond judicial scrutiny, holding that free
and fair elections constituted part of the basic structure. Subsequently, in
Minerva Mills v. Union of India (1980), the Court invalidated clauses of the
42nd Amendment that sought to give Directive Principles primacy over
Fundamental Rights without limit, reaffirming that the harmony and balance
between Fundamental Rights and Directive Principles is itself part of the
basic structure. Critics of the doctrine argue that it represents an
unwarranted judicial encroachment upon the constituent power of Parliament,
effectively allowing unelected judges to override the will of elected
representatives by invoking an undefined and judicially created standard.
Defenders counter that without such a doctrine, a transient parliamentary
majority could, through the amendment process, dismantle democracy itself
from within, and that the basic structure doctrine therefore serves as the
ultimate safeguard of constitutionalism against majoritarian excess. The
doctrine has since been invoked in diverse contexts, including the National
Judicial Appointments Commission case (2015), where the Supreme Court struck
down a constitutional amendment establishing a new mechanism for judicial
appointments on the ground that it violated the basic structure principle of
judicial independence, demonstrating the doctrine's continuing vitality as a
check on the amending power even in contemporary constitutional disputes.
''',
  questions: const [
    QuestionModel(
      prompt:
          "Which case first established that Parliament's amending power under Article 368 could not touch fundamental rights at all?",
      options: [
        "Kesavananda Bharati v. State of Kerala",
        "Golak Nath v. State of Punjab",
        "Minerva Mills v. Union of India",
        "Indira Nehru Gandhi v. Raj Narain",
      ],
      correctIndex: 1,
    ),
    QuestionModel(
      prompt:
          "The Kesavananda Bharati judgment was decided by a bench of how many judges, and by what majority?",
      options: [
        "Eleven judges, by a majority of six to five",
        "Nine judges, by a majority of five to four",
        "Thirteen judges, by a majority of seven to six",
        "Fifteen judges, by a majority of eight to seven",
      ],
      correctIndex: 2,
    ),
    QuestionModel(
      prompt:
          "According to the passage, what did the Court hold in Indira Nehru Gandhi v. Raj Narain (1975)?",
      options: [
        "That Directive Principles take precedence over Fundamental Rights",
        "That free and fair elections form part of the basic structure",
        "That judicial appointments are beyond judicial review",
        "That Parliament cannot amend the Constitution during an Emergency",
      ],
      correctIndex: 1,
    ),
    QuestionModel(
      prompt:
          "Which of the following is cited in the passage as an example of a feature of the basic structure?",
      options: [
        "Reservation in public employment",
        "The President's pardoning power",
        "Separation of powers",
        "The right to property",
      ],
      correctIndex: 2,
    ),
    QuestionModel(
      prompt:
          "What is the main criticism of the basic structure doctrine mentioned in the passage?",
      options: [
        "It makes constitutional amendments impossible in practice",
        "It allows unelected judges to override elected representatives using an undefined standard",
        "It was created without any judicial precedent",
        "It applies only to economic legislation",
      ],
      correctIndex: 1,
    ),
  ],
  flashcards: const [
    FlashcardModel(
      title: "Kesavananda Bharati (1973)",
      fact:
          "Decided by the largest-ever 13-judge bench of the Supreme Court; the 7-6 majority birthed the Basic Structure Doctrine and is widely regarded as independent India's most important constitutional ruling.",
    ),
    FlashcardModel(
      title: "Golak Nath v. State of Punjab (1967)",
      fact:
          "Held fundamental rights to be beyond the reach of Parliament's amending power entirely — a position later refined, not reversed, by Kesavananda Bharati's basic structure test.",
    ),
    FlashcardModel(
      title: "42nd Amendment (1976)",
      fact:
          "Passed during the Emergency, it is often called the 'Mini-Constitution' for the scale of changes it made, including attempts to subordinate Fundamental Rights to Directive Principles — later curtailed in Minerva Mills.",
    ),
    FlashcardModel(
      title: "NJAC Case (2015)",
      fact:
          "The Supreme Court struck down the 99th Constitutional Amendment and the NJAC Act, holding that an independent judiciary and judicial primacy in appointments are part of the basic structure.",
    ),
    FlashcardModel(
      title: "Article 368",
      fact:
          "The constitutional provision granting Parliament the power to amend the Constitution, subject — per the basic structure doctrine — to the limitation that its essential framework cannot be destroyed.",
    ),
  ],
);

// ============================================================================
// SECTION 4 — STORAGE SERVICE
// Thin static wrapper around shared_preferences. All reads/writes are async.
// ============================================================================

class StorageService {
  static const _kStreak = 'clat_streak';
  static const _kTotalWords = 'clat_total_words';
  static const _kAvgWpm = 'clat_avg_wpm';
  static const _kSessionsCount = 'clat_sessions_count';
  static const _kLastCompletedDate = 'clat_last_completed_date'; // yyyy-MM-dd

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static String _yesterdayKey() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year.toString().padLeft(4, '0')}-'
        '${y.month.toString().padLeft(2, '0')}-'
        '${y.day.toString().padLeft(2, '0')}';
  }

  static Future<DashboardStats> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    return DashboardStats(
      streak: prefs.getInt(_kStreak) ?? 0,
      totalWordsRead: prefs.getInt(_kTotalWords) ?? 0,
      averageWpm: prefs.getDouble(_kAvgWpm) ?? 0.0,
      sessionsCount: prefs.getInt(_kSessionsCount) ?? 0,
      lastCompletedDate: prefs.getString(_kLastCompletedDate),
    );
  }

  /// Records the completion of a Daily Sprint: updates streak (once per
  /// calendar day), running total of words read, and the rolling average WPM.
  static Future<DashboardStats> recordSprintCompletion({
    required int wordsRead,
    required int sessionWpm,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await loadStats();

    final today = _todayKey();
    final yesterday = _yesterdayKey();

    int newStreak = stats.streak;
    if (stats.lastCompletedDate != today) {
      // First sprint completed today — eligible to extend/reset the streak.
      if (stats.lastCompletedDate == yesterday) {
        newStreak = stats.streak + 1;
      } else {
        newStreak = 1; // streak was broken (or this is the first-ever sprint)
      }
    }

    final newSessionsCount = stats.sessionsCount + 1;
    final newAvgWpm =
        ((stats.averageWpm * stats.sessionsCount) + sessionWpm) /
            newSessionsCount;
    final newTotalWords = stats.totalWordsRead + wordsRead;

    await prefs.setInt(_kStreak, newStreak);
    await prefs.setInt(_kTotalWords, newTotalWords);
    await prefs.setDouble(_kAvgWpm, newAvgWpm);
    await prefs.setInt(_kSessionsCount, newSessionsCount);
    await prefs.setString(_kLastCompletedDate, today);

    return DashboardStats(
      streak: newStreak,
      totalWordsRead: newTotalWords,
      averageWpm: newAvgWpm,
      sessionsCount: newSessionsCount,
      lastCompletedDate: today,
    );
  }
}

class DashboardStats {
  final int streak;
  final int totalWordsRead;
  final double averageWpm;
  final int sessionsCount;
  final String? lastCompletedDate;

  const DashboardStats({
    required this.streak,
    required this.totalWordsRead,
    required this.averageWpm,
    required this.sessionsCount,
    required this.lastCompletedDate,
  });
}

// ============================================================================
// SECTION 5 — HOME SCREEN (Dashboard)
// ============================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _SectionGroup { verbal, reasoning, numeric, drills }

class _PracticeSection {
  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;
  final List<Color> colors;
  final _SectionGroup group;
  final Widget Function() builder;

  const _PracticeSection({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.icon,
    required this.colors,
    required this.group,
    required this.builder,
  });
}

final List<_PracticeSection> _practiceSections = [
  _PracticeSection(
    title: 'Legal Reasoning',
    subtitle: 'Principle + facts',
    meta: '10 questions',
    icon: Icons.gavel_rounded,
    colors: AppColors.gradBlue,
    group: _SectionGroup.reasoning,
    builder: () => const LegalReasoningScreen(),
  ),
  _PracticeSection(
    title: 'GK / Current Affairs',
    subtitle: 'Headline-grounded',
    meta: '10 questions',
    icon: Icons.public_rounded,
    colors: AppColors.gradOrange,
    group: _SectionGroup.verbal,
    builder: () => const GkQuizScreen(),
  ),
  _PracticeSection(
    title: 'Logical Reasoning',
    subtitle: 'Argument-based',
    meta: '10 questions',
    icon: Icons.psychology_rounded,
    colors: AppColors.gradPurple,
    group: _SectionGroup.reasoning,
    builder: () => const LogicalReasoningScreen(),
  ),
  _PracticeSection(
    title: 'Quantitative Techniques',
    subtitle: 'Basic-maths data',
    meta: '10 questions',
    icon: Icons.calculate_rounded,
    colors: AppColors.gradTeal,
    group: _SectionGroup.numeric,
    builder: () => const QuantScreen(),
  ),
  _PracticeSection(
    title: 'English & RC',
    subtitle: 'Passage-based',
    meta: '10 questions',
    icon: Icons.menu_book_rounded,
    colors: AppColors.gradCyan,
    group: _SectionGroup.verbal,
    builder: () => const EnglishScreen(),
  ),
  _PracticeSection(
    title: 'Brain Gym',
    subtitle: 'Drill your weak topics',
    meta: '5-Q drills',
    icon: Icons.fitness_center_rounded,
    colors: AppColors.gradRose,
    group: _SectionGroup.drills,
    builder: () => const BrainGymScreen(),
  ),
];

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late Future<DashboardStats> _statsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _SectionGroup? _group; // null = "All"

  static const List<NavItem> _navItems = [
    NavItem(Icons.home_rounded, 'Home'),
    NavItem(Icons.assignment_rounded, 'Mock Test'),
    NavItem(Icons.fitness_center_rounded, 'Brain Gym'),
    NavItem(Icons.settings_rounded, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _statsFuture = StorageService.loadStats();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep the rolling 30-day reminder window topped up.
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.refresh();
    }
  }

  void _refresh() {
    setState(() {
      _statsFuture = StorageService.loadStats();
    });
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openSprint() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DailySprintLoadingScreen()),
    );
    if (mounted) _refresh();
  }

  void _onNavTap(int index) {
    switch (index) {
      case 1:
        _push(const MockLoadingScreen());
      case 2:
        _push(const BrainGymScreen());
      case 3:
        _push(const SettingsScreen());
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  List<_PracticeSection> get _visibleSections {
    final q = _query.trim().toLowerCase();
    return _practiceSections.where((s) {
      final inGroup = _group == null || s.group == _group;
      final matches = q.isEmpty ||
          s.title.toLowerCase().contains(q) ||
          s.subtitle.toLowerCase().contains(q);
      return inGroup && matches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBody: true,
        bottomNavigationBar: FloatingNavBar(
          items: _navItems,
          selected: 0,
          onTap: _onNavTap,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bgTop, AppColors.bg],
              stops: [0.0, 0.5],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: FutureBuilder<DashboardStats>(
              future: _statsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: _buildContent(snapshot.data!),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(DashboardStats stats) {
    final doneToday = stats.lastCompletedDate == StorageService._todayKey();
    final sections = _visibleSections;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppStyle.pagePadding, 14,
          AppStyle.pagePadding, 120),
      children: [
        // ---- Header -------------------------------------------------------
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting()},',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Ready to sprint?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            _StreakPill(streak: stats.streak),
          ],
        ),
        const SizedBox(height: 22),

        // ---- Today's sprint ----------------------------------------------
        HeroBanner(
          title: doneToday ? 'Sprint done for today' : "Today's Daily Sprint",
          subtitle: doneToday
              ? 'Nice work. Read another passage to keep your edge.'
              : '$kDailySprintPassageCount passages with questions and '
                  "flashcards, fresh from today's news.",
          buttonLabel: doneToday ? 'Go again' : 'Start now',
          icon: doneToday ? Icons.check_rounded : Icons.bolt_rounded,
          colors: AppColors.gradBlue,
          onTap: _openSprint,
        ),
        const SizedBox(height: 18),

        // ---- Stats --------------------------------------------------------
        Row(
          children: [
            Expanded(child: _StreakCard(streak: stats.streak)),
            const SizedBox(width: 14),
            Expanded(
              child: _StatCard(
                icon: Icons.speed_rounded,
                iconColor: AppColors.primaryText,
                label: 'Avg. Speed',
                value: stats.averageWpm == 0
                    ? '—'
                    : stats.averageWpm.round().toString(),
                suffix: stats.averageWpm == 0 ? '' : ' WPM',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _WordsConqueredCard(totalWords: stats.totalWordsRead),
        const SizedBox(height: 14),
        _StatCard(
          icon: Icons.task_alt_rounded,
          iconColor: AppColors.successText,
          label: 'Sprints Completed',
          value: stats.sessionsCount.toString(),
          suffix: '',
          fullWidth: true,
        ),
        const SizedBox(height: AppStyle.sectionGap),

        // ---- Mock test ----------------------------------------------------
        HeroBanner(
          title: 'Full Mock Test',
          subtitle: 'Half or full length · all 5 sections · negative marking',
          buttonLabel: 'Take a mock',
          icon: Icons.assignment_rounded,
          colors: AppColors.gradPurple,
          onTap: () => _push(const MockLoadingScreen()),
        ),
        const SizedBox(height: AppStyle.sectionGap),

        // ---- Practice by section ------------------------------------------
        const SectionHeader(
          title: 'Practice by section',
          subtitle: 'Fresh, Sarvam-generated questions every time',
        ),
        AppSearchField(
          controller: _searchController,
          hint: 'Search sections',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              for (final chip in <(_SectionGroup?, String, IconData)>[
                (null, 'All', Icons.apps_rounded),
                (_SectionGroup.verbal, 'Verbal', Icons.menu_book_rounded),
                (_SectionGroup.reasoning, 'Reasoning', Icons.psychology_rounded),
                (_SectionGroup.numeric, 'Quant', Icons.calculate_rounded),
                (_SectionGroup.drills, 'Drills', Icons.fitness_center_rounded),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 2, bottom: 2),
                  child: AppPill(
                    label: chip.$2,
                    icon: chip.$3,
                    selected: _group == chip.$1,
                    onTap: () => setState(() => _group = chip.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (sections.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppStyle.radiusLg),
            ),
            child: Text(
              _query.trim().isEmpty
                  ? 'Nothing in this group yet.'
                  : 'No sections match "${_query.trim()}".',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: sections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final s = sections[i];
                return SizedBox(
                  width: 170,
                  child: SectionCard(
                    icon: s.icon,
                    title: s.title,
                    subtitle: s.subtitle,
                    meta: s.meta,
                    colors: s.colors,
                    onTap: () => _push(s.builder()),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Flame + count pill shown top-right of the Home header.
class _StreakPill extends StatelessWidget {
  final int streak;
  const _StreakPill({required this.streak});

  @override
  Widget build(BuildContext context) {
    final active = streak > 0;
    return Semantics(
      label: '$streak day streak',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppStyle.radiusPill),
            boxShadow: AppStyle.softShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: active ? AppColors.warning : AppColors.textFaint,
                size: 22,
              ),
              const SizedBox(width: 6),
              Text(
                '$streak',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final isActive = streak > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: isActive ? AppColors.warning : AppColors.textFaint,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              '$streak',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              streak == 1 ? 'day streak' : 'day streak',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String suffix;
  final bool fullWidth;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.suffix,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: fullWidth
            ? Row(
                children: [
                  Icon(icon, color: iconColor, size: 26),
                  const SizedBox(width: 12),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: iconColor, size: 28),
                  const SizedBox(height: 10),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: suffix,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Odometer-style display for total words read — digits in individual
/// slate "tiles" to mimic a mechanical counter.
class _WordsConqueredCard extends StatelessWidget {
  final int totalWords;
  const _WordsConqueredCard({required this.totalWords});

  @override
  Widget build(BuildContext context) {
    final digits = totalWords.toString().padLeft(6, '0').split('');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded,
                color: AppColors.successText, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Words Conquered',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: digits
                        .map((d) => Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.tint,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppColors.lineStrong, width: 1),
                              ),
                              child: Text(
                                d,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.successText,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION 6 — PASSAGE PACER SCREEN
// Timed reading screen. Tracks elapsed time from first build to the
// "Done Reading" tap to compute WPM. A 5-minute countdown is shown at top;
// if it expires, the user is auto-advanced to the questions.
// ============================================================================

class PassagePacerScreen extends StatefulWidget {
  final PassageModel passage;
  const PassagePacerScreen({super.key, required this.passage});

  @override
  State<PassagePacerScreen> createState() => _PassagePacerScreenState();
}

class _PassagePacerScreenState extends State<PassagePacerScreen> {
  static const int _totalSeconds = 5 * 60; // 5-minute strict cap
  late int _secondsRemaining;
  late Timer _timer;
  late final DateTime _startTime;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _secondsRemaining = _totalSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining <= 1) {
        t.cancel();
        setState(() => _secondsRemaining = 0);
        _finishReading(timedOut: true);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  int _computeWpm() {
    final elapsed = DateTime.now().difference(_startTime).inSeconds;
    final safeElapsed = elapsed < 1 ? 1 : elapsed; // avoid divide-by-zero
    final wpm = (widget.passage.wordCount / (safeElapsed / 60)).round();
    return wpm;
  }

  Future<void> _finishReading({bool timedOut = false}) async {
    if (_advancing) return;
    _advancing = true;
    if (_timer.isActive) _timer.cancel();
    final wpm = _computeWpm();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestionsScreen(
          passage: widget.passage,
          wpm: wpm,
        ),
      ),
    );

    if (mounted) Navigator.of(context).pop(); // return to Home after flow
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isWarning = _secondsRemaining <= 30;
    return PopScope(
      canPop: false, // prevent accidental back-swipe mid-timer
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.timer_rounded,
                  size: 20,
                  color: isWarning ? AppColors.dangerText : AppColors.primaryText),
              const SizedBox(width: 8),
              Text(
                _formatTime(_secondsRemaining),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isWarning ? AppColors.dangerText : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(
                value: _secondsRemaining / _totalSeconds,
                minHeight: 3,
                backgroundColor: AppColors.tint,
                color: isWarning ? AppColors.danger : AppColors.primary,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.passage.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.passage.wordCount} words',
                        style: const TextStyle(
                            color: AppColors.textFaint, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.passage.body.trim(),
                        style: const TextStyle(
                          fontSize: 16.5,
                          height: 1.6,
                          color: AppColors.textBody,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  height: 58,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Done Reading'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    onPressed: () => _finishReading(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION 7 — QUESTIONS SCREEN (Elimination Engine)
// Tap an option to select it as your answer. Tap the strike icon beside an
// option (or long-press the option itself) to visually cross it out — the
// "process of elimination" trainer. Struck options can still be selected,
// but the UI nudges elimination before commitment.
// ============================================================================

class QuestionsScreen extends StatefulWidget {
  final PassageModel passage;
  final int wpm;
  const QuestionsScreen({super.key, required this.passage, required this.wpm});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  late List<int?> _selected;
  late List<Set<int>> _struck; // which option indices are struck, per question
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    final n = widget.passage.questions.length;
    _selected = List<int?>.filled(n, null);
    _struck = List.generate(n, (_) => <int>{});
  }

  void _toggleStrike(int optionIndex) {
    setState(() {
      final set = _struck[_currentIndex];
      if (set.contains(optionIndex)) {
        set.remove(optionIndex);
      } else {
        set.add(optionIndex);
      }
    });
  }

  void _select(int optionIndex) {
    setState(() => _selected[_currentIndex] = optionIndex);
  }

  void _goNext() {
    if (_currentIndex < widget.passage.questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _submit();
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  Future<void> _submit() async {
    int score = 0;
    for (var i = 0; i < widget.passage.questions.length; i++) {
      if (_selected[i] == widget.passage.questions[i].correctIndex) {
        score++;
      }
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          passage: widget.passage,
          wpm: widget.wpm,
          score: score,
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop(); // unwind back to Pacer→Home
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.passage.questions[_currentIndex];
    final total = widget.passage.questions.length;
    final struckSet = _struck[_currentIndex];
    final selectedIndex = _selected[_currentIndex];
    final isLast = _currentIndex == total - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentIndex + 1} of $total'),
      ),
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
                    Text(
                      question.prompt,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(question.options.length, (i) {
                      final isStruck = struckSet.contains(i);
                      final isSelected = selectedIndex == i;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onLongPress: () => _toggleStrike(i),
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
                                    _OptionBullet(
                                        label: String.fromCharCode(65 + i),
                                        selected: isSelected,
                                        struck: isStruck),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        question.options[i],
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          height: 1.4,
                                          color: isStruck
                                              ? AppColors.textFaint
                                              : AppColors.textSoft,
                                          decoration: isStruck
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                          decorationThickness: 2,
                                          decorationColor: AppColors.dangerText,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: isStruck
                                          ? 'Restore option'
                                          : 'Strike out option',
                                      icon: Icon(
                                        isStruck
                                            ? Icons.replay_rounded
                                            : Icons
                                                .format_strikethrough_rounded,
                                        size: 20,
                                        color: isStruck
                                            ? AppColors.successText
                                            : AppColors.textFaint,
                                      ),
                                      onPressed: () => _toggleStrike(i),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    const Text(
                      'Tip: long-press or tap the strike icon to eliminate an option.',
                      style: TextStyle(color: AppColors.textFaint, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  if (_currentIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _goPrev,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.lineStrong),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: selectedIndex == null ? null : _goNext,
                      child: Text(isLast ? 'Submit' : 'Next'),
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
}

class _OptionBullet extends StatelessWidget {
  final String label;
  final bool selected;
  final bool struck;
  const _OptionBullet(
      {required this.label, required this.selected, required this.struck});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : AppColors.tint,
        border: Border.all(
          color: struck ? AppColors.dangerText : AppColors.lineStrong,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION 8 — RESULTS SCREEN
// ============================================================================

class ResultsScreen extends StatelessWidget {
  final PassageModel passage;
  final int wpm;
  final int score;

  const ResultsScreen({
    super.key,
    required this.passage,
    required this.wpm,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final total = passage.questions.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Sprint Results')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ResultTile(
                      icon: Icons.speed_rounded,
                      color: AppColors.primaryText,
                      label: 'Reading Speed',
                      value: '$wpm',
                      suffix: ' WPM',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ResultTile(
                      icon: Icons.fact_check_rounded,
                      color: AppColors.successText,
                      label: 'Accuracy',
                      value: '$score',
                      suffix: '/$total',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Current Affairs Context Web',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '5 connected facts to lock this passage into memory.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const Spacer(),
              SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.style_rounded),
                  label: const Text('Review Flashcards'),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FlashcardsScreen(
                          passage: passage,
                          wpm: wpm,
                        ),
                      ),
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String suffix;

  const _ResultTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: suffix,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION 9 — FLASHCARDS SCREEN (swipeable, Tinder-style)
// Uses a PageView for reliable swipe navigation across devices. On reaching
// the last card, "Finish Sprint" commits stats to storage.
// ============================================================================

class FlashcardsScreen extends StatefulWidget {
  final PassageModel passage;
  final int wpm;
  const FlashcardsScreen({super.key, required this.passage, required this.wpm});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  int _index = 0;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    await StorageService.recordSprintCompletion(
      wordsRead: widget.passage.wordCount,
      sessionWpm: widget.wpm,
    );
    // Today's sprint is done, so skip today's reminder.
    await NotificationService.instance.onSprintCompleted();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.passage.flashcards;
    final isLast = _index == cards.length - 1;

    return Scaffold(
      appBar: AppBar(title: Text('Flashcard ${_index + 1} of ${cards.length}')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: cards.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final card = cards[i];
                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: i == _index ? 8 : 28,
                    ),
                    child: _FlashcardTile(card: card, index: i),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                cards.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.primaryText
                        : AppColors.lineStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  icon: Icon(isLast
                      ? Icons.flag_circle_rounded
                      : Icons.arrow_forward_rounded),
                  label: Text(isLast ? 'Finish Sprint' : 'Swipe to continue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isLast ? AppColors.success : AppColors.primary,
                  ),
                  onPressed: isLast
                      ? (_saving ? null : _finish)
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashcardTile extends StatelessWidget {
  final FlashcardModel card;
  final int index;
  const _FlashcardTile({required this.card, required this.index});

  static const _accents = [
    AppColors.primary,
    AppColors.success,
    AppColors.warning,
    AppColors.danger,
    AppColors.primaryText,
  ];

  @override
  Widget build(BuildContext context) {
    final accent = _accents[index % _accents.length];
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyle.radiusLg),
        border: Border.all(color: AppColors.tint, width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: Icons.auto_awesome_rounded, color: accent, size: 44),
          const SizedBox(height: 18),
          Text(
            card.title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                card.fact,
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.55,
                  color: AppColors.textBody,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
