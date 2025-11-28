// lib/ai_analysis/ai_analysis_prefs.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_analysis_models.dart';

class AiAnalysisPrefs {
  AiAnalysisPrefs._();
  static const _keyTone = 'ai_analysis_tone';

  // 保存
  static Future<void> setTone(AnalysisTone tone) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyTone, tone.id); // ← id は "gentle" など
  }

  // 読み込み
  static Future<AnalysisTone> getTone() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_keyTone);

    if (s == null) {
      return AnalysisTone.neutral; // デフォルト
    }

    return AnalysisToneExt.fromId(s);
  }
}