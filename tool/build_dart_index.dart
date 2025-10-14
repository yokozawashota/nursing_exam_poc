import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// .dart-index/ 以下にフォルダ単位の index.json を作成し、
/// ルートに catalog.json（全フォルダの一覧）も出力する。
///
/// グルーピング方針：lib 配下の「相対フォルダパス」ごと（ファイル直下は lib/ に寄せる）
Future<void> main() async {
  final outDir = Directory('.dart-index');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('lib/ not found.');
    exitCode = 1;
    return;
  }

  // lib 以下の .dart を走査
  final files = libDir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  // フォルダごとにグルーピング（lib/widgets/a.dart -> lib/widgets）
  final Map<String, List<File>> byFolder = {};
  for (final f in files) {
    final rel = _relativeFrom(f.path, base: 'lib');        // 例: widgets/a.dart or main.dart
    final folder = rel.contains(Platform.pathSeparator)
        ? 'lib/${rel.split(Platform.pathSeparator).first}'
        : 'lib'; // 直下ファイルは lib にまとめる
    byFolder.putIfAbsent(folder, () => []).add(f);
  }

  // フォルダ別 index.json を出力
  final generatedAt = DateTime.now().toUtc().toIso8601String() + 'Z';
  final List<Map<String, dynamic>> catalogFolders = [];

  for (final entry in byFolder.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    final folder = entry.key;       // 例: lib/widgets
    final fileList = entry.value;

    final items = <Map<String, dynamic>>[];
    for (final f in fileList..sort((a, b) => a.path.compareTo(b.path))) {
      final relPath = 'lib/${_relativeFrom(f.path, base: 'lib')}';
      final bytes = await f.readAsBytes();
      final hash = sha1.convert(bytes).toString();
      items.add({
        'path': relPath,
        'size': bytes.length,
        'sha1': hash,
      });
    }

    final payload = {
      'folder': folder,
      'generatedAt': generatedAt,
      'files': items,
    };

    final folderFile = File('${outDir.path}/${_sanitizeFolder(folder)}.index.json');
    folderFile.createSync(recursive: true);
    folderFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));

    catalogFolders.add({'folder': folder, 'index': folderFile.path});
  }

  // ルート catalog.json
  final catalog = {
    'generatedAt': generatedAt,
    'folders': catalogFolders,
  };
  File('${outDir.path}/catalog.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(catalog));

  stdout.writeln('Generated ${catalogFolders.length} folder indices into ${outDir.path}/');
}

String _relativeFrom(String full, {required String base}) {
  final normalized = full.replaceAll('\\', '/');
  final basePrefix = '$base/';
  final idx = normalized.indexOf(basePrefix);
  if (idx >= 0) {
    return normalized.substring(idx + basePrefix.length);
  }
  // 予備
  final i2 = normalized.lastIndexOf('/');
  return i2 >= 0 ? normalized.substring(i2 + 1) : normalized;
}

String _sanitizeFolder(String folder) {
  // lib/widgets -> lib_widgets など、ファイル名として使えるように
  return folder.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}