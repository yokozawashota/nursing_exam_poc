// lib/questioning/services/prompt_builder.dart

/// OpenAI へ送るプロンプト（system / user）の組み立てを担当するユーティリティ。
class PromptBuilder {
  /// system プロンプト（固定方針＋ハード制約）
  ///
  /// - 必ず JSON オブジェクトのみを返す（前後に説明文やコードフェンスを付けない）
  /// - `questionKind` は desiredKind と一致させる
  /// - 選択肢数は desiredChoiceCount 個「ちょうど」
  /// - 正答数は requiredCorrectCount と一致（single=1 / multiple=2）
  /// - "select_incorrect" のときは、`correctAnswers` に「誤っている選択肢」のラベルを入れる
  /// - 医学・看護学的に整合した正誤になるよう、自己チェックを行う
  ///
  /// 出力スキーマ:
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
      '- 選択肢 "choices" は { "A": "...", "B": "...", ... } の連想配列形式で、キーは A から始まる昇順 (A〜${desiredChoiceCount == 5 ? 'E' : 'D'})。',
      '- 選択肢の個数は ちょうど $desiredChoiceCount 個にする（多すぎ/少なすぎは禁止）。',
      '- "correctAnswers" は ["A", ...] の形で、要素数は $requiredCorrectCount 個に一致させる。',
      '- single のときは正答は 1 個、multiple のときは正答は 2 個に固定。',
      '- "select_incorrect" のときは、"correctAnswers" には「誤っている選択肢」のラベルだけを入れる（正しい選択肢のラベルは絶対に含めない）。',

      '',
      '【内容上の厳格な条件】',
      '- 医学・看護学的に明確な正誤が判断できるテーマを扱う。',
      '- 正しい選択肢は、解説や rationales でも「正しい」「妥当」など一貫して肯定される内容にする。',
      '- 誤っている選択肢は、解説や rationales でも「誤り」「不適切」など一貫して否定される内容にする。',
      '- "select_incorrect" のとき:',
      '  - 選択肢のうち $requiredCorrectCount 個だけ明確に誤った記述にし、それ以外は明確に正しい記述にする。',
      '  - "correctAnswers" には、その誤った選択肢のラベルだけを列挙する。',
      '- "multiple" のとき:',
      '  - 正答の選択肢同士は、すべて正しい内容で互いに矛盾しないようにする。',
      '  - 誤答の選択肢は、明確な誤りを含む記述にする。',
      '- "single" のとき:',
      '  - 正答は 1 つだけが明らかに正しく、他は明らかに誤りになるようにする。',

      '',
      '【自己チェック】',
      '- 出力する前に、次のチェックを必ず行うこと:',
      '  1) "correctAnswers" に含まれるラベルの選択肢が、本当に指定の意味で正しい／誤っているか（問題文の指示と矛盾しないか）。',
      '  2) "explanation" と "rationales" が、"correctAnswers" に指定したラベルと論理的に矛盾していないか。',
      '  3) "select_incorrect" の場合、"correctAnswers" の各ラベルの文章が、本当に誤った記述になっているか。',

      '',
      '【禁止事項】',
      '- JSON 以外の文字、注釈、コードフェンス、整形エラー。',
      '- 指定個数と異なる選択肢数や正答数。',
      '- 正しいはずの選択肢を「誤答」として "correctAnswers" に含めること。',
      '- 誤っているはずの選択肢を「正答」として扱うこと。',

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
    int requiredCorrectCount = 1,   // single=1, multiple=2 など
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
      b.writeln('- select_incorrect の場合、"correctAnswers" は「誤っている選択肢」のラベルだけを列挙する（正しい選択肢は絶対に含めない）。');
      b.writeln('- 誤っている選択肢は、明確に誤りと分かる内容にし、他の選択肢は明確に正しい内容にする。');
    } else {
      b.writeln('- single/multiple の場合、"correctAnswers" は内容的に正しい選択肢のラベルだけを列挙する。');
      b.writeln('- 誤答選択肢には、事実と異なる、もしくは不適切な記述を入れる。');
    }
    b.writeln('- 出力は必ず JSON オブジェクトのみ。');
    b.writeln('- 各選択肢は重複や曖昧さがないように明確に作成する。');
    b.writeln('- 解説は根拠を簡潔に示す。可能なら各選択肢の理由 (rationales) を付与する。');

    b.writeln('');
    b.writeln('【自己チェック】');
    b.writeln('- 出力前に、次の点を必ず確認してから JSON を返すこと:');
    b.writeln('  1) 問題文の指示（「正しいものを選べ」「誤っているものを選べ」など）と、"correctAnswers" の意味が一致しているか。');
    b.writeln('  2) "correctAnswers" に含まれるラベルの文章が、解説・rationales の内容と矛盾していないか。');

    // =========================
    // ここから「状況設定問題」専用の追加要件
    // =========================
    if (difficulty == '状況設定問題') {
      b.writeln('');
      b.writeln('【状況設定問題としての追加要件】');
      b.writeln('- 問題文全体は「状況設定文＋設問」という構成にする。');
      b.writeln('- "question" フィールドのテキストは、次の構造を持つ 1 本の文章とする:');
      b.writeln('  1) 冒頭に「次の文を読み問題に答えよ。」などの指示文を置く。');
      b.writeln('  2) その後に、患者や家族などの背景を説明する状況設定文を 3〜6 文程度書く。');
      b.writeln('     - 年齢（例：◯歳の男性／女性）');
      b.writeln('     - 職業や生活背景（例：会社員、一人暮らし、夫と二人暮らし など）');
      b.writeln('     - 既往歴や治療歴、家族構成、生活上の困りごとなど');
      b.writeln('     - 発症のきっかけや現在の症状、受診の経緯 など');
      b.writeln('  3) 最後に「問題1」または「このとき看護師の対応として最も適切なのはどれか。」など、国試の設問らしい一文で締める。');
      b.writeln('- 文章量の目安は全体で日本語 300〜600字程度とし、短すぎず長すぎない分量にする。');
      b.writeln('- 会話文だけにならないようにし、地の文（叙述）と会話をバランスよく用いる。');
      b.writeln('- 時系列の流れ（受診前 → 受診時 → 受診後 など）がある程度わかるように記述する。');
      b.writeln('- 看護師が判断・対応を問われる文脈（観察、情報収集、家族への支援、多職種連携など）を明確に示す。');
      b.writeln('- 実際の看護師国家試験の状況設定問題の雰囲気に近づける。');
      b.writeln('- 設問の主語は「看護師」や「看護管理者」などを用い、国家試験らしい問い方にする。');
    }

    return b.toString();
  }
}