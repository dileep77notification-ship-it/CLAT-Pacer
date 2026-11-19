// ============================================================================
// SETTINGS SCREEN
// One field: Sarvam API key. Masked input, Save / Clear. No "test
// connection" call — validation happens naturally the first time the key
// is used to generate a Legal Reasoning test.
// ============================================================================

import 'package:flutter/material.dart';
import '../main.dart' show AppColors, AppStyle;
import '../services/api_key_service.dart';
import '../widgets/reminder_settings_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _hasKey = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final hasKey = await ApiKeyService.hasKey();
    if (!mounted) return;
    setState(() {
      _hasKey = hasKey;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    await ApiKeyService.saveKey(value);
    _controller.clear();
    if (!mounted) return;
    setState(() {
      _hasKey = true;
      _message = 'Key saved.';
    });
  }

  Future<void> _clear() async {
    await ApiKeyService.clearKey();
    if (!mounted) return;
    setState(() {
      _hasKey = false;
      _message = 'Key cleared.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primaryText))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Sarvam API Key',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _hasKey
                          ? 'A key is stored, encrypted on this device.'
                          : 'No key stored yet — the Legal Reasoning Test needs one.',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      obscureText: true,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Paste your Sarvam API key',
                        hintStyle:
                            const TextStyle(color: AppColors.textFaint),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppStyle.radiusMd),
                          borderSide:
                              const BorderSide(color: AppColors.tint),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _save,
                              child: const Text('Save'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _hasKey ? _clear : null,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppColors.lineStrong),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppStyle.radiusMd),
                                ),
                              ),
                              child: const Text('Clear'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        style: const TextStyle(
                            color: AppColors.successText, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 32),
                    const Text(
                      'Reminders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Get a nudge each day to finish your Daily Sprint and keep your streak.',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    const ReminderSettingsTile(),
                  ],
                ),
              ),
            ),
    );
  }
}
