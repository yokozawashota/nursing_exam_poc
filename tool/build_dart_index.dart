// tool/build_dart_index.dart
//
// lib/ 以下の Dart ファイルを走査して、
// フォルダ（lib/<top-level>/...）ごとに JSON を分割出力します。
// 例: lib/services/... -> .indices/dart-index-services.json
//
// JSON 形式：
// {
//   "generatedAt": "2025-10-14T12:34:56Z",
//   "basePath": "lib",
//   "encoding": "base64",
//   "files": { "services/question_service.dart": "<BASE64>", ... }
// }

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final baseDir = Directory('lib');
  if (!await baseDir.exists()) {
    stderr.writeln('lib/ が見つかりません。プロジェクト直下で実行してください。');
    exit(1);
  }

  // 出力先（コミットして良いなら repo 内、そうでなければ .gitignore 推奨）
  final outDir = Directory('.indices');
  if (!await outDir.exists()) {
    await outDir.create(recursive: true);
  }

  // 収集：top-level フォルダ名 → { 相対パス: Base64(content) }
  final Map<String, Map<String, String>> buckets = {};
  // ルート直下 (lib/*.dart) 専用バケツ
  const rootBucketKey = '_root';

  await for (final entity in baseDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;

    final relPath = entity.path.replaceFirst('lib/', '');
    final parts = relPath.split(Platform.pathSeparator);

    // top-level = services / widgets / screens / data / models / theme / ...
    final String bucket = (parts.length >= 2) ? parts.first : rootBucketKey;

    final content = await entity.readAsString(); // UTF-8 と仮定
    final b64 = base64Encode(utf8.encode(content));

    buckets.putIfAbsent(bucket, () => <String, String>{});
    buckets[bucket]![relPath] = b64;
  }

  final nowIso = DateTime.now().toUtc().toIso8601String();

  Future<void> writeBucket(String bucket, Map<String, String> files) async {
    final map = <String, dynamic>{
      'generatedAt': nowIso,
      'basePath': 'lib',
      'encoding': 'base64',
      'files': files, // { "services/x.dart": "..." }
    };

    final safeName = bucket == rootBucketKey ? 'root' : bucket;
    final outFile = File('${outDir.path}/dart-index-$safeName.json');
    await outFile.writeAsString(jsonEncode(map));
    stdout.writeln('Wrote ${outFile.path} (${files.length} files)');
  }

  // 書き出し
  for (final entry in buckets.entries) {
    await writeBucket(entry.key, entry.value);
  }

  // 全バケツに跨る「総合インデックス」を小さく作りたい場合は、メタだけ出す:
  final summary = {
    'generatedAt': nowIso,
    'parts': buckets.keys
        .map((k) => k == rootBucketKey ? 'root' : k)
        .map((name) => '.indices/dart-index-$name.json')
        .toList(),
  };
  await File('${outDir.path}/dart-index-summary.json')
      .writeAsString(jsonEncode(summary));
  stdout.writeln('Wrote .indices/dart-index-summary.json');
}