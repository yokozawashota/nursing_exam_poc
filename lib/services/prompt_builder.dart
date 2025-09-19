// lib/services/prompt_builder.dart

/// OpenAI へ送るプロンプト（system / user）の組み立てを担当するユーティリティ。
class PromptBuilder {
  /// system プロンプト（固定方針）
  static String buildSystemPrompt() {
    return 'あなたは日本の看護師国家試験の出題委員です。'
        '厚労省の出題基準に準拠し、日本語として自然で学術的に正確な択一式（4択）問題を作成します。'
        '出力は必ず JSON オブジェクトのみ。'
        '形式の例: {"question": string, "choices": [string,string,string,string], '
        '"correctIndex": number, "explanation": string, '
        '"rationales": {"A": "...", "B": "...", "C": "...", "D": "..."}}';
  }

  /// user プロンプト（選択条件を反映）
  static String buildUserPrompt({
    required String difficulty,
    required String domain,
    required String major,
    String? mid,
    String? topic,
    String? scenarioAspect,
  }) {
    final b = StringBuffer();
    b.writeln('出題形式: $difficulty');  // 必修問題 / 一般問題 / 状況設定問題
    b.writeln('分野: $domain');          // 例：人体の構造と機能
    b.writeln('大項目: $major');         // 例：循環器系 など
    if (mid != null && mid.isNotEmpty) {
      b.writeln('中項目: $mid');
    }
    if (topic != null && topic.isNotEmpty) {
      b.writeln('トピック: $topic');
    }
    if (scenarioAspect != null && scenarioAspect.isNotEmpty) {
      b.writeln('状況設定の観点: $scenarioAspect');
    }

    // 出力要件：JSON固定・4択・重複のない選択肢・正答と解説・（可能なら）各選択肢のラショナーレ
    b.writeln('要件: 出力は必ず JSON オブジェクト。4択、各選択肢は重複しないこと。'
        '正答とわかりやすい解説を含める。可能であれば各選択肢の理由 (rationales) も付与する。'
        '内容は最新の知見とガイドラインに矛盾しないように。');

    return b.toString();
  }
}