// ============================================================================
// ENGLISH & READING COMPREHENSION — START SCREEN
// "Start New Set" (fixed 10 questions = 2 original ~450-500 word passages,
// 5 questions each): main idea, inference, vocabulary-in-context, tone, and
// supported/unsupported-statement questions, rotated per passage. Handles
// the no-key, loading, and error states; never crashes on a failed API
// call. Loading state shows live progress since generation happens
// passage-by-passage (see GroqService.generateEnglishQuestions). Uses the
// generic QuizTakingScreen (section: english), which renders each
// question's shared passage text above it.
// ============================================================================

import 'package:flutter/material.dart';
import '../main.dart' show AppColors, AppStyle, IconBadge;
import '../models/quiz_models.dart';
import '../services/api_key_service.dart';
import '../services/grok_service.dart';
import '../services/quiz_storage_service.dart';
import 'settings_screen.dart';
import 'quiz_taking_screen.dart';

enum _Status { checking, noKey, idle, loading, error }

class EnglishScreen extends StatefulWidget {
  const EnglishScreen({super.key});

  @override
  State<EnglishScreen> createState() => _EnglishScreenState();
}

class _EnglishScreenState extends State<EnglishScreen> {
  _Status _status = _Status.checking;
  String? _error;
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
      final questions = await GroqService.generateEnglishQuestions(
        apiKey: key,
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
          QuizSection.english, questions);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizTakingScreen(
            questions: questions,
            section: QuizSection.english,
            sectionLabel: 'English & Reading Comprehension',
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
      appBar: AppBar(title: const Text('English & Reading Comprehension')),
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
          child: CircularProgressIndicator(color: AppColors.indigo400),
        );

      case _Status.noKey:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.key_off_rounded,
                color: AppColors.slate600, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Add your Groq API key in Settings before starting an English & Reading Comprehension practice set.',
              style: TextStyle(
                  color: AppColors.slate300, fontSize: 15, height: 1.4),
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
              const CircularProgressIndicator(color: AppColors.indigo400),
              const SizedBox(height: 16),
              Text(
                _progressGenerated == 0
                    ? 'Generating $_progressTotal fresh questions…'
                    : 'Generated $_progressGenerated of $_progressTotal…',
                style: const TextStyle(color: AppColors.slate400),
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
                color: AppColors.rose400, size: 48),
            const SizedBox(height: 16),
            Text(
              "Couldn't generate questions — ${_error ?? 'unknown error'}",
              style: const TextStyle(
                  color: AppColors.slate300, fontSize: 15, height: 1.4),
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
                icon: Icons.menu_book_rounded,
                color: AppColors.indigo400,
                size: 64,
              ),
            ),
            const SizedBox(height: AppStyle.sectionGap),
            const Text(
              '10 freshly generated reading-comprehension questions across 2 original passages — main idea, inference, vocabulary, tone, and supported/unsupported statements.',
              style: TextStyle(
                  color: AppColors.slate300, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 58,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Start New Set'),
                onPressed: _start,
              ),
            ),
          ],
        );
    }
  }
}
