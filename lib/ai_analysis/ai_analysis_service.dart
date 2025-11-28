// lib/ai_analysis/ai_analysis_service.dart
import 'dart:math';

import '../models/answer_history.dart';
import 'ai_analysis_models.dart';

/// NurAI の AI分析ロジック（ローカル実装）
///
/// - OpenAI API は使わず、解答履歴から統計値を計算して文章を生成する
/// - AnalysisTone によって、同じ分析内容でも文体・ニュアンスを大きく変える
class AiAnalysisService {
  /// 全体または特定分野の AnswerRecord 群を受け取り、
  /// トーンに応じた AiAnalysisResult を返す。
  static Future<AiAnalysisResult> analyzeOverall({
    required List<AnswerRecord> records,
    required AnalysisTone tone,
  }) async {
    if (records.isEmpty) {
      return _buildEmptyResult(tone);
    }

    final total = records.length;
    final correct = records.where((r) => r.isCorrect).length;
    final acc = total == 0 ? 0.0 : correct / total;

    final diffStats = _buildDifficultyStats(records);
    final domainStats = _buildDomainStats(records);

    final intro = _buildIntroMessage(
      tone: tone,
      totalAnswers: total,
      overallAccuracy: acc,
    );

    final difficultyComment = _buildDifficultyComment(
      tone: tone,
      stats: diffStats,
    );

    final domainComment = _buildDomainComment(
      tone: tone,
      stats: domainStats,
    );

    final studyAdvice = _buildStudyAdvice(
      tone: tone,
      totalAnswers: total,
      overallAccuracy: acc,
      diffStats: diffStats,
      domainStats: domainStats,
    );

    final nuraiComment = _buildNuraiComment(
      tone: tone,
      totalAnswers: total,
      overallAccuracy: acc,
    );

    return AiAnalysisResult(
      totalAnswers: total,
      overallAccuracy: acc,
      introMessage: intro,
      difficultyComment: difficultyComment,
      domainComment: domainComment,
      studyAdvice: studyAdvice,
      nuraiComment: nuraiComment,
      difficultyStats: diffStats,
      domainStats: domainStats,
    );
  }

  // ============================================================
  // 統計計算
  // ============================================================

  static List<DifficultyStat> _buildDifficultyStats(
      List<AnswerRecord> records) {
    final Map<String, DifficultyStat> map = <String, DifficultyStat>{};

    void add(String name, bool isCorrect) {
      final current = map[name] ??
          const DifficultyStat(name: '', total: 0, correct: 0);
      final total = current.name.isEmpty ? 0 : current.total;
      final correct0 = current.name.isEmpty ? 0 : current.correct;
      map[name] = DifficultyStat(
        name: name,
        total: total + 1,
        correct: correct0 + (isCorrect ? 1 : 0),
      );
    }

    for (final r in records) {
      final name = (r.difficulty.isEmpty) ? '未分類' : r.difficulty;
      add(name, r.isCorrect);
    }

    // 表示順をある程度固定（必修 → 一般 → 状況設定 → その他）
    final order = ['必修問題', '一般問題', '状況設定問題'];
    final list = map.values.toList();

    list.sort((a, b) {
      final ia = order.indexOf(a.name);
      final ib = order.indexOf(b.name);
      if (ia != -1 && ib != -1) return ia.compareTo(ib);
      if (ia != -1) return -1;
      if (ib != -1) return 1;
      return a.name.compareTo(b.name);
    });

    return list;
  }

  static List<DomainStat> _buildDomainStats(List<AnswerRecord> records) {
    final Map<String, DomainStat> map = <String, DomainStat>{};

    void add(String name, bool isCorrect) {
      final current =
          map[name] ?? const DomainStat(name: '', total: 0, correct: 0);
      final total = current.name.isEmpty ? 0 : current.total;
      final correct0 = current.name.isEmpty ? 0 : current.correct;
      map[name] = DomainStat(
        name: name,
        total: total + 1,
        correct: correct0 + (isCorrect ? 1 : 0),
      );
    }

    for (final r in records) {
      final dom = (r.domain ?? '').trim();
      final name = dom.isEmpty ? '未指定' : dom;
      add(name, r.isCorrect);
    }

    final list = map.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  // ============================================================
  // トーン別：空データ時
  // ============================================================

  static AiAnalysisResult _buildEmptyResult(AnalysisTone tone) {
    String intro;
    String difficulty;
    String domain;
    String advice;
    String comment;

    switch (tone) {
      case AnalysisTone.gentle:
        intro =
        'まだ解答履歴がありません。\n\nまずは気になった分野の問題から、少しずつ解き始めてみましょう。'
            'たとえ数問でも、NurAIはあなたの傾向を丁寧に覚えていきます。';
        difficulty =
        '現時点では、出題形式ごとの傾向を判断するだけのデータが集まっていません。'
            '必修問題・一般問題・状況設定問題をバランスよく解いていくことで、全体像が見えやすくなります。';
        domain =
        '分野別の成績も、まだ判断できるほどの履歴がありません。\n'
            'まずは得意そう・興味があると感じる領域から取り組み、「解きやすい感覚」をつかんでいきましょう。';
        advice =
        '1. 1日1〜2問からでかまいません。学習のハードルを下げて、まずは「NurAIを開く」ことを習慣にしてみてください。\n'
            '2. 正解・不正解よりも、「なぜその選択肢にしたのか」を自分なりに言葉にしてみると、理解が深まりやすくなります。\n'
            '3. 少し慣れてきたら、状況設定問題も混ぜて解いてみましょう。臨床イメージを膨らませる練習にもなります。';
        comment =
        '最初の一歩を踏み出すだけでも、大きな前進です。NurAIは、あなたのペースを大切にしながら、そっと背中を押し続けます。';
        break;

      case AnalysisTone.neutral:
        intro =
        '現時点では、AI分析を行うための解答履歴がまだありません。\n'
            'ある程度の問題数を解くことで、傾向や課題が可視化されていきます。';
        difficulty =
        '出題形式（必修・一般・状況設定）ごとの傾向を評価するには、各形式に一定数の解答が必要です。'
            '今後、複数形式の問題を少しずつ解いていくことで、より精度の高い分析が可能になります。';
        domain =
        '分野別（成人・老年・精神など）の成績も、データ不足のため評価保留です。'
            '複数の領域に触れていくことで、「強み」と「課題」が徐々に見えてきます。';
        advice =
        '1. まずは20問前後を目安に、幅広い分野の問題を解いてみてください。\n'
            '2. 不正解の問題については、解説を読み、なぜ誤ったのかを明確にしておくと次に活かしやすくなります。\n'
            '3. ある程度データが蓄積した段階で、再度AI分析を実行することで、より具体的な学習方針を立てられます。';
        comment =
        '十分なデータが集まるほど、分析の精度は向上します。まずは土台となる解答履歴を蓄積していきましょう。';
        break;

      case AnalysisTone.strict:
        intro =
        'まだ解答履歴がありません。この状態では、学習の傾向も課題も評価できません。'
            'まずは一定量の問題演習を積むことが必須です。';
        difficulty =
        '出題形式別の成績を評価するには、少なくとも各形式で複数問の解答が必要です。'
            '現状では、どの形式が強みでどの形式が弱点か判断できません。';
        domain =
        '分野別の成績も評価不能です。成人・老年・精神など、国家試験の出題範囲を意識しながら、計画的に演習を進めていく必要があります。';
        advice =
        '1. まずは20〜30問を短期間で解き切ることを一つの目標としてください。\n'
            '2. 不正解の問題は必ず見直し、根拠を説明できるレベルまで理解を深めることを徹底しましょう。\n'
            '3. その上でAI分析を実行すると、どの領域をどの程度補強すべきか、より具体的な指針が得られます。';
        comment =
        '学習の出発点は「手を動かすこと」です。まずは問題演習量を確保し、分析に耐えうるデータを蓄積していきましょう。';
        break;

      case AnalysisTone.coach:
        intro =
        'まだ試合（＝問題演習）は始まっていません！\n'
            'でも大丈夫、ここから一緒にウォーミングアップしていきましょう。';
        difficulty =
        '今はまだ、どのポジション（必修・一般・状況設定）が得意か、データが足りず判定できません。'
            'まずはいろいろなポジションを経験して、自分の得意ゾーンを見つけていきましょう。';
        domain =
        '分野別のスタッツも、まだ真っ白なスコアボードの状態です。\n'
            '成人・老年・精神など、少しずつ幅広くボールを投げてみて、「ここは手応えがある」という感覚を探していきましょう。';
        advice =
        '1. まずは肩慣らしとして、1日数問でいいので継続して解いていきましょう。\n'
            '2. ミスした問題は、「どこで判断を誤ったか」を振り返ることで、次の一手が格段に良くなります。\n'
            '3. ある程度データが溜まってきたら、AI分析を走らせて「自分の戦い方の癖」を一緒に確認していきましょう。';
        comment =
        'ここからどれだけ強くなるかは、これからの積み重ね次第です。NurAIは、あなたの専属コーチとしてずっと伴走します。';
        break;

      case AnalysisTone.clinical:
        intro =
        '現時点では、学習状況を評価するためのデータが不足しています。\n'
            '臨床推論と同様に、一定量の情報が揃って初めて、パターンやリスクが見えてきます。';
        difficulty =
        '必修・一般・状況設定といった出題形式ごとの成績は、複数症例に相当するデータが必要です。'
            '現状では、どの形式で判断精度が低下しやすいかを特定できません。';
        domain =
        '領域別（成人・老年・精神など）の成績も、サンプル数不足のため評価保留です。\n'
            '各領域で一定数の問題に触れることで、「知識の抜け」と「臨床イメージの弱さ」がより明確になります。';
        advice =
        '1. まずは基礎データとして、20〜30問程度の解答履歴を蓄積することを目標としてください。\n'
            '2. 不正解の選択肢については、「どの前提や臨床推論が誤っていたのか」を言語化して振り返ることが重要です。\n'
            '3. データが蓄積した段階でAI分析を行うと、領域別・形式別にどこから介入すべきかが明確になります。';
        comment =
        '学習も臨床と同じく、データの蓄積とフィードバックの繰り返しで質が高まります。まずは評価に足るだけのデータを集めていきましょう。';
        break;
    }

    return AiAnalysisResult(
      totalAnswers: 0,
      overallAccuracy: 0.0,
      introMessage: intro,
      difficultyComment: difficulty,
      domainComment: domain,
      studyAdvice: advice,
      nuraiComment: comment,
      difficultyStats: const <DifficultyStat>[],
      domainStats: const <DomainStat>[],
    );
  }

  // ============================================================
  // トーン別：イントロ
  // ============================================================

  static String _buildIntroMessage({
    required AnalysisTone tone,
    required int totalAnswers,
    required double overallAccuracy,
  }) {
    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

    if (totalAnswers < 20) {
      switch (tone) {
        case AnalysisTone.gentle:
          return 'まだ $totalAnswers 問と、ほんのウォーミングアップ段階ですが、すでにNurAIはあなたの解き方のクセを少しずつ学習し始めています。'
              'ここから問題数が増えるほど、より細かい分析ができるようになっていきます。';
        case AnalysisTone.neutral:
          return '現在の解答数は $totalAnswers 問です。全体傾向を語るにはやや少なめですが、初期の傾向を把握するには十分な量が集まりつつあります。';
        case AnalysisTone.strict:
          return '解答数は $totalAnswers 問です。まだ本格的な分析には不十分な量ですが、初期傾向の確認として内容を評価します。'
              '今後はさらに演習量を増やすことが前提になります。';
        case AnalysisTone.coach:
          return 'これまでに $totalAnswers 問チャレンジしましたね。まだゲームは始まったばかりですが、もうスタートラインは切れています。'
              'ここから一緒にペースを上げていきましょう。';
        case AnalysisTone.clinical:
          return '現在のサンプル数は $totalAnswers 問と、統計的には初期データの段階です。'
              'とはいえ、傾向を早期に把握することは、その後の学習戦略を立てる上で有用です。';
      }
    }

    if (totalAnswers < 50) {
      switch (tone) {
        case AnalysisTone.gentle:
          return 'これまでに $totalAnswers 問に取り組んでおり、少しずつ学習の輪郭が見えてきました。'
              '正答率はおおよそ ${pct(overallAccuracy)} 前後で、ここからの伸びしろがたくさん残されている状態です。';
        case AnalysisTone.neutral:
          return '解答数は $totalAnswers 問、総合正答率は概ね ${pct(overallAccuracy)} です。'
              '初期〜中盤の学習フェーズにあり、得意・苦手の輪郭が徐々に形成されつつあります。';
        case AnalysisTone.strict:
          return '現時点での解答数は $totalAnswers 問、総合正答率は ${pct(overallAccuracy)} です。'
              '学習の基盤はできつつありますが、本番水準を意識するなら、ここからさらに量・質ともに引き上げる必要があります。';
        case AnalysisTone.coach:
          return 'すでに $totalAnswers 問こなしています。ここまでの総合正答率は ${pct(overallAccuracy)}。'
              '「基礎を固めるフェーズ」がちょうど終盤に差し掛かっているイメージです。';
        case AnalysisTone.clinical:
          return '解答数 $totalAnswers 問、総合正答率 ${pct(overallAccuracy)} という状況です。'
              'ある程度データが蓄積し、出題形式・分野ごとのパターンが見え始めている段階といえます。';
      }
    }

    // 50問以上
    switch (tone) {
      case AnalysisTone.gentle:
        return 'これまでに $totalAnswers 問もの問題に取り組んでおり、かなりしっかりとした学習履歴が蓄積されています。'
            '総合正答率は ${pct(overallAccuracy)} 前後で、ここからは「弱点の整理」と「仕上げ」の段階に入っていきます。';
      case AnalysisTone.neutral:
        return '解答数は $totalAnswers 問、総合正答率は ${pct(overallAccuracy)} です。'
            'この分量であれば、出題形式・分野別に見たときの強み・弱みもある程度信頼できるレベルで評価できます。';
      case AnalysisTone.strict:
        return '現在 $totalAnswers 問を解き、総合正答率は ${pct(overallAccuracy)} です。'
            'ここまで演習できているのは評価できますが、本番で安定して点数を確保するには、引き続き課題領域への集中的な介入が必要です。';
      case AnalysisTone.coach:
        return '累計 $totalAnswers 問、かなり戦ってきましたね！総合正答率は ${pct(overallAccuracy)}。'
            'ここからは「細かいクセ」を整えていく、仕上げとチューニングのフェーズに入っていきます。';
      case AnalysisTone.clinical:
        return '解答数 $totalAnswers 問、総合正答率 ${pct(overallAccuracy)}。'
            'この規模のデータがあれば、出題形式別・分野別の傾向をある程度信頼できる水準で把握できます。'
            'ここからは、明確になった弱点領域に対して、集中的に介入していくフェーズです。';
    }
  }

  // ============================================================
  // トーン別：出題形式コメント
  // ============================================================

  static String _buildDifficultyComment({
    required AnalysisTone tone,
    required List<DifficultyStat> stats,
  }) {
    if (stats.isEmpty) {
      switch (tone) {
        case AnalysisTone.gentle:
          return 'まだ出題形式ごとの十分なデータはありませんが、これから必修・一般・状況設定をバランスよく解いていくことで、'
              '得意な形式・苦手な形式がはっきりしてきます。';
        case AnalysisTone.neutral:
          return '出題形式別の集計はまだ限定的です。今後、複数の形式に触れていくことで、より明確な傾向が得られます。';
        case AnalysisTone.strict:
          return '出題形式ごとの傾向を評価するにはデータが不足しています。形式に偏りなく演習することが必要です。';
        case AnalysisTone.coach:
          return 'まだどの形式が「得意ポジション」かは判定しきれません。'
              'これから必修・一般・状況設定、いろいろなパターンに挑戦していきましょう。';
        case AnalysisTone.clinical:
          return '出題形式別のデータは限定的であり、統計的な評価には至っていません。'
              '各形式の問題を意識的に組み合わせて解いていくことで、判断傾向がより明瞭になります。';
      }
    }

    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
    final buf = StringBuffer();

    // 一覧
    buf.writeln('【出題形式別の成績】');
    for (final s in stats) {
      buf.writeln(
          '・${s.name}：${pct(s.rate)}（${s.correct} / ${s.total} 問）');
    }
    buf.writeln();

    // ある程度データがある形式のみで強弱を評価
    final eligible = stats.where((s) => s.total >= 5).toList();
    if (eligible.length < 2) {
      // コメントはトーン別に軽く
      switch (tone) {
        case AnalysisTone.gentle:
          buf.writeln('まだ形式ごとの問題数が多くないため、「得意／苦手」と言い切る段階ではありません。'
              '今は「慣れる」ことを大切にしていきましょう。');
          break;
        case AnalysisTone.neutral:
          buf.writeln('問題数が限られているため、出題形式ごとの差は参考程度として扱うのが適切です。');
          break;
        case AnalysisTone.strict:
          buf.writeln('現状のデータからは、出題形式ごとの差を断定することはできません。今後さらに演習量を増やしてください。');
          break;
        case AnalysisTone.coach:
          buf.writeln('まだフォームを固めている段階です。焦らず、いろいろな形式に当たっていきましょう。');
          break;
        case AnalysisTone.clinical:
          buf.writeln('サンプル数が少ないため、形式別の成績差は統計的に十分とはいえません。');
          break;
      }
      return buf.toString().trimRight();
    }

    eligible.sort((a, b) => b.rate.compareTo(a.rate));
    final best = eligible.first;
    final worst = eligible.last;

    switch (tone) {
      case AnalysisTone.gentle:
        buf.writeln('比較的安定しているのは「${best.name}」の問題で、落ち着いて取り組めている印象です。');
        if (best.name != worst.name) {
          buf.writeln('一方で、「${worst.name}」はまだ伸びしろが大きい分野と言えます。'
              '問題文を読む順番や、情報のメモの仕方を工夫してみると、少しずつ感触が変わっていきます。');
        }
        break;

      case AnalysisTone.neutral:
        buf.writeln('成績が相対的に高いのは「${best.name}」、低いのは「${worst.name}」という傾向があります。');
        buf.writeln('特に「${worst.name}」は、読み飛ばしや設問意図の取り違えが起きやすい形式である可能性があります。');
        break;

      case AnalysisTone.strict:
        buf.writeln('「${best.name}」では一定のパフォーマンスが出せていますが、「${worst.name}」では明らかに精度が落ちています。');
        buf.writeln('特に「${worst.name}」については、問題文の読み方と選択肢の比較手順を、意識的にトレーニングし直す必要があります。');
        break;

      case AnalysisTone.coach:
        buf.writeln('今のところ一番戦えているのは「${best.name}」です。ここはあなたの得意レンジと言ってよさそうです。');
        if (best.name != worst.name) {
          buf.writeln('逆に「${worst.name}」は、まだ伸びしろたっぷりのポジションです。'
              'ここを鍛えられれば、全体の底上げにつながっていきます。');
        }
        break;

      case AnalysisTone.clinical:
        buf.writeln('「${best.name}」では比較的安定した判断ができている一方で、「${worst.name}」では判断精度のばらつきが大きい可能性があります。');
        buf.writeln('特に「${worst.name}」は、設問が意図する看護判断のポイントを適切に抽出できているか、意識的に振り返る必要があります。');
        break;
    }

    return buf.toString().trimRight();
  }

  // ============================================================
  // トーン別：分野コメント
  // ============================================================

  static String _buildDomainComment({
    required AnalysisTone tone,
    required List<DomainStat> stats,
  }) {
    if (stats.isEmpty) {
      switch (tone) {
        case AnalysisTone.gentle:
          return '分野ごとのデータはまだ少なめですが、これから解いていく中で、「得意な分野」「少し苦手な分野」が自然と見えてきます。';
        case AnalysisTone.neutral:
          return '分野別の集計はまだ限定的です。複数の領域に触れていくことで、より明確な傾向が得られます。';
        case AnalysisTone.strict:
          return '分野別の成績を評価するには、現時点ではデータが不足しています。計画的に各領域の演習を進めてください。';
        case AnalysisTone.coach:
          return '今はまだ「得意ポジションの分野」ははっきりしていません。これからの試合で、どんどん見えてきます。';
        case AnalysisTone.clinical:
          return '分野別のデータは限られており、領域ごとの強み・弱みを明確化する段階には至っていません。';
      }
    }

    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
    final buf = StringBuffer();

    // 一覧（件数が少ないものも含めて表示）
    buf.writeln('【分野別の成績概要】');
    for (final s in stats) {
      buf.writeln(
          '・${s.name}：${pct(s.rate)}（${s.correct} / ${s.total} 問）');
    }
    buf.writeln();

    // 評価対象（ある程度の問題数がある分野だけ）
    final eligible = stats.where((s) => s.total >= 3).toList();
    if (eligible.length < 2) {
      switch (tone) {
        case AnalysisTone.gentle:
          buf.writeln('まだ各分野での問題数が少なめなので、「これが苦手」と決めつける必要はありません。'
              '興味のある領域から、少しずつ幅を広げていきましょう。');
          break;
        case AnalysisTone.neutral:
          buf.writeln('問題数が少ないため、分野間の差は参考程度として扱うのが適切です。');
          break;
        case AnalysisTone.strict:
          buf.writeln('現時点の分野別成績はサンプル数が不十分であり、強み・弱みの判断材料としては限定的です。');
          break;
        case AnalysisTone.coach:
          buf.writeln('まだデータが少ないので、「ここが苦手だ」と決めつけるには早すぎます。'
              'これからのチャレンジ次第でいくらでも変わっていきます。');
          break;
        case AnalysisTone.clinical:
          buf.writeln('分野別の差は観察段階であり、明確な弱点領域として確定するには症例（データ）の蓄積が必要です。');
          break;
      }
      return buf.toString().trimRight();
    }

    eligible.sort((a, b) => b.rate.compareTo(a.rate));
    final best = eligible.first;
    final worst = eligible.last;

    switch (tone) {
      case AnalysisTone.gentle:
        buf.writeln('特に「${best.name}」は、比較的スムーズに解けている分野です。'
            '自信を持って良い領域なので、この調子を維持していきましょう。');
        buf.writeln();
        buf.writeln('一方で、「${worst.name}」は少し迷いやすい分野かもしれません。'
            '焦らず、基本的な考え方や頻出パターンから、ゆっくり整えていくと安心です。');
        break;

      case AnalysisTone.neutral:
        buf.writeln('分野別に見ると、「${best.name}」の正答率が比較的高く、'
            '「${worst.name}」の正答率が相対的に低くなっています。');
        buf.writeln('特に「${worst.name}」では、基礎知識の整理や、よく出る病態・看護問題の再確認が有効です。');
        break;

      case AnalysisTone.strict:
        buf.writeln('「${best.name}」は一定の得点源として期待できますが、「${worst.name}」は明らかな弱点領域です。');
        buf.writeln('この分野を放置すると、本番での失点リスクが高い状態が続きます。'
            '頻出テーマを中心に、早めに集中的な復習を行うべきです。');
        break;

      case AnalysisTone.coach:
        buf.writeln('「${best.name}」は、かなり良いパフォーマンスが出せている分野です。ここは自信を持って戦っていきましょう。');
        buf.writeln('「${worst.name}」は、まさに伸びしろのかたまりです。ここを底上げできれば、総合力が一段跳ね上がります。');
        break;

      case AnalysisTone.clinical:
        buf.writeln('「${best.name}」では、概ね妥当な判断ができていると考えられます。');
        buf.writeln('一方で「${worst.name}」は、知識の不足や臨床イメージの不足により、判断に迷いが生じやすい領域と推測されます。'
            '頻出疾患・代表的な看護問題に絞って、重点的な補強を行うことが推奨されます。');
        break;
    }

    return buf.toString().trimRight();
  }

  // ============================================================
  // トーン別：これからの学び方
  // ============================================================

  static String _buildStudyAdvice({
    required AnalysisTone tone,
    required int totalAnswers,
    required double overallAccuracy,
    required List<DifficultyStat> diffStats,
    required List<DomainStat> domainStats,
  }) {
    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

    switch (tone) {
      case AnalysisTone.gentle:
        return [
          '1. まずは「苦手かも」と感じる形式や分野を一つだけ決めて、'
              'その領域の問題を数問ずつ、ゆっくり解いてみましょう。',
          '2. 間違えた問題は、「どの部分で迷ったのか」「何が分からなかったのか」を一言メモしておくと、'
              'あとで見返したときに安心して復習できます。',
          '3. 全体の正答率が ${pct(overallAccuracy)} 前後であっても、'
              '少しずつ積み重ねていけば、必ず曲線は右肩上がりになっていきます。'
              '無理のないペースで、NurAIと一緒に続けていきましょう。',
        ].join('\n');

      case AnalysisTone.neutral:
        return [
          '1. 出題形式・分野別の成績を踏まえ、まずは正答率が低い領域から優先的に復習すると効率的です。',
          '2. 不正解の選択肢について、「なぜその選択肢が誤りなのか」を説明できるようにしておくと、類題に対応しやすくなります。',
          '3. 全体の正答率が ${pct(overallAccuracy)} 前後であれば、'
              '引き続き演習量を増やしつつ、定期的にAI分析を走らせて進捗をモニタリングしていくと良いでしょう。',
        ].join('\n');

      case AnalysisTone.strict:
        return [
          '1. まずは正答率の低い形式・分野を明確にし、その領域を集中的に演習してください。'
              '弱点を放置したまま問題数だけ増やしても、得点にはつながりにくくなります。',
          '2. 間違えた問題は、必ずその日のうちに解説を読み込み、'
              '「自分が立てた仮説」と「正しい考え方」のギャップを言語化しておくことが重要です。',
          '3. 現在の総合正答率が ${pct(overallAccuracy)} の場合、'
              '本番レベルを目指すにはまだ改善の余地があります。'
              '計画的に復習範囲を決め、定期的に模試モードで仕上がりを確認していきましょう。',
        ].join('\n');

      case AnalysisTone.coach:
        return [
          '1. まずは「ここが弱点かも」と感じた分野を一つピックアップして、'
              'そこを集中的に鍛える「強化週間」を作ってみましょう。',
          '2. ミスした問題は「ただの失点」ではなく、「次に同じパターンが出たときに確実に取れるポイント」です。'
              '一つひとつのミスが、あなたを強くしています。',
          '3. 今の総合正答率が ${pct(overallAccuracy)} だったとしても、'
              'ここからの伸びしろはまだまだ大きいです。'
              'NurAIと一緒に、小さな一歩を積み重ねていきましょう。'
        ].join('\n');

      case AnalysisTone.clinical:
        return [
          '1. 出題形式・分野別の成績を踏まえ、まずは正答率の低い領域に対して集中的な介入を行うことが合理的です。',
          '2. 不正解の問題では、「必要な情報収集ができていたか」「病態生理を踏まえた判断ができていたか」'
              'といった観点で、臨床推論プロセスを振り返ることが有用です。',
          '3. 総合正答率が ${pct(overallAccuracy)} 前後であれば、'
              '基礎的な知識の定着と、状況設定問題における判断プロセスの明確化を並行して進めることで、'
              '臨床に近いかたちでの実戦力を高めていくことができます。',
        ].join('\n');
    }
  }

  // ============================================================
  // トーン別：NurAI からのひとこと
  // ============================================================

  static String _buildNuraiComment({
    required AnalysisTone tone,
    required int totalAnswers,
    required double overallAccuracy,
  }) {
    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

    switch (tone) {
      case AnalysisTone.gentle:
        if (overallAccuracy >= 0.8) {
          return 'とても安定した正答率（${pct(overallAccuracy)}）です。'
              'ここまで積み重ねてきたことを、どうか自分でもしっかり認めてあげてくださいね。';
        } else if (overallAccuracy >= 0.6) {
          return '着実に力をつけている途中段階です。急激な伸びよりも、「少しずつ前に進んでいる感覚」を大切にしながら進んでいきましょう。';
        } else {
          return '今はまだ伸びしろがたっぷり残っている状態です。'
              '結果よりも、「今日も一問解けた」という事実の方が、ずっと大事だとNurAIは考えています。';
        }

      case AnalysisTone.neutral:
        if (overallAccuracy >= 0.8) {
          return '高い正答率（${pct(overallAccuracy)}）が維持できており、現時点でも十分な実力がうかがえます。'
              '今後はミスのパターンをさらに絞り込むことで、仕上げの精度を高めていけるでしょう。';
        } else if (overallAccuracy >= 0.6) {
          return '基礎的な理解は概ね形成されており、あとは弱点領域をどれだけ効率的に補強できるかが鍵になります。';
        } else {
          return '現時点では正答率 ${pct(overallAccuracy)} と、まだ改善の余地が大きい状態です。'
              'しかし、解答履歴が増えるほど、より精度の高いフィードバックが可能になります。';
        }

      case AnalysisTone.strict:
        if (overallAccuracy >= 0.8) {
          return '現状の正答率 ${pct(overallAccuracy)} は評価できますが、'
              '本番で安定して合格点を確保するには、まだ誤答の原因分析を徹底して行う必要があります。';
        } else if (overallAccuracy >= 0.6) {
          return '正答率 ${pct(overallAccuracy)} は中間的な水準です。'
              'ここから一段階上に行くには、「なんとなく選んだ正解」をなくしていくことが不可欠です。';
        } else {
          return '正答率 ${pct(overallAccuracy)} では、本番での安全圏には届きません。'
              '問題演習の量と質の両方を意識して、学習計画そのものを見直していく必要があります。';
        }

      case AnalysisTone.coach:
        if (overallAccuracy >= 0.8) {
          return 'この正答率（${pct(overallAccuracy)}）は、かなり良いラインに来ています！'
              'あとは細かいミスをどれだけ減らせるかが勝負どころです。一緒にラストスパートをかけていきましょう。';
        } else if (overallAccuracy >= 0.6) {
          return 'ここからが一番伸びやすいゾーンです。悔しいミスを一つずつ潰していけば、スコアはぐっと上がってきます。';
        } else {
          return '今はまだ結果だけを見ると厳しいかもしれませんが、その分だけ伸びしろがあります。'
              '「昨日より一歩前へ」を合言葉に、一緒に積み上げていきましょう。';
        }

      case AnalysisTone.clinical:
        if (overallAccuracy >= 0.8) {
          return '現時点の正答率 ${pct(overallAccuracy)} は、臨床実践においても一定の判断力が期待できる水準です。'
              '今後は、判断根拠をより明確に言語化できるようトレーニングを続けていくと良いでしょう。';
        } else if (overallAccuracy >= 0.6) {
          return '正答率 ${pct(overallAccuracy)} は基礎的な理解が形成されつつある段階です。'
              '臨床場面を意識しながら、「なぜその選択が適切か」を説明できるレベルを目指していきましょう。';
        } else {
          return '正答率 ${pct(overallAccuracy)} という現状は、学習の土台づくりがまだ途上であることを示しています。'
              'しかし、この段階で傾向を把握し、計画的に介入していくことで、今後の伸びは十分期待できます。';
        }
    }
  }
}