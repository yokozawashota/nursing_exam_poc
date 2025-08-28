// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyApi = 'OPENAI_API_KEY';
  static const String _keyModel = 'OPENAI_MODEL';

  // ===== 推奨API（現行UIで使用） =====
  static Future<String?> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApi);
  }

  static Future<void> saveApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApi, value);
  }

  static Future<String?> loadModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyModel);
  }

  static Future<void> saveModel(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyModel, value);
  }

  // ===== 互換API（過去のコード対応） =====
  static Future<String?> getApiKey() => loadApiKey();
  static Future<void> setApiKey(String value) => saveApiKey(value);

  static Future<String?> getModel() => loadModel();
  static Future<void> setModel(String value) => saveModel(value);

  // ===== 全設定クリア =====
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyApi);
    await prefs.remove(_keyModel);
  }
}