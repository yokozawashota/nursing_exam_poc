// lib/services/version_service.dart
import 'package:package_info_plus/package_info_plus.dart';

/// アプリのバージョンを提供するサービス。
class VersionService {
  /// バージョンを返す（例: "1.0.0"）
  /// ※ 通常は buildNumber は付けません。("1.0.0 (1)" などの (1) を避けるため)
  static Future<String> getAppVersion({bool includeBuild = false}) async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version; // 例: "1.0.0"
    if (includeBuild) {
      final build = info.buildNumber; // 例: "1"
      return '$version+$build';
    }
    return version;
  }

  /// フッター表記に使う整形済み文字列を返す。
  /// 例: "© 2025 NurAI  Ver 1.0.0"
  static Future<String> footerText() async {
    final v = await getAppVersion();
    // 全角スペース混在を避け、半角2つで視認性を確保
    return '© 2025 NurAI  Ver $v';
  }
}