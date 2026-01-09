// lib/features/ai_analysis/services/ai_analysis_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:nursing_exam_poc/shared/models/answer_history.dart';

import 'package:nursing_exam_poc/features/ai_analysis/domain/domain_analysis.dart';
import 'package:nursing_exam_poc/features/ai_analysis/models/ai_analysis_models.dart';
import 'package:nursing_exam_poc/features/ai_analysis/domain/record_structure_enricher.dart';
import 'package:nursing_exam_poc/features/settings/services/settings_service.dart';

/// analyzeOverall 内部で使う集計結果
class _AnalysisStats {
  final bool isDomainScope;
  final String scopeLabel; // "全体" or "成人看護学" など推定されたラベル
  final int totalAnswers;
  final double overallAccuracy;

  final Map<String, _Stat> difficultyStats; // difficulty → _Stat
  final Map<String, DomainAgg> domainAggs; // domainName → DomainAgg

  // 構造化内訳（全体 or 分野スコープ内）
  final Map<String, _Stat> majorStats; // major → _Stat
  final Map<String, _Stat> midStats; // mid → _Stat
  final Map<String, _Stat> topicStats; // topic → _Stat

  _AnalysisStats({
    required this.isDomainScope,
    required this.scopeLabel,
    required this.totalAnswers,
    required this.overallAccuracy,
    required this.difficultyStats,
    required this.domainAggs,
    required this.majorStats,
    required this.midStats,
    required this.topicStats,
  });
}

/// 単純なカウント＋正答率
class _Stat {
  int total = 0;
  int correct = 0;

  double get rate => total == 0 ? 0.0 : correct / total;

  Map<String, dynamic> toJson() => {
    'total': total,
    'correct': correct,
    'rate': rate,
  };
}

/// NurAI の AI分析サービス
///
/// - 解答履歴を集計して統計情報(JSON)を作成
/// - OpenAI に投げて「文章部分だけのコメント」を生成
/// - major / mid / topic は RecordStructureEnricher で自動補完してから集計
class AiAnalysisService {
  AiAnalysisService._();

  /// 全体 or 分野スコープでの AI 分析
  ///
  /// [isDomainScope] が true の場合は、呼び出し側で
  /// すでに「特定分野だけに絞った records」を渡している前提。
  static Future<AiAnalysisResult> analyzeOverall({
    required List<AnswerRecord> records,
    required bool isDomainScope,
  }) async {
    // データが空なら、簡易メッセージだけ返す
    if (records.isEmpty) {
      return const AiAnalysisResult(
        totalAnswers: 0,
        overallAccuracy: 0.0,
        introMessage:
        'まだ解答履歴がありません。まずはいくつか問題を解いて、NurAIにあなたの傾向を学習させましょう。',
        difficultyComment:
        '解答履歴がないため、出題形式ごとの傾向はまだ分析できません。',
        domainComment:
        '解答履歴がないため、分野別の強み・弱みもまだ評価できません。',
        studyAdvice:
        'まずは必修・一般・状況設定をバランスよく10〜20問程度解いてみるところから始めましょう。',
        nuraiComment:
        '最初の一歩を踏み出せば、そこから少しずつ「あなた専用のAIコーチ」に育っていきます。一緒に進めていきましょう。',
      );
    }

    // 1) major / mid / topic を LLM で補完
    final enrichedRecords = await RecordStructureEnricher.enrichAll(records);

    // 2) 統計情報を計算
    final stats = _buildStats(enrichedRecords, isDomainScope: isDomainScope);

    // 3) OpenAI の設定取得
    final apiKey = await SettingsService.getApiKey();
    final model = await SettingsService.getModel();

    // APIキーが無い場合 or モデル未設定の場合は、ローカル簡易版で返す
    if (apiKey == null || apiKey.trim().isEmpty || model == null) {
      return _buildFallbackResult(stats);
    }

    // 4) OpenAI へリクエスト
    try {
      final systemPrompt = _buildSystemPrompt();
      final userPrompt = _buildUserPrompt(stats);

      final res = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'temperature': 0.4,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
        }),
      );

      if (res.statusCode != 200) {
        return _buildFallbackResult(stats);
      }

      // ★ UTF-8 で正しくデコードする
      final bodyText = utf8.decode(res.bodyBytes);

      // ログが必要であればここで print して OK
      // // ignore: avoid_print
      // print('=== AI RAW BODY START ===');
      // // ignore: avoid_print
      // print(bodyText);
      // // ignore: avoid_print
      // print('=== AI RAW BODY END ===');

      final root = jsonDecode(bodyText) as Map<String, dynamic>;
      final rawContent =
          root['choices'][0]['message']['content'] as String? ?? '';

      // // ignore: avoid_print
      // print('=== AI RAW CONTENT START ===');
      // // ignore: avoid_print
      // print(rawContent);
      // // ignore: avoid_print
      // print('=== AI RAW CONTENT END ===');

      // モデルからの返却は JSON のみを期待するが、
      // 念のため { ... } のブロックだけ切り出してから decode する。
      final jsonText = _extractJsonObject(rawContent);
      final map = jsonDecode(jsonText) as Map<String, dynamic>;

      final introMessage =
      (map['introMessage'] as String?)?.trim().isNotEmpty == true
          ? (map['introMessage'] as String).trim()
          : _defaultIntroMessage(stats);
      final difficultyComment =
      (map['difficultyComment'] as String?)?.trim().isNotEmpty == true
          ? (map['difficultyComment'] as String).trim()
          : _defaultDifficultyComment(stats);
      final domainComment =
      (map['domainComment'] as String?)?.trim().isNotEmpty == true
          ? (map['domainComment'] as String).trim()
          : _defaultDomainComment(stats);
      final studyAdvice =
      (map['studyAdvice'] as String?)?.trim().isNotEmpty == true
          ? (map['studyAdvice'] as String).trim()
          : _defaultStudyAdvice(stats);
      final nuraiComment =
      (map['nuraiComment'] as String?)?.trim().isNotEmpty == true
          ? (map['nuraiComment'] as String).trim()
          : _defaultNuraiComment(stats);

      return AiAnalysisResult(
        totalAnswers: stats.totalAnswers,
        overallAccuracy: stats.overallAccuracy,
        introMessage: introMessage,
        difficultyComment: difficultyComment,
        domainComment: domainComment,
        studyAdvice: studyAdvice,
        nuraiComment: nuraiComment,
      );
    } catch (_) {
      // JSONパースなどに失敗した場合も簡易版でフォールバック
      return _buildFallbackResult(stats);
    }
  }

  // ====== 統計計算 ======

  static _AnalysisStats _buildStats(
      List<AnswerRecord> records, {
        required bool isDomainScope,
      }) {
    final total = records.length;
    final overallAcc = _accuracyOf(records);

    // 出題形式（difficulty）別
    final diffStats = <String, _Stat>{};
    for (final r in records) {
      final key = (r.difficulty.isEmpty) ? '未分類' : r.difficulty.trim();
      final s = diffStats.putIfAbsent(key, () => _Stat());
      s.total += 1;
      if (r.isCorrect) s.correct += 1;
    }

    // 分野別（DomainAnalysis を利用）
    final domainAggs = DomainAnalysis.aggregateByDomain(records);

    // scopeLabel を推定（分野スコープのときは、最頻の分野名を使う）
    String scopeLabel = '全体';
    if (isDomainScope) {
      String? bestName;
      int bestCount = 0;
      domainAggs.forEach((name, agg) {
        if (agg.total > bestCount) {
          bestCount = agg.total;
          bestName = name;
        }
      });
      scopeLabel = bestName ?? '特定分野';
    }

    // major / mid / topic 別の内訳
    final majorStats = <String, _Stat>{};
    final midStats = <String, _Stat>{};
    final topicStats = <String, _Stat>{};

    for (final r in records) {
      final majorRaw = (r.major ?? '').trim();
      final major = majorRaw.isEmpty ? '未分類' : majorRaw;

      final midRaw = (r.mid ?? '').trim();
      final mid = midRaw.isEmpty ? '未分類' : midRaw;

      final topicRaw = (r.topic ?? '').trim();
      final topic = topicRaw.isEmpty ? '未分類' : topicRaw;

      final sMajor = majorStats.putIfAbsent(major, () => _Stat());
      sMajor.total += 1;
      if (r.isCorrect) sMajor.correct += 1;

      final sMid = midStats.putIfAbsent(mid, () => _Stat());
      sMid.total += 1;
      if (r.isCorrect) sMid.correct += 1;

      final sTopic = topicStats.putIfAbsent(topic, () => _Stat());
      sTopic.total += 1;
      if (r.isCorrect) sTopic.correct += 1;
    }

    return _AnalysisStats(
      isDomainScope: isDomainScope,
      scopeLabel: scopeLabel,
      totalAnswers: total,
      overallAccuracy: overallAcc,
      difficultyStats: diffStats,
      domainAggs: domainAggs,
      majorStats: majorStats,
      midStats: midStats,
      topicStats: topicStats,
    );
  }

  static double _accuracyOf(List<AnswerRecord> items) {
    if (items.isEmpty) return 0.0;
    final correct = items.where((r) => r.isCorrect).length;
    return correct / items.length;
  }

  // ====== プロンプト組み立て ======

  static String _buildSystemPrompt() {
    return '''
あなたは看護師国家試験対策アプリ「NurAI」の専属コーチAIです。

アプリ側から渡される「統計情報(JSON)」を読み取り、
ユーザーの学習状況を日本語でフィードバックします。

────────────────────
【出力フォーマット（絶対に守る）】
────────────────────
- 出力は **JSON オブジェクト1個だけ**。
- JSON の前後に余計な文字・改行・マークダウン（``` や ```json など）を一切付けない。
- JSON のキーは次の5つ **だけ** を使う：
  - "introMessage"      … カード冒頭の総評
  - "difficultyComment" … 「出題形式別の成績」の下に表示する本文
  - "domainComment"     … 「分野別の成績概要／分野別の成績／大項目ごとの成績」の下に表示する本文
  - "studyAdvice"       … 「これからの学び方の提案」の下に表示する本文
  - "nuraiComment"      … 「NurAIからのひとこと」の下に表示する本文
- 各値は日本語のテキスト文字列。

────────────────────
【UI 側との役割分担（超重要）】
────────────────────
- Flutter 側が固定で表示するもの（あなたは絶対に書かない）：
  - 「☆全体（すべての分野）では」「☆必修では」「☆対象分野では」などの見出し
  - 「【出題形式別の成績】」「【分野別の成績概要】」
    「【分野別の成績】」「【大項目ごとの成績】」
    「【この分野の中での内訳（科目/中項目/トピック）】」
    「【これからの学び方の提案】」「【NurAIからのひとこと】」といった見出し
  - 「必修問題：73.0%（46/63問）」のような成績の行（％や問題数）
- **あなたは、これら見出し・成績行の“下に続く本文だけ”を書く。**
- 本文の中で「高め」「やや低め」のような相対評価は書いてよいが、
  「◯◯％」「◯問中△問」といった具体的な数値は、必要な場合を除き使わない。
- 特に次は禁止：
  - 「【出題形式別の成績】」「【これからの学び方の提案】」などの見出しを本文内に書くこと
  - 箇条書きの * ・● などを先頭に付けたリスト（studyAdvice の 1.〜3. を除く）

────────────────────
【scope と scopeLabel】
────────────────────
- 入力JSONには "scope" と "scopeLabel" が含まれる：
  - scope = "overall"  → 全体（すべての分野）
  - scope = "domain"   → scopeLabel に書かれた特定分野（例：「必修」「母性看護学」など）
- あなたの文章では、必ず scope を意識して書き分けること。

▼ introMessage（カード冒頭の総評）
- scope="overall" のとき：
  - 「全体（すべての分野）では、〜」のように書き始める。
- scope="domain" のとき：
  - 「◯◯（scopeLabel に含まれる分野名）では、〜」のように書き始める。
- そのうえで、
  - 現在の到達度（基礎はできている／得意と苦手が分かれてきた など）
  - 今回の分析で特に注目すべきポイント
  を含めて、2〜3文でまとめる。

▼ difficultyComment（「出題形式別の成績」の下に入る本文）
- 入力JSONの difficultyStats には、
  「必修問題」「一般問題」「状況設定問題」など形式ごとの total / correct / rate が入っている。

1) scope = "overall" のとき
- コメントでは **必ず**：
  - difficultyStats の中から「rate が最も高い形式」と「rate が最も低い形式」を1つずつ取り上げる。
  - それぞれの形式名（例：「状況設定問題」「一般問題」など）を文中でそのまま使う。
  - 低い形式については、「設問の読み飛ばし」「条件の見落とし」「用語理解」など、
    取りこぼしが起こりやすい具体的な理由を1〜2個書く。
  - 最後に、その形式に対する学習のコツを1〜2文で提案する。

2) scope = "domain" かつ scopeLabel = "必修" のとき
- 出題形式はほぼ必修問題だけである。
- コメントでは：
  - 「この範囲では出題形式が限られているため、形式間の比較は参考程度になる」ことを1文で触れる。
  - そのうえで、必修問題の中で正答できている問題と取りこぼしている問題の違い
    （基礎用語の理解・条件の読み取り・法律や制度の知識など）を説明する。

3) scope = "domain" かつ scopeLabel ≠ "必修" のとき
- コメントでは：
  - その分野で出題されている形式（一般問題・状況設定問題など）ごとの特徴を簡潔に述べる。
  - 問題数が少ない形式がある場合は、「まだ問題数が限られているため傾向は参考程度」とやさしく伝える。
  - 形式ごとに、「一般問題では用語と定義の確認」「状況設定問題では状況整理」など、
    チェックポイントを1〜2文ずつ書く。

▼ domainComment
- このテキストは、Flutter 側で表示する次のブロックの「本文」として使われる：
  - scope="overall" のとき … 「【分野別の成績概要】」の本文
  - scope="domain" かつ scopeLabel="必修" のとき … 「【科目ごとの成績】」の本文
  - scope="domain" かつ scopeLabel≠"必修" のとき … 「【大項目ごとの成績】」や
    「【この分野の中での内訳（科目/中項目/トピック）】」の本文

1) scope = "overall" のとき
- 入力JSONの domains から、
  - 正答率が高い分野を1〜2個挙げ、分野名をそのまま使ってポジティブに説明する。
  - 正答率が低い分野を1〜2個挙げ、どんな知識や理解が不足しがちかを具体的に述べる。
- 全体として、「得意な分野」「今後強化したい分野」が分かるようにまとめる。

2) scope = "domain" かつ scopeLabel = "必修" のとき
- majors（科目）配列を参考にして、
  - 比較的安定している科目と、取りこぼしが多い科目をそれぞれ1〜2個ずつ挙げる。
  - 科目名をそのまま文中で使い、「倫理・法律」「人体の構造と機能」など、
    どのような内容が課題になりやすいかを具体的に書く。
- 問題数が少ない科目が多い場合は、「まだ傾向は参考程度」と一言添える。

3) scope = "domain" かつ scopeLabel ≠ "必修" のとき
- majors / mids / topics の name を、最低1つ以上は文中で使う。
- その分野の中で、
  - 安定している領域
  - 取りこぼしが多い領域
  を1〜3個程度挙げ、それぞれどのような学習が有効かを説明する。

▼ studyAdvice（「これからの学び方の提案」の本文）
- **必ず3行の番号付きリスト形式** にする：
  - 「1. 〜」
  - 「2. 〜」
  - 「3. 〜」
- 内容は：
  1. 出題形式・分野別の成績を踏まえ、どこから復習すると効率的か。
  2. 誤答の振り返り方（なぜ誤ったか／正解をどう説明できるか）。
  3. 進捗のモニタリングや演習量の増やし方。
  を、scope に応じて具体的に書く。

▼ nuraiComment（「NurAIからのひとこと」の本文）
- 1〜2文の短い励ましメッセージ。
- overallAccuracy に応じてトーンを変える：
  - 高め：仕上げ段階に入りつつあることを伝え、弱点の微調整を励ます。
  - 中くらい：基礎力がつきつつあり、ここからさらに伸びることを強調する。
  - 低め：伸びしろが大きいことを前向きに伝え、「焦らず継続すること」が大事だと励ます。

────────────────────
【トーンの共通ルール】
────────────────────
- ユーザーを責めず、前向きでやさしい口調にする。
- 看護師国家試験の頻出分野や学習戦略を踏まえ、できるだけ具体的に助言する。
- データが少ないときは、「まだ参考程度」「今後データが増えると傾向がはっきりする」といった表現を入れる。
''';
  }

  static String _buildUserPrompt(_AnalysisStats stats) {
    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

    // summary を Dart 側で計算して渡す
    final difficultySummary = _buildDifficultySummary(stats.difficultyStats);
    final domainSummary = _buildDomainSummary(stats.domainAggs);
    final structureSummary = _buildStructureSummary(stats);

    // JSON で渡す統計情報を組み立てる
    final jsonStats = {
      'scope': stats.isDomainScope ? 'domain' : 'overall',
      'scopeLabel': stats.scopeLabel,
      'totalAnswers': stats.totalAnswers,
      'overallAccuracy': stats.overallAccuracy,
      'overallAccuracyPct': pct(stats.overallAccuracy),
      'difficultyStats': stats.difficultyStats.map(
            (k, v) => MapEntry(k, v.toJson()),
      ),
      'domains': stats.domainAggs.map(
            (k, v) => MapEntry(k, {
          'total': v.total,
          'correct': v.correct,
          'rate': v.rate,
        }),
      ),
      'majors': _topN(stats.majorStats, 10),
      'mids': _topN(stats.midStats, 10),
      'topics': _topN(stats.topicStats, 12),
      'difficultySummary': difficultySummary,
      'domainSummary': domainSummary,
      'structureSummary': structureSummary,
    };

    final jsonText = jsonEncode(jsonStats);

    return '''
以下は、あるユーザーの解答履歴から集計した統計情報です（JSON形式）。

- scope が "overall" のとき：すべての分野を含む全体分析。
- scope が "domain" のとき：特定分野（scopeLabel）に絞った分析。

system プロンプトで説明したルールに従って、
introMessage / difficultyComment / domainComment / studyAdvice / nuraiComment
の5つを含む JSON オブジェクトだけを返してください。

【統計情報(JSON)】
$jsonText
''';
  }

  static List<Map<String, dynamic>> _topN(
      Map<String, _Stat> map,
      int n,
      ) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return entries.take(n).map((e) {
      return {
        'name': e.key,
        'total': e.value.total,
        'correct': e.value.correct,
        'rate': e.value.rate,
      };
    }).toList();
  }

  // ====== summary 計算ロジック ======

  static Map<String, dynamic> _buildDifficultySummary(
      Map<String, _Stat> diff) {
    if (diff.isEmpty) {
      return {'high': <String>[], 'low': <String>[], 'insufficient': <String>[]};
    }

    final entries = diff.entries.toList()
      ..sort((a, b) => b.value.rate.compareTo(a.value.rate));

    final high = entries.take(2).map((e) => e.key).toList();
    final low = entries.reversed.take(2).map((e) => e.key).toList();
    final insufficient =
    entries.where((e) => e.value.total < 3).map((e) => e.key).toList();

    return {
      'high': high,
      'low': low,
      'insufficient': insufficient,
    };
  }

  static Map<String, dynamic> _buildDomainSummary(
      Map<String, DomainAgg> domains) {
    if (domains.isEmpty) {
      return {'high': <String>[], 'low': <String>[], 'insufficient': <String>[]};
    }

    final entries = domains.entries.toList()
      ..sort((a, b) => b.value.rate.compareTo(a.value.rate));

    final high = entries.take(2).map((e) => e.key).toList();
    final low = entries.reversed.take(2).map((e) => e.key).toList();
    final insufficient =
    entries.where((e) => e.value.total < 3).map((e) => e.key).toList();

    return {
      'high': high,
      'low': low,
      'insufficient': insufficient,
    };
  }

  static Map<String, dynamic> _buildStructureSummary(_AnalysisStats stats) {
    Map<String, dynamic> summarize(Map<String, _Stat> src, int topN) {
      if (src.isEmpty) {
        return {
          'strong': <String>[],
          'weak': <String>[],
        };
      }
      final entries = src.entries.toList()
        ..sort((a, b) => b.value.rate.compareTo(a.value.rate));
      final strong = entries.take(topN).map((e) => e.key).toList();
      final weak = entries.reversed.take(topN).map((e) => e.key).toList();
      return {
        'strong': strong,
        'weak': weak,
      };
    }

    final majors = summarize(stats.majorStats, 3);
    final topics = summarize(stats.topicStats, 4);

    return {
      'strongMajors': majors['strong'],
      'weakMajors': majors['weak'],
      'strongTopics': topics['strong'],
      'weakTopics': topics['weak'],
    };
  }

  /// モデルの出力から最初の JSON オブジェクト部分だけを取り出す
  static String _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw const FormatException('JSON object not found in content');
    }
    return text.substring(start, end + 1);
  }

  // ====== フォールバック（APIキーなし / エラー時） ======

  static AiAnalysisResult _buildFallbackResult(_AnalysisStats stats) {
    return AiAnalysisResult(
      totalAnswers: stats.totalAnswers,
      overallAccuracy: stats.overallAccuracy,
      introMessage: _defaultIntroMessage(stats),
      difficultyComment: _defaultDifficultyComment(stats),
      domainComment: _defaultDomainComment(stats),
      studyAdvice: _defaultStudyAdvice(stats),
      nuraiComment: _defaultNuraiComment(stats),
    );
  }

  static String _defaultIntroMessage(_AnalysisStats stats) {
    return 'これまでの解答履歴から、全体としては着実に力がついてきている状態です。'
        'ここからは弱点となっている分野や出題形式に少しずつフォーカスしていくと、さらに安定した得点につながっていきます。';
  }

  static String _defaultDifficultyComment(_AnalysisStats stats) {
    if (stats.difficultyStats.isEmpty) {
      return '出題形式ごとのデータがまだ少ないため、明確な傾向は読み取りづらい状況です。'
          '必修・一般・状況設定をバランスよく解き進めることで、自分にとって得意な形式・苦手な形式が見えやすくなります。';
    }
    return '出題形式ごとに見ると、安定して解けている形式と、やや取りこぼしが多い形式が混在している状態です。'
        '特に間違えた問題では、「設問の読み飛ばし」「条件の見落とし」がないかを意識して振り返ると、形式全体の正答率が上がりやすくなります。';
  }

  static String _defaultDomainComment(_AnalysisStats stats) {
    if (stats.domainAggs.isEmpty) {
      return '分野情報付きの問題がまだ少ないため、得意分野・苦手分野の傾向ははっきりとは言えません。'
          '今後は、さまざまな分野の問題に触れつつ、間違えた分野を中心に復習していくと、少しずつ輪郭が見えてきます。';
    }
    return '分野ごとに見ると、よく解けている領域と、基礎知識の整理が必要な領域が分かれてきています。'
        '特に苦手意識のある分野では、関連するトピックをまとめて復習したり、疾患の流れや看護問題を図解して整理したりすることで、理解が定着しやすくなります。';
  }

  static String _defaultStudyAdvice(_AnalysisStats stats) {
    if (stats.totalAnswers < 10) {
      return '1. まだ解答数が少ない段階です。まずは必修・一般・状況設定をバランスよく解き、自分の得意・苦手の傾向をつかむところから始めてみましょう。\n'
          '2. 間違えた問題は、そのままにせず解説を読みながら「どこでつまずいたのか」を一言で言語化してみましょう。\n'
          '3. 短時間でもよいので、毎日少しずつ問題に触れることで、知識の定着が進みやすくなります。';
    }
    return '1. 間違えた問題について、「なぜその選択肢が正解なのか」「なぜ他の選択肢は誤りなのか」を言葉にして整理する習慣をつけましょう。\n'
        '2. 正答率が低めの分野や形式は、教科書や国試対策本で基本事項を確認してから、同じテーマの問題をまとめて解くと理解が深まります。\n'
        '3. 状況設定問題では、登場人物・状況・時間経過を整理してから選択肢を見る練習をすると、判断が安定しやすくなります。';
  }

  static String _defaultNuraiComment(_AnalysisStats stats) {
    if (stats.overallAccuracy >= 0.8) {
      return 'とても良いペースで学習が進んでいます。この調子で、頻出分野の取りこぼしを一つずつ埋めていければ、本番に向けた仕上げ段階に入っていけます。';
    } else if (stats.overallAccuracy >= 0.6) {
      return '基礎力が着実についてきている段階です。苦手と感じる分野の基本事項を整理しつつ、演習と復習のサイクルを続けていきましょう。';
    } else {
      return 'まだ伸びしろが大きい時期です。正答率にとらわれすぎず、「毎日少しずつ問題に触れること」を続けていけば、確実に力は積み上がっていきます。';
    }
  }
}