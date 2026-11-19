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

void main() {
  runApp(const ClatPacerApp());
}

// ============================================================================
// SECTION 1 — THEME
// Tailwind-inspired dark palette: slate background, indigo primary,
// emerald accent for success/correct states.
// ============================================================================

class AppColors {
  // Slate scale (backgrounds / surfaces / text)
  static const slate950 = Color(0xFF0B1120);
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate100 = Color(0xFFF1F5F9);

  // Indigo scale (primary actions / accents)
  static const indigo500 = Color(0xFF6366F1);
  static const indigo400 = Color(0xFF818CF8);
  static const indigo600 = Color(0xFF4F46E5);

  // Emerald scale (success / correct / streak flame)
  static const emerald500 = Color(0xFF10B981);
  static const emerald400 = Color(0xFF34D399);

  // Rose (incorrect / destructive / strike)
  static const rose500 = Color(0xFFF43F5E);
  static const rose400 = Color(0xFFFB7185);

  // Slightly lighter slate for unselected option text (kept distinct from
  // slate100 so selected vs. unselected options read differently at a glance)
  static const slate200 = Color(0xFFE2E8F0);

  // Amber (timer warning)
  static const amber400 = Color(0xFFFBBF24);
}

// ============================================================================
// AIRBNB-STYLE LAYOUT TOKENS
// Kept the dark slate palette above, but borrowed Airbnb's layout language
// on top of it: larger corner radii, more generous whitespace, icon-badge
// tiles instead of plain outlined buttons. Every screen in the app should
// reach for these constants/widgets instead of hand-rolling its own radius
// or padding number, so a future look change is one place, not twenty.
// ============================================================================

class AppStyle {
  static const double radiusLg = 22.0; // cards, hero banners
  static const double radiusMd = 16.0; // buttons, tiles, chips
  static const double radiusSm = 12.0; // small pills, badges
  static const double pagePadding = 20.0;
  static const double sectionGap = 28.0;
}

/// Bold title + optional muted subtitle, used to open every major section
/// of a screen — the "Homes / Experiences" style heading Airbnb uses above
/// each horizontally-scrolling or gridded group.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.only(bottom: 14),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.slate100,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                  color: AppColors.slate400, fontSize: 13.5, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// A rounded icon in a soft tinted circle-square — Airbnb's category-tile
/// icon treatment. [size] is the outer box; the icon itself is ~55% of it.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

/// A tappable, icon-badged card — Airbnb's "category" tile. Used on Home
/// for the practice-section grid, and reusable anywhere else a grid of
/// equally-weighted choices is needed.
class PracticeTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const PracticeTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppStyle.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppStyle.radiusLg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.slate900,
            borderRadius: BorderRadius.circular(AppStyle.radiusLg),
            border: Border.all(color: AppColors.slate800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon: icon, color: color),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate100,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.slate400, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.slate950,
    primaryColor: AppColors.indigo500,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.indigo500,
      secondary: AppColors.emerald500,
      surface: AppColors.slate900,
      error: AppColors.rose500,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Roboto',
      bodyColor: AppColors.slate100,
      displayColor: AppColors.slate100,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.slate950,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.slate100),
      titleTextStyle: TextStyle(
        color: AppColors.slate100,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.indigo500,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusMd),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.slate100,
        side: const BorderSide(color: AppColors.slate700),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusMd),
        ),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.slate900,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyle.radiusLg),
        side: const BorderSide(color: AppColors.slate800, width: 1),
      ),
    ),
    dividerColor: AppColors.slate800,
  );
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

class _HomeScreenState extends State<HomeScreen> {
  late Future<DashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = StorageService.loadStats();
  }

  void _refresh() {
    setState(() {
      _statsFuture = StorageService.loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CLAT Daily Sprint'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<DashboardStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.indigo400),
            );
          }
          final stats = snapshot.data!;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  const Text(
                    'Ready for today\'s sprint?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate100,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: AppStyle.sectionGap),
                  Row(
                    children: [
                      Expanded(
                        child: _StreakCard(streak: stats.streak),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.speed_rounded,
                          iconColor: AppColors.indigo400,
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
                    iconColor: AppColors.emerald400,
                    label: 'Sprints Completed',
                    value: stats.sessionsCount.toString(),
                    suffix: '',
                    fullWidth: true,
                  ),
                  const SizedBox(height: AppStyle.sectionGap),

                  // Hero CTA — Airbnb-style full-bleed banner card rather
                  // than a plain button: icon badge, title, subtitle, and
                  // the action together in one tappable surface.
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppStyle.radiusLg),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppStyle.radiusLg),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DailySprintLoadingScreen(),
                          ),
                        );
                        _refresh();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.emerald500.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppStyle.radiusLg),
                          border: Border.all(
                              color: AppColors.emerald500.withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            const IconBadge(
                              icon: Icons.bolt_rounded,
                              color: AppColors.emerald400,
                              size: 52,
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Start Today's Sprint",
                                      style: TextStyle(
                                          color: AppColors.slate100,
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w800)),
                                  SizedBox(height: 4),
                                  Text(
                                    '1 passage · 5 questions · 5 flashcards',
                                    style: TextStyle(
                                        color: AppColors.slate400,
                                        fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.slate400),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Full Mock Test — same banner idiom, indigo-tinted.
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppStyle.radiusLg),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppStyle.radiusLg),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MockLoadingScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.indigo500.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppStyle.radiusLg),
                          border: Border.all(
                              color: AppColors.indigo500.withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            const IconBadge(
                              icon: Icons.assignment_rounded,
                              color: AppColors.indigo400,
                              size: 52,
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Full Mock Test',
                                      style: TextStyle(
                                          color: AppColors.slate100,
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w800)),
                                  SizedBox(height: 4),
                                  Text(
                                    'Half or full length · all 5 sections · negative marking',
                                    style: TextStyle(
                                        color: AppColors.slate400,
                                        fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.slate400),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppStyle.sectionGap),
                  const SectionHeader(
                    title: 'Practice by section',
                    subtitle: 'Fresh, Sarvam-generated questions every time',
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                    children: [
                      PracticeTile(
                        icon: Icons.gavel_rounded,
                        color: AppColors.indigo400,
                        title: 'Legal Reasoning',
                        subtitle: 'Principle + facts',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegalReasoningScreen(),
                          ),
                        ),
                      ),
                      PracticeTile(
                        icon: Icons.public_rounded,
                        color: AppColors.amber400,
                        title: 'GK / Current Affairs',
                        subtitle: 'Headline-grounded',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const GkQuizScreen(),
                          ),
                        ),
                      ),
                      PracticeTile(
                        icon: Icons.psychology_rounded,
                        color: AppColors.rose400,
                        title: 'Logical Reasoning',
                        subtitle: 'Argument-based',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LogicalReasoningScreen(),
                          ),
                        ),
                      ),
                      PracticeTile(
                        icon: Icons.calculate_rounded,
                        color: AppColors.emerald400,
                        title: 'Quantitative Techniques',
                        subtitle: 'Basic-maths data',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const QuantScreen(),
                          ),
                        ),
                      ),
                      PracticeTile(
                        icon: Icons.menu_book_rounded,
                        color: AppColors.indigo400,
                        title: 'English & RC',
                        subtitle: 'Passage-based',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EnglishScreen(),
                          ),
                        ),
                      ),
                      PracticeTile(
                        icon: Icons.fitness_center_rounded,
                        color: AppColors.emerald400,
                        title: 'Brain Gym',
                        subtitle: 'Drill your weak topics',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BrainGymScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                ),
              ),
            ),
          );
        },
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
              color: isActive ? AppColors.amber400 : AppColors.slate600,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              '$streak',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.slate100,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              streak == 1 ? 'day streak' : 'day streak',
              style: const TextStyle(color: AppColors.slate400, fontSize: 13),
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
                      color: AppColors.slate100,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                        color: AppColors.slate400, fontSize: 13),
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
                            color: AppColors.slate100,
                          ),
                        ),
                        TextSpan(
                          text: suffix,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                        color: AppColors.slate400, fontSize: 13),
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
                color: AppColors.emerald400, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Words Conquered',
                    style: TextStyle(color: AppColors.slate400, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: digits
                        .map((d) => Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.slate800,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppColors.slate700, width: 1),
                              ),
                              child: Text(
                                d,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.emerald400,
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
                  color: isWarning ? AppColors.rose400 : AppColors.indigo400),
              const SizedBox(width: 8),
              Text(
                _formatTime(_secondsRemaining),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isWarning ? AppColors.rose400 : AppColors.slate100,
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
                backgroundColor: AppColors.slate800,
                color: isWarning ? AppColors.rose500 : AppColors.indigo500,
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
                          color: AppColors.slate100,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.passage.wordCount} words',
                        style: const TextStyle(
                            color: AppColors.slate600, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.passage.body.trim(),
                        style: const TextStyle(
                          fontSize: 16.5,
                          height: 1.6,
                          color: AppColors.slate300,
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
                      backgroundColor: AppColors.emerald500,
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
              backgroundColor: AppColors.slate800,
              color: AppColors.indigo500,
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
                        color: AppColors.slate100,
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
                                ? AppColors.indigo500.withOpacity(0.15)
                                : AppColors.slate900,
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
                                        ? AppColors.indigo500
                                        : AppColors.slate800,
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
                                              ? AppColors.slate600
                                              : AppColors.slate200,
                                          decoration: isStruck
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                          decorationThickness: 2,
                                          decorationColor: AppColors.rose400,
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
                                            ? AppColors.emerald400
                                            : AppColors.slate600,
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
                      style: TextStyle(color: AppColors.slate600, fontSize: 12),
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
                          side: const BorderSide(color: AppColors.slate700),
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
        color: selected ? AppColors.indigo500 : AppColors.slate800,
        border: Border.all(
          color: struck ? AppColors.rose400 : AppColors.slate700,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.slate400,
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
                      color: AppColors.indigo400,
                      label: 'Reading Speed',
                      value: '$wpm',
                      suffix: ' WPM',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ResultTile(
                      icon: Icons.fact_check_rounded,
                      color: AppColors.emerald400,
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
                  color: AppColors.slate100,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '5 connected facts to lock this passage into memory.',
                style: TextStyle(color: AppColors.slate400, fontSize: 13),
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
                      color: AppColors.slate100,
                    ),
                  ),
                  TextSpan(
                    text: suffix,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(color: AppColors.slate400, fontSize: 13)),
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
                        ? AppColors.indigo400
                        : AppColors.slate700,
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
                        isLast ? AppColors.emerald500 : AppColors.indigo500,
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
    AppColors.indigo500,
    AppColors.emerald500,
    AppColors.amber400,
    AppColors.rose500,
    AppColors.indigo400,
  ];

  @override
  Widget build(BuildContext context) {
    final accent = _accents[index % _accents.length];
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(AppStyle.radiusLg),
        border: Border.all(color: AppColors.slate800, width: 1),
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
              color: AppColors.slate100,
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
                  color: AppColors.slate300,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
