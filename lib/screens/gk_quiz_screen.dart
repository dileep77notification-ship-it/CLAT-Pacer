// ============================================================================
// GK / CURRENT AFFAIRS — START SCREEN
// Mirrors legal_reasoning_screen.dart's no-key/loading/error pattern.
// "Start New Quiz" fetches today's headlines (RssService), then generates
// 10 headline-grounded + static-GK MCQs via SarvamService.generateGkQuestions,
// batched the same way as Legal Reasoning. Feeds into the generic
// QuizTakingScreen (section: gk_current_affairs) rather than a GK-specific
// quiz screen.
// ============================================================================

import 'package:flutter/material.dart';
import '../main.dart' show AppColors, AppStyle, IconBadge;
import '../models/quiz_models.dart';
import '../services/api_key_service.dart';
import '../services/sarvam_service.dart';
import '../services/quiz_storage_service.dart';
import '../services/rss_service.dart';
import 'settings_screen.dart';
import 'quiz_taking_screen.dart';

enum _Status { checking, noKey, idle, loading, error }

class GkQuizScreen extends StatefulWidget {
  const GkQuizScreen({super.key});

  @override
  State<GkQuizScreen> createState() => _GkQuizScreenState();
}

class _GkQuizScreenState extends State<GkQuizScreen> {
  _Status _status = _Status.checking;
  String? _error;
  String _loadingLabel = 'Fetching today\'s headlines…';
  int _progressGenerated = 0;
  int _progressTotal = 10;

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  Future<void> _checkKey() async {
    final hasKey = await ApiKeyService.hasKey();
    if (!mounted) return;
    setState(() => _status = hasKey ? _Status.idle : _Status.noKey);
  }

  Future<void> _start() async {
    setState(() {
      _status = _Status.loading;
      _loadingLabel = 'Fetching today\'s headlines…';
      _progressGenerated = 0;
      _progressTotal = 10;
    });
    try {
      final key = await ApiKeyService.getKey();
      if (key == null || key.isEmpty) {
        if (!mounted) return;
        setState(() => _status = _Status.noKey);
        return;
      }

      final headlines = await RssService.fetchAllHeadlines();

      if (!mounted) return;
      setState(() => _loadingLabel = 'Generating 10 fresh questions…');

      final questions = await SarvamService.generateGkQuestions(
        apiKey: key,
        headlines: headlines,
        count: 10,
        onProgress: (generated, total) {
          if (!mounted) return;
          setState(() {
            _progressGenerated = generated;
            _progressTotal = total;
          });
        },
      );

      await QuizStorageService.saveInProgressQuestions(
          QuizSection.gkCurrentAffairs, questions);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizTakingScreen(
            questions: questions,
            section: QuizSection.gkCurrentAffairs,
            sectionLabel: 'GK / Current Affairs',
          ),
        ),
      );
      if (!mounted) return;
      setState(() => _status = _Status.idle);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GK / Current Affairs Quiz')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_status) {
      case _Status.checking:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryText),
        );

      case _Status.noKey:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.key_off_rounded,
                color: AppColors.textFaint, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Add your Sarvam API key in Settings before starting a GK / Current Affairs quiz.',
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
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  );
                  _checkKey();
                },
              ),
            ),
          ],
        );

      case _Status.loading:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryText),
              const SizedBox(height: 16),
              Text(
                _progressGenerated == 0
                    ? _loadingLabel
                    : 'Generated $_progressGenerated of $_progressTotal…',
                style: const TextStyle(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case _Status.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.error_outline_rounded,
                color: AppColors.dangerText, size: 48),
            const SizedBox(height: 16),
            Text(
              "Couldn't generate questions — ${_error ?? 'unknown error'}",
              style: const TextStyle(
                  color: AppColors.textBody, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(onPressed: _start, child: const Text('Retry')),
            ),
          ],
        );

      case _Status.idle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Center(
              child: IconBadge(
                icon: Icons.public_rounded,
                color: AppColors.warning,
                size: 64,
              ),
            ),
            const SizedBox(height: AppStyle.sectionGap),
            const Text(
              '10 fresh multiple-choice questions mixing today\'s current affairs with static GK, in the CLAT pattern.',
              style: TextStyle(
                  color: AppColors.textBody, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 58,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Start New Quiz'),
                onPressed: _start,
              ),
            ),
          ],
        );
    }
  }
}
