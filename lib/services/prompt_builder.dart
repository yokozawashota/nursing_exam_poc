// lib/services/prompt_builder.dart

/// OpenAI へ送るプロンプト（system / user）の組み立てを担当するユーティリティ。
class PromptBuilder {
  /// system プロンプト（固定方針＋ハード制約）
  ///
  /// - 必ず JSON オブジェクトのみを返す（前後に説明文やコードフェンスを付けない）
  /// - `questionKind` は desiredKind と一致させる
  /// - 選択肢数は desiredChoiceCount 個「ちょうど」
  /// - 正答数は requiredCorrectCount と一致（single=1 / multiple=2）
  /// - "select_incorrect" のときは、`correctAnswers` に「誤っている選択肢」のラベルを入れる
  /// - フィールド定義:
  ///   {
  ///     "question": string,
  ///     "choices": { "A": string, "B": string, ... },   // A..D または A..E
  ///     "correctAnswers": [ "A", ... ],                  // ラベル配列（1 or 2）
  ///     "questionKind": "single" | "multiple" | "select_incorrect",
  ///     "explanation": string,
  ///     "rationales": { "A": string, "B": string, ... } // 任意
  ///   }
  static String buildSystemPrompt({
    String desiredKind = 'single',
    int desiredChoiceCount = 4,
    int requiredCorrectCount = 1,
  }) {
    return [
      'あなたは日本の看護師国家試験の出題委員です。',
      '厚労省の出題基準に準拠し、日本語として自然で学術的に正確な択一式問題を作成します。',
      '出力は必ず JSON オブジェクトのみ（前後に余計な文字やコードフェンスを含めない）。',
      '',
      '【厳守すべき形式制約】',
      '- "questionKind" は必ず "$desiredKind" とする。',
      '- 選択肢 "choices" は { "A": "...", "B": "...", ... } の連想配列形式で、キーは A から始まる昇順。',
      '- 選択肢の個数は ちょうど $desiredChoiceCount 個にする（多すぎ/少なすぎは禁止）。',
      '- "correctAnswers" は ["A", ...] の形で、要素数は $requiredCorrectCount 個に一致させる。',
      '- "select_incorrect" のときは、"correctAnswers" には「誤っている選択肢」のラベルを入れる。',
      '- single のときは正答は 1 個、multiple のときは正答は 2 個に固定。',
      '',
      '【禁止事項】',
      '- JSON 以外の文字、注釈、コードフェンス、整形エラー。',
      '- 指定個数と異なる選択肢数や正答数。',
      '',
      '【出力スキーマ】',
      '{',
      '  "question": string,',
      '  "choices": { "A": string, "B": string, "C": string, "D": string' +
          (desiredChoiceCount == 5 ? ', "E": string' : '') +
          ' },',
      '  "correctAnswers": [ "A"' + (requiredCorrectCount == 2 ? ', "B"' : '') + ' ],',
      '  "questionKind": "single" | "multiple" | "select_incorrect",',
      '  "explanation": string,',
      '  "rationales": { "A": string, "B": string, "C": string, "D": string' +
          (desiredChoiceCount == 5 ? ', "E": string' : '') +
          ' }',
      '}',
    ].join('\n');
  }

  /// user プロンプト（出題条件）
  static String buildUserPrompt({
    required String difficulty,     // 必修問題 / 一般問題 / 状況設定問題
    required String domain,         // 例：人体の構造と機能
    required String major,          // 例：循環器系
    String? mid,
    String? topic,
    String? scenarioAspect,
    String desiredKind = 'single',  // single / multiple / select_incorrect
    int desiredChoiceCount = 4,     // 4 or 5
    int requiredCorrectCount = 1,   // single=1, multiple=2（固定化）
  }) {
    final b = StringBuffer();
    b.writeln('出題形式: $difficulty');
    b.writeln('分野: $domain');
    b.writeln('大項目: $major');
    if (mid != null && mid.isNotEmpty) b.writeln('中項目: $mid');
    if (topic != null && topic.isNotEmpty) b.writeln('トピック: $topic');
    if (scenarioAspect != null && scenarioAspect.isNotEmpty) {
      b.writeln('状況設定の観点: $scenarioAspect');
    }
    b.writeln('');
    b.writeln('【問題生成の仕様】');
    b.writeln('- questionKind は "$desiredKind" に固定する。');
    b.writeln('- 選択肢は $desiredChoiceCount 個に固定（A..' +
        (desiredChoiceCount == 5 ? 'E' : 'D') + '）。');
    b.writeln('- 正答数は $requiredCorrectCount 個に固定する。');
    if (desiredKind == 'select_incorrect') {
      b.writeln('- select_incorrect の場合、"correctAnswers" は誤っている選択肢のラベルを列挙する。');
    } else {
      b.writeln('- single/multiple の場合、"correctAnswers" は正しい選択肢のラベルを列挙する。');
    }
    b.writeln('- 出力は必ず JSON オブジェクトのみ。');
    b.writeln('- 各選択肢は重複や曖昧さがないように明確に作成する。');
    b.writeln('- 解説は根拠を簡潔に示す。可能なら各選択肢の理由 (rationales) を付与する。');
    return b.toString();
  }
}