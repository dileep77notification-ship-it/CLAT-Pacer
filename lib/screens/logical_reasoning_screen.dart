// ============================================================================
// LOGICAL REASONING — START SCREEN
// "Start New Set" (fixed 10 questions): short argument + assumption /
// inference / strengthen / weaken / conclusion, rotated across the batch.
// Handles the no-key, loading, and error states; never crashes on a failed
// API call. Loading state shows live progress since generation happens in
// batches (see SarvamService). Uses the generic QuizTakingScreen
// (section: logical_reasoning) rather than a section-specific quiz screen.
// ============================================================================

import 'package:flutter/material.dart';
import '../main.dart' show AppColors, AppStyle, IconBadge;
import '../models/quiz_models.dart';
import '../services/api_key_service.dart';
import '../services/sarvam_service.dart';
import '../services/quiz_storage_service.dart';
import 'settings_screen.dart';
import 'quiz_taking_screen.dart';

enum _Status { checking, noKey, idle, loading, error }

class LogicalReasoningScreen extends StatefulWidget {
  const LogicalReasoningScreen({super.key});

  @override
  State<LogicalReasoningScreen> createState() => _LogicalReasoningScreenState();
}

class _LogicalReasoningScreenState extends State<LogicalReasoningScreen> {
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
      final questions = await SarvamService.generateLogicalReasoningQuestions(
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
          QuizSection.logicalReasoning, questions);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizTakingScreen(
            questions: questions,
            section: QuizSection.logicalReasoning,
            sectionLabel: 'Logical Reasoning',
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
      appBar: AppBar(title: const Text('Logical Reasoning Practice')),
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
              'Add your Sarvam API key in Settings before starting a Logical Reasoning Practice.',
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
                icon: Icons.psychology_rounded,
                color: AppColors.rose400,
                size: 64,
              ),
            ),
            const SizedBox(height: AppStyle.sectionGap),
            const Text(
              '10 freshly generated argument-based questions — assumption, inference, strengthen, weaken, and conclusion — in the CLAT pattern.',
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
