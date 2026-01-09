// lib/features/settings/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyApiKey = 'api_key';
  static const _keyModel = 'model';
  static const _keyChoiceMode = 'choice_mode'; // auto|force4|force5
  static const _keyFiveChoiceProb = 'five_choice_probability';
  static const _keyMultipleProb = 'multiple_kind_probability';
  static const _keyIncorrectProb = 'incorrect_kind_probability';

  // ==========================
  // APIキー / モデル
  // ==========================
  static Future<void> setApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, value);
  }

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey);
  }

  static Future<void> setModel(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyModel, value);
  }

  static Future<String?> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyModel);
  }

  // ==========================
  // 出題設定
  // ==========================
  static Future<void> setChoiceMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyChoiceMode, mode);
  }

  static Future<String?> getChoiceMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyChoiceMode);
  }

  static Future<void> setFiveChoiceProbability(int percent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFiveChoiceProb, percent);
  }

  static Future<int?> getFiveChoiceProbability() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFiveChoiceProb);
  }

  static Future<void> setMultipleKindProbability(int percent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMultipleProb, percent);
  }

  static Future<int?> getMultipleKindProbability() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMultipleProb);
  }

  static Future<void> setIncorrectKindProbability(int percent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyIncorrectProb, percent);
  }

  static Future<int?> getIncorrectKindProbability() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyIncorrectProb);
  }
}