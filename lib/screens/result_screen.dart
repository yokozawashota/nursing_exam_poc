// lib/screens/result_screen.dart
import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../widgets/app_buttons.dart';
import '../widgets/result_block.dart';

class ResultScreen extends StatefulWidget {
  final String question;
  final Map<String, String> choices;

  /// 複数対応（単一の場合も1要素で渡る）
  final List<String> selectedAnswers;
  final List<String> correctAnswers;

  final String explanation;
  final Map<String, String>? rationales;

  /// 次の問題を生成（QuestionScreen 側から渡される）
  final VoidCallback onGenerateNext;

  /// メタ（任意）
  final String? difficulty;
  final String? domain;
  final String? major;
  final String? mid;
  final String? topic;

  /// 問題タイプ（'single' | 'multiple' | 'select_incorrect'）
  /// 渡されない場合は 'single' として扱う（後方互換）
  final String? questionKind;

  const ResultScreen({
    super.key,
    required this.question,
    required this.choices,
    required this.selectedAnswers,
    required this.correctAnswers,
    required this.explanation,
    this.rationales,
    required this.onGenerateNext,
    this.difficulty,
    this.domain,
    this.major,
    this.mid,
    this.topic,
    this.questionKind,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showOverlay = false;
  bool _isCorrect = false;

  @override
  void initState() {
    super.initState();
    _isCorrect = _isFullyCorrect();
    _showOverlay = true;

    // 画面描画後にフェードアウトを開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleOverlayHide();
    });
  }

  /// 完全一致方式の正誤判定
  bool _isFullyCorrect() {
    final sel = widget.selectedAnswers.toSet();
    final cor = widget.correctAnswers.toSet();
    if (sel.isEmpty || cor.isEmpty) return false;
    if (sel.length != cor.length) return false;
    return sel.containsAll(cor);
  }

  void _scheduleOverlayHide() async {
    // 表示時間 ＋ フェードアウト時間はお好みで調整可
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _showOverlay = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.questionKind ?? 'single';

    // ★ select_incorrect のときに解説テキストを正しいラベルで補正する
    final normalizedExplanation = _normalizeExplanation(
      explanation: widget.explanation,
      correctAnswers: widget.correctAnswers,
      questionKind: kind,
    );

    return Stack(
      children: [
        BaseScaffold(
          title: '解答結果',
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResultBlock(
                    question: widget.question,
                    choices: widget.choices,
                    selectedAnswers: widget.selectedAnswers,
                    correctAnswers: widget.correctAnswers,
                    explanation: normalizedExplanation,
                    rationales: widget.rationales,
                    questionKind: kind,
                  ),
                  const SizedBox(height: 20),

                  // 次の問題
                  SizedBox(
                    width: double.infinity,
                    child: AppButtons.success(
                      label: '次の問題を生成',
                      icon: Icons.refresh,
                      onPressed: () {
                        widget.onGenerateNext();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 出題に戻る
                  SizedBox(
                    width: double.infinity,
                    child: AppButtons.primary(
                      label: '出題に戻る',
                      icon: Icons.arrow_back,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 正解 / 不正解 オーバーレイ
        _buildResultOverlay(context),
      ],
    );
  }

  /// 正解 / 不正解 を大きく表示するオーバーレイ
  Widget _buildResultOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final color = _isCorrect ? Colors.green.shade600 : Colors.red.shade600;
    final symbol = _isCorrect ? '◯' : '✕';
    final label = _isCorrect ? '正解！' : '不正解';

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _showOverlay ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 600),
        child: Container(
          color: Colors.black.withOpacity(0.10),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ★ 下線の原因をなくすため TextHeightBehavior を指定
              RichText(
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                text: TextSpan(
                  text: symbol,
                  style: TextStyle(
                    fontSize: 130,
                    fontWeight: FontWeight.w900,
                    height: 0.8,              // ★ 行間をさらに詰める
                    color: color,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// explanation の整形
  ///
  /// - select_incorrect のときだけ、
  ///   「選択肢CとDが誤った記述です。」などの一文を先頭に挿入（or 置き換え）して
  ///   correctAnswers と必ず整合するようにする。
  String _normalizeExplanation({
    required String explanation,
    required List<String> correctAnswers,
    required String questionKind,
  }) {
    final trimmed = explanation.trim();
    if (trimmed.isEmpty) return '';

    if (questionKind != 'select_incorrect') {
      // 単純な正答問題（single / multiple）はそのまま使う
      return trimmed;
    }

    // 正しいラベル群（A, B, ...）をソートして結合
    final labels = correctAnswers.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
      ..sort();
    if (labels.isEmpty) return trimmed;

    final joined = _labelsToJoined(labels);
    final head = '選択肢$joinedが誤った記述です。';

    // もし先頭の一文が「選択肢○と△は誤った記述です」系なら、それを差し替え
    final firstPeriodIndex = trimmed.indexOf('。');
    if (firstPeriodIndex >= 0) {
      final firstSentence = trimmed.substring(0, firstPeriodIndex + 1);
      final rest = trimmed.substring(firstPeriodIndex + 1).trimLeft();

      if (firstSentence.contains('選択肢') &&
          (firstSentence.contains('誤った') ||
              firstSentence.contains('誤り') ||
              firstSentence.contains('誤っている'))) {
        // 先頭文を head に差し替え
        if (rest.isEmpty) {
          return head;
        }
        return '$head$rest';
      } else {
        // 先頭文が別物なら、head を前に足す
        return '$head$trimmed';
      }
    } else {
      // 句点が無ければ単純に前置
      return '$head$trimmed';
    }
  }

  /// ラベル配列を「A」「AとB」「A、BとC」形式に連結
  String _labelsToJoined(List<String> labels) {
    if (labels.isEmpty) return '';
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels[0]}と${labels[1]}';
    final head = labels.sublist(0, labels.length - 1).join('、');
    return '$headと${labels.last}';
  }
}