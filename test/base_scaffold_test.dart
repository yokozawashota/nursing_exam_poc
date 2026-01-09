import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nursing_exam_poc/shared/widgets/base_scaffold.dart';

void main() {
  testWidgets('BaseScaffold がヘッダー/本文/フッターを表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BaseScaffold(
          title: 'タイトル',
          body: Text('本文エリア'),
        ),
      ),
    );

    expect(find.text('タイトル'), findsOneWidget);
    expect(find.text('本文エリア'), findsOneWidget);
    // 既定フッター（© 2025 NurAI）の存在確認
    expect(find.textContaining('© 2025'), findsOneWidget);
  });

  testWidgets('戻るボタンの表示制御（ルートでは非表示）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BaseScaffold(
          title: 'Root',
          body: SizedBox.shrink(),
        ),
      ),
    );
    // ルートでは戻るボタンが出ない
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('カスタムフッターを差し替えられる', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BaseScaffold(
          title: 'タイトル',
          body: SizedBox.shrink(),
          footer: Text('© 2025 NurAI Ver 1.0'),
        ),
      ),
    );
    expect(find.text('© 2025 NurAI Ver 1.0'), findsOneWidget);
  });
}