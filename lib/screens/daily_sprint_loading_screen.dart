// ============================================================================
// DAILY SPRINT — LOADING SCREEN
// Pushed when "Start Today's Sprint" is tapped. Checks for a Groq key,
// fetches today's headlines + generates 3-4 passages (DailyArticleService),
// then replaces itself with DailySprintListScreen. Same no-key/loading/error
// pattern as LegalReasoningScreen, for a consistent app-wide UX.
// ============================================================================

import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../services/api_key_service.dart';
import '../services/daily_article_service.dart';
import 'daily_sprint_list_screen.dart';
import 'settings_screen.dart';

enum _Status { checking, noKey, loading, error }

class DailySprintLoadingScreen extends StatefulWidget {
  const DailySprintLoadingScreen({super.key});

  @override
  State<DailySprintLoadingScreen> createState() =>
      _DailySprintLoadingScreenState();
}

class _DailySprintLoadingScreenState extends State<DailySprintLoadingScreen> {
  _Status _status = _Status.checking;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _status = _Status.loading);
    final hasKey = await ApiKeyService.hasKey();
    if (!mounted) return;
    if (!hasKey) {
      setState(() => _status = _Status.noKey);
      return;
    }

    try {
      final key = await ApiKeyService.getKey();
      final passages =
          await DailyArticleService.generateTodaysSprints(apiKey: key!);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DailySprintListScreen(passages: passages),
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
      appBar: AppBar(title: const Text("Today's Sprint")),
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
      case _Status.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.indigo400),
              SizedBox(height: 16),
              Text(
                "Picking today's most relevant stories and generating your sprint — this takes under a minute per story…",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate400),
              ),
            ],
          ),
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
              'Add your Groq API key in Settings before starting a Daily Sprint.',
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
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                  _run();
                },
              ),
            ),
          ],
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
              "Couldn't prepare today's sprint — ${_error ?? 'unknown error'}",
              style: const TextStyle(
                  color: AppColors.slate300, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(onPressed: _run, child: const Text('Retry')),
            ),
          ],
        );
    }
  }
}
