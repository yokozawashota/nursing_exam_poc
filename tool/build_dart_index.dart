// tool/build_dart_index.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// 出力ルート
const String outDir = '.dart-index';

/// 収集するルート（今回は lib 固定）
const String srcRoot = 'lib';

Future<void> main() async {
  final started = DateTime.now().toUtc();
  final libDir = Directory(srcRoot);

  if (!await libDir.exists()) {
    stderr.writeln('WARN: "$srcRoot" directory not found. Nothing to do.');
    await _writeCatalog([], started);
    return;
  }

  // 収集：lib 配下の .dart ファイルを走査
  final Map<String, List<Map<String, dynamic>>> buckets = {}; // key: lib/<folder> or lib/_root
  final stream = libDir.list(recursive: true, followLinks: false);

  await for (final entity in stream) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;

    final relPath = _relative(entity.path, from: '.'); // 例: lib/services/foo.dart
    final parts = p.split(relPath);

    // lib 直下か、サブフォルダかを分類
    String bucketKey;
    if (parts.length == 2) {
      // 例: ["lib", "main.dart"] -> _root
      bucketKey = '$srcRoot/_root';
    } else {
      // 例: ["lib","services","foo.dart"] -> lib/services
      bucketKey = p.join(parts[0], parts[1]);
    }

    final stat = await entity.stat();
    final content = await entity.readAsString();
    (buckets[bucketKey] ??= []).add({
      'path': relPath,                // 相対パス
      'file': parts.last,             // ファイル名
      'size': stat.size,              // バイトサイズ
      'modified': stat.modified.toUtc().toIso8601String(),
      'content': content,             // ★ 本文
    });
  }

  // 出力先を作成
  await Directory(outDir).create(recursive: true);
  final folders = <Map<String, dynamic>>[];

  // 各バケットごとに index.json を出力
  final sortedKeys = buckets.keys.toList()..sort(); // 安定した順序
  for (final key in sortedKeys) {
    final items = buckets[key]!..sort((a, b) => (a['path'] as String).compareTo(b['path'] as String));
    final destDir = Directory(p.join(outDir, key)); // 例: .dart-index/lib/services
    await destDir.create(recursive: true);

    final outFile = File(p.join(destDir.path, 'index.json'));
    final obj = {
      'folder': key,                       // 例: lib/services
      'generatedAt': started.toIso8601String() + 'Z',
      'count': items.length,
      'items': items,
    };
    await outFile.writeAsString(const JsonEncoder.withIndent('  ').convert(obj));

    folders.add({
      'folder': key,
      'index': _relative(outFile.path, from: outDir), // 例: lib/services/index.json
      'count': items.length,
    });
  }

  // ルートのカタログを書き出し
  await _writeCatalog(folders, started);

  // ログ出力（Actions のログに見やすく）
  stdout.writeln('Generated ${folders.length} folder indices under $outDir/');
  for (final f in folders) {
    stdout.writeln(' - ${f['folder']}/index.json (${f['count']} files)');
  }
}

/// ルートのカタログ .dart-index/index.json を出力
Future<void> _writeCatalog(List<Map<String, dynamic>> folders, DateTime started) async {
  final catalogFile = File(p.join(outDir, 'index.json'));
  await catalogFile.parent.create(recursive: true);
  final catalog = {
    'generatedAt': started.toIso8601String() + 'Z',
    'folders': folders,
  };
  await catalogFile.writeAsString(const JsonEncoder.withIndent('  ').convert(catalog));
}

/// from から target への相対パス（OS差異を吸収）
String _relative(String target, {required String from}) {
  final normTarget = p.normalize(target);
  final normFrom = p.normalize(from);
  return p.relative(normTarget, from: normFrom);
}