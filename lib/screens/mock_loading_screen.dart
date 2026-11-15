// ============================================================================
// FULL MOCK TEST — START / GENERATION SCREEN
// Generates all questions across all 5 sections BEFORE the exam timer
// starts (see mock_generator_service.dart) — the exam clock times the
// student, not Groq. This step alone can take several minutes (5 sections,
// paced ~10s apart plus multi-batch sections — longer still for the full
// config), so progress is shown with both the current section and the
// running overall count.
//
// Idle screen lets the user pick Half (kHalfMockConfig, ~60Q/60min) or Full
// (kFullMockConfig, ~120Q/120min) before starting — the choice only matters
// here; MockGeneratorService/MockTakingScreen/MockResultsScreen downstream
// just take whichever MockConfig they're handed.
// ============================================================================

import 'package:flutter/material.dart';
import '../main.dart' show AppColors, AppStyle, IconBadge;
import '../services/api_key_service.dart';
import '../services/mock_generator_service.dart';
import 'settings_screen.dart';
import 'mock_taking_screen.dart';

enum _Status { checking, noKey, idle, generating, error }

class MockLoadingScreen extends StatefulWidget {
  const MockLoadingScreen({super.key});

  @override
  State<MockLoadingScreen> createState() => _MockLoadingScreenState();
}

class _MockLoadingScreenState extends State<MockLoadingScreen> {
  _Status _status = _Status.checking;
  String? _error;
  MockGenerationProgress? _progress;

  MockConfig _config = kHalfMockConfig;

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
      _status = _Status.generating;
      _progress = null;
    });
    try {
      final key = await ApiKeyService.getKey();
      if (key == null || key.isEmpty) {
        if (!mounted) return;
        setState(() => _status = _Status.noKey);
        return;
      }
      final questions = await MockGeneratorService.generate(
        apiKey: key,
        config: _config,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MockTakingScreen(
            questions: questions,
            config: _config,
          ),
        ),
      );
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
      appBar: AppBar(title: const Text('Full Mock Test')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _lengthOption({
    required MockConfig config,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _config.name == config.name;
    return InkWell(
      borderRadius: BorderRadius.circular(AppStyle.radiusLg),
      onTap: () => setState(() => _config = config),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppStyle.radiusLg),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.tint,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.primaryText : AppColors.textPrimary,
                )),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12.5)),
          ],
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
              'Add your Groq API key in Settings before starting a mock test.',
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

      case _Status.generating:
        final p = _progress;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryText),
              const SizedBox(height: 20),
              Text(
                p == null
                    ? 'Starting generation…'
                    : 'Section ${p.sectionIndex + 1} of ${p.totalSections}: ${p.sectionLabel}',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                p == null
                    ? 'This can take a few minutes — Groq\'s free tier paces requests.'
                    : 'Overall: ${p.overallGenerated} of ${p.overallTotal} questions',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (p != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: 220,
                  child: LinearProgressIndicator(
                    value: p.overallGenerated / p.overallTotal,
                    minHeight: 6,
                    backgroundColor: AppColors.tint,
                    color: AppColors.primary,
                  ),
                ),
              ],
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
              "Couldn't generate the mock — ${_error ?? 'unknown error'}",
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
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Center(
                child: IconBadge(
                  icon: Icons.assignment_rounded,
                  color: AppColors.primaryText,
                  size: 64,
                ),
              ),
              const SizedBox(height: AppStyle.sectionGap),
              Row(
                children: [
                  Expanded(
                    child: _lengthOption(
                      config: kHalfMockConfig,
                      title: 'Half',
                      subtitle: '60 Qs · 60 min',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _lengthOption(
                      config: kFullMockConfig,
                      title: 'Full',
                      subtitle: '120 Qs · 120 min',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${_config.name} — ${_config.totalQuestions} questions, ${_config.durationMinutes} minutes',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                '+1 for each correct answer, -0.25 for each wrong answer, 0 for unattempted — the standard CLAT scheme.',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              ..._config.sections.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryText,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(s.label,
                              style: const TextStyle(
                                  color: AppColors.textSoft, fontSize: 14)),
                        ),
                        Text('${s.count} Qs',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 13)),
                      ],
                    ),
                  )),
              const SizedBox(height: 10),
              const Text(
                'All questions generate up front, before the timer starts — this can take several minutes on Groq\'s free tier.',
                style: TextStyle(
                    color: AppColors.textFaint, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Start Mock Test'),
                  onPressed: _start,
                ),
              ),
            ],
          ),
        );
    }
  }
}
