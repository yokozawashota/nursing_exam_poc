// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

/// アプリ全体の設定を保存/取得するサービス。
/// 互換性のため、旧メソッド名（load*/save* 系・getMultipleProbability など）も残しています。
class SettingsService {
  // ===== Keys =====
  static const _kApiKey   = 'api_key';
  static const _kModel    = 'openai_model';

  // 4択/5択の制御
  // 'auto' | 'force4' | 'force5'
  static const _kChoiceMode = 'choice_mode';
  // 5択を選ぶ確率（auto のときに参照）: 0..100
  static const _kFiveChoiceProb = 'five_choice_probability';

  // 誤答選択（select_incorrect）にする確率: 0..100
  static const _kIncorrectKindProb = 'incorrect_kind_probability';

  // 複数選択（multiple）にする確率: 0..100
  static const _kMultipleKindProb = 'multiple_kind_probability';
  // （将来用）複数選択時に正答を2つにする確率: 0..100
  // ※現状は multiple = 2択固定の方針ですが、互換のため保持
  static const _kMultipleCorrectProb = 'multiple_correct_probability';

  // ===== Defaults =====
  static const _defaultModel = 'gpt-5.1-mini';
  static const _defaultChoiceMode = 'auto';   // 'auto' | 'force4' | 'force5'
  static const _defaultFiveProb = 30;         // auto時 5択化の確率
  static const _defaultIncorrectProb = 20;    // 誤答化の確率
  static const _defaultMultipleKindProb = 0;  // 複数選択化の確率（初期は0）
  static const _defaultMultipleCorrectProb = 100; // 複数時=2正答の確率（将来用）

  // ===== API Key =====
  static Future<String?> getApiKey() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kApiKey);
  }

  static Future<void> setApiKey(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kApiKey, value);
  }

  // 互換（旧名）
  static Future<String?> loadApiKey() => getApiKey();
  static Future<void> saveApiKey(String value) => setApiKey(value);

  // ===== Model =====
  static Future<String> getModel() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kModel) ?? _defaultModel;
  }

  static Future<void> setModel(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kModel, value);
  }

  // 互換（旧名）
  static Future<String> loadModel() => getModel();
  static Future<void> saveModel(String value) => setModel(value);

  // ===== Choice mode ('auto' | 'force4' | 'force5') =====
  static Future<String> getChoiceMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kChoiceMode) ?? _defaultChoiceMode;
    // 常に String を返す設計（呼び出し側が null を想定しないため）
  }

  static Future<void> setChoiceMode(String mode) async {
    final normalized = (mode == 'force4' || mode == 'force5') ? mode : 'auto';
    final p = await SharedPreferences.getInstance();
    await p.setString(_kChoiceMode, normalized);
  }

  // ===== 5択確率（auto時） =====
  static Future<int> getFiveChoiceProbability() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kFiveChoiceProb) ?? _defaultFiveProb;
  }

  static Future<void> setFiveChoiceProbability(int prob) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kFiveChoiceProb, _clampPercent(prob));
  }

  // ===== 誤答問題化の確率 =====
  static Future<int> getIncorrectKindProbability() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kIncorrectKindProb) ?? _defaultIncorrectProb;
  }

  static Future<void> setIncorrectKindProbability(int prob) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kIncorrectKindProb, _clampPercent(prob));
  }

  // ===== 複数選択（multiple）にする確率 =====
  static Future<int> getMultipleKindProbability() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kMultipleKindProb) ?? _defaultMultipleKindProb;
  }

  static Future<void> setMultipleKindProbability(int prob) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kMultipleKindProb, _clampPercent(prob));
  }

  // ===== 複数選択時に「正答2つ」にする確率（将来用・現状は100%想定） =====
  static Future<int> getMultipleCorrectProbability() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kMultipleCorrectProb) ?? _defaultMultipleCorrectProb;
  }

  static Future<void> setMultipleCorrectProbability(int prob) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kMultipleCorrectProb, _clampPercent(prob));
  }

  // ===== 互換エイリアス（古い呼び出しに対応） =====

  /// 旧: getMultipleProbability() -> 複数選択化の確率
  static Future<int?> getMultipleProbability() async {
    // 旧呼び出しが null 許容だったため、互換性を保って int? で返す
    return getMultipleKindProbability();
  }

  /// 旧: getMultipleTwoCorrectsProbability() -> 複数時2正答の確率
  static Future<int?> getMultipleTwoCorrectsProbability() async {
    return getMultipleCorrectProbability();
  }

  // ===== Helpers =====
  static int _clampPercent(int v) {
    if (v < 0) return 0;
    if (v > 100) return 100;
    return v;
  }
}