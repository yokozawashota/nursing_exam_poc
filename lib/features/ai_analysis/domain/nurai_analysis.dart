// lib/features/ai_analysis/utils/nurai_analysis.dart
import 'package:nursing_exam_poc/features/history/services/history_answer_service.dart';

/// 正答率（0.0〜1.0）
double accuracyOf(List<AnswerRecord> items) {
  if (items.isEmpty) return 0.0;
  final correct = items.where((r) => r.isCorrect).length;
  return correct / items.length;
}

Map<String, double> accuracyByDifficulty(List<AnswerRecord> items) {
  final map = <String, List<AnswerRecord>>{};
  for (final r in items) {
    final key = (r.difficulty.isEmpty) ? '未分類' : r.difficulty;
    map.putIfAbsent(key, () => <AnswerRecord>[]).add(r);
  }
  final out = <String, double>{};
  map.forEach((k, v) {
    out[k] = accuracyOf(v);
  });
  return out;
}

Map<String, double> accuracyByDomain(List<AnswerRecord> items) {
  final map = <String, List<AnswerRecord>>{};
  for (final r in items) {
    final dom =
    (r.domain == null || r.domain!.isEmpty) ? '未指定' : r.domain!.trim();
    map.putIfAbsent(dom, () => <AnswerRecord>[]).add(r);
  }
  final out = <String, double>{};
  map.forEach((k, v) {
    out[k] = accuracyOf(v);
  });
  return out;
}

/// NurAI が表示する長文の分析レポート
///
/// ※ここは「必ずコメントを出す」仕様にしている。
///   データが足りない場合は、あと何問くらい必要かも出す。
String buildNuraiAnalysisText(List<AnswerRecord> items) {
  if (items.isEmpty) {
    return 'まだ解答履歴がありません。\n\n'
        'まずは何問か問題を解いて、NurAIにあなたの「クセ」を覚えさせましょう。';
  }

  const minPerDifficulty = 5; // 形式別の比較にほしい件数
  const minPerDomain = 3; // 分野別の比較にほしい件数

  final total = items.length;
  final accAll = accuracyOf(items);
  final now = DateTime.now();

  // 直近30問・直近7日など
  final recent30 = items.take(30).toList();
  final accRecent30 = accuracyOf(recent30);

  final from7d = now.subtract(const Duration(days: 7));
  final recent7d = items.where((r) => r.ts.isAfter(from7d)).toList();
  final accRecent7d = accuracyOf(recent7d);

  // 形式別・分野別の正答率
  final byDiff = accuracyByDifficulty(items);
  final byDom = accuracyByDomain(items);

  // 件数カウント（コメント用）
  final countByDiff = <String, int>{};
  final countByDom = <String, int>{};

  for (final r in items) {
    final d = (r.difficulty.isEmpty) ? '未分類' : r.difficulty;
    countByDiff[d] = (countByDiff[d] ?? 0) + 1;

    final dom =
    (r.domain == null || r.domain!.isEmpty) ? '未指定' : r.domain!.trim();
    countByDom[dom] = (countByDom[dom] ?? 0) + 1;
  }

  // 得意・苦手分野（ドメイン）
  final domainEntries = byDom.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final bestDomains = domainEntries.take(2).toList();
  final worstDomains =
  domainEntries.reversed.take(2).toList().reversed.toList();

  String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  final buffer = StringBuffer();

  // ① コンセプトメッセージ
  buffer.writeln(
      'NurAIのAI分析は、あなたが解いた問題の履歴から「得意」と「苦手」のパターンを学習し続ける、育成型コーチです。');
  buffer.writeln('解けば解くほど、NurAIはあなた専用の先生として賢くなっていきます。');
  buffer.writeln();

  // ② 全体の振り返り
  buffer.writeln('【全体のようす】');
  buffer.writeln('・これまでの解答数：$total 問');
  buffer.writeln('・総合正答率　　　：${pct(accAll)}');

  if (recent30.length >= 10) {
    buffer.writeln('・直近30問の正答率：${pct(accRecent30)}');
  }
  if (recent7d.length >= 10) {
    buffer.writeln('・直近7日間の正答率：${pct(accRecent7d)}');
  }

  if (recent7d.length >= 10) {
    if (accRecent7d > accAll + 0.05) {
      buffer.writeln('→ 直近は全体よりも正答率が高く、良いペースで成長しています。');
    } else if (accRecent7d < accAll - 0.05) {
      buffer.writeln('→ 直近は少し調子を崩し気味かもしれません。焦らず復習中心で立て直しましょう。');
    } else {
      buffer.writeln('→ 直近の成績は全体と同程度で、安定した状態です。');
    }
  }
  buffer.writeln();

  // ③ 出題形式別
  buffer.writeln('【出題形式ごとの傾向】');

  if (byDiff.isEmpty) {
    buffer.writeln('まだ出題形式ごとのデータが十分ではありません。'
        '必修・一般・状況設定をバランスよく解いていくと、形式ごとの得意・不得意が見えてきます。');
    buffer.writeln();
  } else {
    buffer.writeln('【出題形式別の成績】');

    const order = ['必修問題', '一般問題', '状況設定問題'];
    final keys = [
      ...order.where((k) => byDiff.containsKey(k)),
      ...byDiff.keys.where((k) => !order.contains(k)),
    ];

    for (final k in keys) {
      final v = byDiff[k]!;
      final c = countByDiff[k] ?? 0;
      buffer.writeln('・$k：${pct(v)}（$c 問）');
    }
    buffer.writeln();

    // 形式ごとの比較コメント
    final eligibleDiffs = keys
        .where((k) => (countByDiff[k] ?? 0) >= minPerDifficulty)
        .toList();

    if (eligibleDiffs.length >= 2) {
      eligibleDiffs.sort(
            (a, b) => byDiff[b]!.compareTo(byDiff[a]!),
      );
      final bestKey = eligibleDiffs.first;
      final worstKey = eligibleDiffs.last;

      buffer.writeln(
          '今のところ一番戦えているのは「$bestKey」で、この形式はかなり安定して得点できています。');
      if (bestKey != worstKey) {
        buffer.writeln(
            '逆に「$worstKey」は、まだ伸びしろたっぷりのポジションです。ここを鍛えられれば、全体の底上げにつながっていきます。');
      }
    } else {
      // データ不足の場合は、具体的にあと何問かを書く
      buffer.writeln(
          '出題形式ごとの差をはっきり評価するには、各形式少なくとも $minPerDifficulty 問程度のデータがあると安心です。');
      buffer.writeln('いまのところ、次の形式でデータがやや不足しています：');
      for (final k in keys) {
        final c = countByDiff[k] ?? 0;
        final need = (minPerDifficulty - c).clamp(0, minPerDifficulty);
        if (need > 0) {
          buffer.writeln('・$k：あと $need 問 ほど解くと傾向が見えやすくなります。');
        }
      }
    }
    buffer.writeln();
  }

  // ④ 分野別の強み・弱み
  buffer.writeln('【分野別の強みと課題】');

  if (domainEntries.isEmpty) {
    buffer.writeln('まだ分野情報つきの問題がほとんど無いため、「どの分野が得意か／苦手か」を評価できる段階ではありません。');
    buffer.writeln(
        '今後、成人・老年・精神など、複数の領域の問題を解いていくことで、分野ごとの傾向が見えてきます。');
    buffer.writeln();
  } else {
    buffer.writeln('【分野別の成績概要】');
    for (final e in domainEntries) {
      final c = countByDom[e.key] ?? 0;
      buffer.writeln('・${e.key}：${pct(e.value)}（$c 問）');
    }
    buffer.writeln();

    // 比較に使える分野（ある程度の問題数があるもの）
    final eligibleDomains = domainEntries
        .where((e) => (countByDom[e.key] ?? 0) >= minPerDomain)
        .toList();

    if (eligibleDomains.length >= 2) {
      eligibleDomains.sort((a, b) => b.value.compareTo(a.value));
      final best = eligibleDomains.first;
      final worst = eligibleDomains.last;

      buffer.writeln('■ 比較的得意な分野');
      buffer.writeln(
          '・${best.key}：${pct(best.value)}（${countByDom[best.key] ?? 0} 問）');
      buffer.writeln(
          '　→ この分野はかなり安定して得点できており、自信を持って良い領域です。');
      buffer.writeln();

      buffer.writeln('■ 集中して伸ばしたい分野');
      buffer.writeln(
          '・${worst.key}：${pct(worst.value)}（${countByDom[worst.key] ?? 0} 問）');
      buffer.writeln(
          '　→ 迷いやすいパターンが残っている可能性があります。頻出テーマを中心に、基礎の整理と解き直しをしておくと安心です。');
      buffer.writeln();
    } else {
      // 分野はあるが、件数や分野数が足りないとき
      buffer.writeln(
          '分野ごとの強み・課題をはっきり評価するには、1つの分野につき少なくとも $minPerDomain 問程度、'
              'かつ2つ以上の分野でデータがあると安心です。');
      buffer.writeln('現在の不足状況の目安は次のとおりです：');

      for (final e in domainEntries) {
        final c = countByDom[e.key] ?? 0;
        final need = (minPerDomain - c).clamp(0, minPerDomain);
        if (need > 0) {
          buffer.writeln('・${e.key}：あと $need 問 ほど解くと傾向が見えやすくなります。');
        }
      }

      if (domainEntries.length < 2) {
        buffer.writeln(
            'また、現時点では分野のバリエーション自体も少なめです。別の領域の問題にも少しずつ触れてみると、全体像がつかみやすくなります。');
      }
      buffer.writeln();
    }
  }

  // ⑤ これからの学び方の提案
  buffer.writeln('【これからの学び方の提案】');
  if (worstDomains.isNotEmpty) {
    buffer.writeln('1. まずは「${worstDomains.first.key}」を優先して復習しましょう。');
    buffer.writeln('   ・スコア画面から、該当分野の問題だけを解き直すのがおすすめです。');
  } else {
    buffer.writeln('1. まずは苦手分野を見つけるために、さまざまな分野の問題をバランスよく解いてみましょう。');
  }

  if (byDiff['状況設定問題'] != null &&
      byDiff['状況設定問題']! < accAll - 0.05) {
    buffer.writeln(
        '2. 状況設定問題は臨床イメージが重要です。慌てず文章を区切って読み、「誰が」「いつ」「どこで」「何に困っているか」を整理してから選択肢を見る練習をしてみてください。');
  } else {
    buffer.writeln(
        '2. 本番に近い形でトレーニングしたい場合は、「模試モード」で連続して解く練習も取り入れてみましょう。');
  }

  buffer.writeln(
      '3. 正解した問題も、理由を説明できるか自分に問いかけてみてください。説明できない正解は、たまたま当たった可能性があります。');
  buffer.writeln();

  // ⑥ NurAI からの一言
  buffer.writeln('【NurAIからのひとこと】');
  if (accAll >= 0.8) {
    buffer.writeln(
        'かなり高い正答率です。この調子なら、本番に向けて「抜け漏れを埋める仕上げフェーズ」に入っていけそうです。'
            '難易度の高い問題にも挑戦してみましょう。');
  } else if (accAll >= 0.6) {
    buffer.writeln(
        '着実に力がついてきています。あと一歩伸ばすには、間違えた問題の振り返りと、状況設定問題への慣れが鍵になりそうです。');
  } else {
    buffer.writeln(
        'まだ伸びしろがたくさんある状態です。最初は正答率よりも「毎日触ること」を大事にしていきましょう。'
            'NurAIは、あなたが解けば解くほど、あなたのパターンを学習して賢くなっていきます。');
  }

  return buffer.toString();
}