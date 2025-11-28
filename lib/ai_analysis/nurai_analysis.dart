// lib/ai_analysis/nurai_analysis.dart
import '../models/answer_history.dart';

/// 正答率（0.0〜1.0）
double accuracyOf(List<AnswerRecord> items) {
  if (items.isEmpty) return 0.0;
  final correct = items.where((r) => r.isCorrect).length;
  return correct / items.length;
}

Map<String, double> accuracyByDifficulty(List<AnswerRecord> items) {
  final map = <String, List<AnswerRecord>>{};
  for (final r in items) {
    map.putIfAbsent(r.difficulty, () => <AnswerRecord>[]).add(r);
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
    (r.domain == null || r.domain!.isEmpty) ? '未指定' : r.domain!;
    map.putIfAbsent(dom, () => <AnswerRecord>[]).add(r);
  }
  final out = <String, double>{};
  map.forEach((k, v) {
    out[k] = accuracyOf(v);
  });
  return out;
}

/// NurAI が表示する長文の分析レポート
String buildNuraiAnalysisText(List<AnswerRecord> items) {
  if (items.isEmpty) {
    return 'まだ解答履歴がありません。\n\nまずは何問か問題を解いて、NurAIにあなたの「クセ」を覚えさせましょう。';
  }

  final total = items.length;
  final accAll = accuracyOf(items);
  final now = DateTime.now();

  // 直近30問・直近7日など
  final recent30 = items.take(30).toList();
  final accRecent30 = accuracyOf(recent30);

  final from7d = now.subtract(const Duration(days: 7));
  final recent7d = items.where((r) => r.ts.isAfter(from7d)).toList();
  final accRecent7d = accuracyOf(recent7d);

  final byDiff = accuracyByDifficulty(items);
  final byDom = accuracyByDomain(items);

  // 得意・苦手分野（ドメイン）
  final domainEntries = byDom.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final bestDomains = domainEntries.take(2).toList();
  final worstDomains =
  domainEntries.reversed.take(2).toList().reversed.toList();

  String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  final buffer = StringBuffer();

  // ① コンセプトメッセージ
  buffer.writeln('NurAIのAI分析は、あなたが解いた問題の履歴から「得意」と「苦手」のパターンを学習し続ける、育成型コーチです。');
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
  if (byDiff.isNotEmpty) {
    buffer.writeln('【出題形式ごとの傾向】');
    const order = ['必修問題', '一般問題', '状況設定問題'];
    final keys = [
      ...order.where((k) => byDiff.containsKey(k)),
      ...byDiff.keys.where((k) => !order.contains(k)),
    ];
    for (final k in keys) {
      final v = byDiff[k]!;
      buffer.writeln('・$k：${pct(v)}');
    }
    buffer.writeln();
  }

  // ④ 分野別の強み・弱み
  if (domainEntries.length >= 2) {
    buffer.writeln('【分野別の強みと課題】');

    if (bestDomains.isNotEmpty) {
      buffer.writeln('■ 比較的得意な分野');
      for (final e in bestDomains) {
        buffer.writeln('・${e.key}：${pct(e.value)}');
      }
    }

    if (worstDomains.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('■ 集中して伸ばしたい分野');
      for (final e in worstDomains) {
        buffer.writeln('・${e.key}：${pct(e.value)}');
      }
    }
    buffer.writeln();
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
        'かなり高い正答率です。この調子なら、本番に向けて「抜け漏れを埋める仕上げフェーズ」に入っていけそうです。難易度の高い問題にも挑戦してみましょう。');
  } else if (accAll >= 0.6) {
    buffer.writeln(
        '着実に力がついてきています。あと一歩伸ばすには、間違えた問題の振り返りと、状況設定問題への慣れが鍵になりそうです。');
  } else {
    buffer.writeln(
        'まだ伸びしろがたくさんある状態です。最初は正答率よりも「毎日触ること」を大事にしていきましょう。NurAIは、あなたが解けば解くほど、あなたのパターンを学習して賢くなっていきます。');
  }

  return buffer.toString();
}