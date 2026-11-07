// ============================================================================
// API KEY SERVICE
// Stores the Grok (xAI) API key using flutter_secure_storage, which on
// Android backs onto EncryptedSharedPreferences / the Android Keystore —
// the mobile equivalent of Electron's safeStorage. The key is never written
// to shared_preferences, SQLite, or any plaintext file.
// ============================================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiKeyService {
  static const _kGrokApiKey = 'grok_api_key';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String?> getKey() => _storage.read(key: _kGrokApiKey);

  static Future<void> saveKey(String value) =>
      _storage.write(key: _kGrokApiKey, value: value);

  static Future<void> clearKey() => _storage.delete(key: _kGrokApiKey);

  static Future<bool> hasKey() async {
    final value = await getKey();
    return value != null && value.trim().isNotEmpty;
  }
}
