import 'dart:io';
import 'dart:convert';

Future<void> main(List<String> args) async {
  final roots = args.isEmpty ? ['lib'] : args; // 必要なら test, tool も渡す
  final map = <String, String>{};

  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is File && e.path.endsWith('.dart')) {
        map[e.path.replaceAll('\\', '/')] = await e.readAsString();
      }
    }
  }

  final out = const JsonEncoder.withIndent('  ').convert({
    'generatedAt': DateTime.now().toIso8601String(),
    'roots': roots,
    'count': map.length,
    'files': map,
  });
  await File('dart-index.json').writeAsString(out);
  print('Wrote dart-index.json with ${map.length} files');
}