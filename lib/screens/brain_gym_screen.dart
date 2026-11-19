// ============================================================================
// BRAIN GYM SCREEN
// Closes the loop that TopicPerformanceService has been quietly building
// since the per-section practice screens and the Mock Test both log a
// TopicRecord per answered question: this screen is the first (and so far
// only) consumer of TopicPerformanceService.weakestTopics(). It lists the
// student's weakest (section, topic) pairs, worst first, and lets them
// launch a short 5-question set focused entirely on one of them via each
// generator's `focusTopic` parameter (see sarvam_service.dart).
//
// Needs at least `_kMinAttempts` logged answers for a topic before it will
// surface it (same floor TopicPerformanceService.weakestTopics() defaults
// to) — otherwise a single unlucky guess would look like a "weak topic".
// ============================================================================

import 'package:flutter/material.dart';
import '../main.dart' show AppColors, AppStyle, IconBadge, SectionHeader;
import '../models/quiz_models.dart';
import '../models/topic_performance_models.dart';
import '../services/api_key_service.dart';
import '../services/sarvam_service.dart';
import '../services/quiz_storage_service.dart';
import '../services/rss_service.dart';
import '../services/topic_performance_service.dart';
import 'settings_screen.dart';
import 'quiz_taking_screen.dart';

const int _kMinAttempts = 3;
const int _kDrillSize = 5;

/// Display label for each QuizSection.* id — kept here rather than added to
/// quiz_models.dart since it's a UI concern specific to this screen (other
/// screens already know their own section's label directly).
const Map<String, String> _kSectionLabels = {
  QuizSection.legalReasoning: 'Legal Reasoning',
  QuizSection.gkCurrentAffairs: 'GK / Current Affairs',
  QuizSection.logicalReasoning: 'Logical Reasoning',
  QuizSection.quant: 'Quantitative Techniques',
  QuizSection.english: 'English & RC',
};

const Map<String, IconData> _kSectionIcons = {
  QuizSection.legalReasoning: Icons.gavel_rounded,
  QuizSection.gkCurrentAffairs: Icons.public_rounded,
  QuizSection.logicalReasoning: Icons.psychology_rounded,
  QuizSection.quant: Icons.calculate_rounded,
  QuizSection.english: Icons.menu_book_rounded,
};

/// "speed_distance_time" -> "Speed Distance Time". Topics are free-text
/// slugs from the model (see quiz_models.dart's QuizQuestion.topic doc),
/// lowercased with underscores — this just makes them readable.
String _prettyTopic(String topic) => topic
    .split('_')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

enum _LoadState { loading, ready, empty, error }

enum _DrillState { idle, noKey, generating, error }

class BrainGymScreen extends StatefulWidget {
  const BrainGymScreen({super.key});

  @override
  State<BrainGymScreen> createState() => _BrainGymScreenState();
}

class _BrainGymScreenState extends State<BrainGymScreen> {
  _LoadState _loadState = _LoadState.loading;
  List<TopicStats> _weakest = [];
  String? _loadError;

  _DrillState _drillState = _DrillState.idle;
  TopicStats? _drilling;
  int _progressGenerated = 0;
  int _progressTotal = _kDrillSize;
  String? _drillError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadState = _LoadState.loading);
    try {
      final stats = await TopicPerformanceService.weakestTopics(
        minAttempts: _kMinAttempts,
      );
      if (!mounted) return;
      setState(() {
        _weakest = stats;
        _loadState = stats.isEmpty ? _LoadState.empty : _LoadState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadState = _LoadState.error;
      });
    }
  }

  Future<void> _startDrill(TopicStats stat) async {
    final hasKey = await ApiKeyService.hasKey();
    if (!mounted) return;
    if (!hasKey) {
      setState(() {
        _drilling = stat;
        _drillState = _DrillState.noKey;
      });
      return;
    }

    setState(() {
      _drilling = stat;
      _drillState = _DrillState.generating;
      _progressGenerated = 0;
      _progressTotal = _kDrillSize;
    });

    try {
      final key = await ApiKeyService.getKey();
      if (key == null || key.isEmpty) {
        if (!mounted) return;
        setState(() => _drillState = _DrillState.noKey);
        return;
      }

      void onProgress(int generated, int total) {
        if (!mounted) return;
        setState(() {
          _progressGenerated = generated;
          _progressTotal = total;
        });
      }

      final questions = await _generateFor(
        section: stat.section,
        topic: stat.topic,
        apiKey: key,
        onProgress: onProgress,
      );

      await QuizStorageService.saveInProgressQuestions(stat.section, questions);
      if (!mounted) return;

      final sectionLabel = _kSectionLabels[stat.section] ?? stat.section;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizTakingScreen(
            questions: questions,
            section: stat.section,
            sectionLabel: '$sectionLabel — ${_prettyTopic(stat.topic)}',
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        _drillState = _DrillState.idle;
        _drilling = null;
      });
      _load(); // refresh — this attempt may have moved the rankings
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _drillState = _DrillState.error;
        _drillError = e.toString();
      });
    }
  }

  Future<List<QuizQuestion>> _generateFor({
    required String section,
    required String topic,
    required String apiKey,
    required void Function(int generated, int total) onProgress,
  }) {
    switch (section) {
      case QuizSection.legalReasoning:
        return SarvamService.generateQuestions(
          apiKey: apiKey,
          count: _kDrillSize,
          focusTopic: topic,
          onProgress: onProgress,
        );
      case QuizSection.logicalReasoning:
        return SarvamService.generateLogicalReasoningQuestions(
          apiKey: apiKey,
          count: _kDrillSize,
          focusTopic: topic,
          onProgress: onProgress,
        );
      case QuizSection.quant:
        return SarvamService.generateQuantQuestions(
          apiKey: apiKey,
          count: _kDrillSize,
          focusTopic: topic,
          onProgress: onProgress,
        );
      case QuizSection.english:
        return SarvamService.generateEnglishQuestions(
          apiKey: apiKey,
          count: _kDrillSize,
          focusTopic: topic,
          onProgress: onProgress,
        );
      case QuizSection.gkCurrentAffairs:
        return RssService.fetchAllHeadlines().then(
          (headlines) => SarvamService.generateGkQuestions(
            apiKey: apiKey,
            headlines: headlines,
            count: _kDrillSize,
            focusTopic: topic,
            onProgress: onProgress,
          ),
        );
      default:
        throw StateError('Unknown Brain Gym section: $section');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brain Gym')),
      body: SafeArea(
        child: _drillState != _DrillState.idle
            ? _buildDrillOverlay()
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_loadState) {
      case _LoadState.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryText),
        );

      case _LoadState.error:
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.dangerText, size: 48),
              const SizedBox(height: 16),
              Text(
                "Couldn't load your weak topics — ${_loadError ?? 'unknown error'}",
                style: const TextStyle(
                    color: AppColors.textBody, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(onPressed: _load, child: const Text('Retry')),
              ),
            ],
          ),
        );

      case _LoadState.empty:
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 56),
              Center(
                child: IconBadge(
                  icon: Icons.fitness_center_rounded,
                  color: AppColors.primaryText,
                  size: 64,
                ),
              ),
              const SizedBox(height: AppStyle.sectionGap),
              const Text(
                'Not enough data yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete a few more practice sets or a mock test — once a '
                'topic has at least $_kMinAttempts answered questions, '
                "Brain Gym will show you where you're weakest.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 14, height: 1.5),
              ),
            ],
          ),
        );

      case _LoadState.ready:
        return RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primaryText,
          backgroundColor: AppColors.surface,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SectionHeader(
                title: 'Your weakest topics',
                subtitle:
                    'Ranked worst accuracy first. Tap one to drill 5 fresh questions on just that topic.',
              ),
              ..._weakest.map(_buildTopicTile),
            ],
          ),
        );
    }
  }

  Widget _buildTopicTile(TopicStats stat) {
    final sectionLabel = _kSectionLabels[stat.section] ?? stat.section;
    final icon = _kSectionIcons[stat.section] ?? Icons.quiz_rounded;
    final accuracyPct = (stat.accuracy * 100).round();
    final accuracyColor = stat.accuracy < 0.4
        ? AppColors.dangerText
        : (stat.accuracy < 0.7 ? AppColors.warningText : AppColors.successText);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppStyle.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppStyle.radiusLg),
          onTap: () => _startDrill(stat),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppStyle.radiusLg),
              border: Border.all(color: AppColors.tint),
            ),
            child: Row(
              children: [
                IconBadge(icon: icon, color: AppColors.primaryText),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _prettyTopic(stat.topic),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$sectionLabel · ${stat.attempts} attempts',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$accuracyPct%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: accuracyColor,
                      ),
                    ),
                    const Text(
                      'accuracy',
                      style:
                          TextStyle(color: AppColors.textFaint, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrillOverlay() {
    final stat = _drilling;
    final topicLabel = stat == null ? '' : _prettyTopic(stat.topic);

    switch (_drillState) {
      case _DrillState.noKey:
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.key_off_rounded,
                  color: AppColors.textFaint, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Add your Sarvam API key in Settings before drilling a weak topic.',
                style: TextStyle(
                    color: AppColors.textBody, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Go to Settings'),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                    if (!mounted) return;
                    setState(() {
                      _drillState = _DrillState.idle;
                      _drilling = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _drillState = _DrillState.idle;
                    _drilling = null;
                  }),
                  child: const Text('Back'),
                ),
              ),
            ],
          ),
        );

      case _DrillState.generating:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryText),
              const SizedBox(height: 16),
              Text(
                'Drilling "$topicLabel"…',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _progressGenerated == 0
                    ? 'Generating $_progressTotal fresh questions…'
                    : 'Generated $_progressGenerated of $_progressTotal…',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        );

      case _DrillState.error:
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.dangerText, size: 48),
              const SizedBox(height: 16),
              Text(
                "Couldn't generate the drill — ${_drillError ?? 'unknown error'}",
                style: const TextStyle(
                    color: AppColors.textBody, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => stat == null ? null : _startDrill(stat),
                  child: const Text('Retry'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _drillState = _DrillState.idle;
                    _drilling = null;
                  }),
                  child: const Text('Back'),
                ),
              ),
            ],
          ),
        );

      case _DrillState.idle:
        return const SizedBox.shrink(); // unreachable — guarded by caller
    }
  }
}
