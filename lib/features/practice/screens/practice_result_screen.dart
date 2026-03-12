// lib/features/practice/screens/practice_result_screen.dart

import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/base_scaffold.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../utils/practice_result_formatter.dart';
import '../widgets/practice_result_block.dart';

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

  late final ConfettiController _leftConfettiController;
  late final ConfettiController _rightConfettiController;

  @override
  void initState() {
    super.initState();

    _leftConfettiController = ConfettiController(
      duration: const Duration(milliseconds: 1200),
    );
    _rightConfettiController = ConfettiController(
      duration: const Duration(milliseconds: 1200),
    );

    _isCorrect = _isFullyCorrect();
    _showOverlay = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isCorrect) {
        _leftConfettiController.play();
        _rightConfettiController.play();
      }
      _scheduleOverlayHide();
    });
  }

  @override
  void dispose() {
    _leftConfettiController.dispose();
    _rightConfettiController.dispose();
    super.dispose();
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
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _showOverlay = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.questionKind ?? 'single';

    final normalizedExplanation = PracticeResultFormatter.normalizeExplanation(
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

        _buildResultOverlay(context),
        if (_isCorrect) _buildConfettiLayer(),
      ],
    );
  }

  Widget _buildConfettiLayer() {
    return IgnorePointer(
      child: Stack(
        children: [
          // 左側クラッカー
          Align(
            alignment: const Alignment(-0.6, -0.15), // ← 発射位置を上げる
            child: ConfettiWidget(
              confettiController: _leftConfettiController,
              blastDirection: -pi / 4, // 右上
              emissionFrequency: 0.01,
              numberOfParticles: 30, // ← 粒増やす
              maxBlastForce: 45, // ← 強く吹き出す
              minBlastForce: 28,
              gravity: 0.45, // ← 落ちる感じ強化
              shouldLoop: false,
              blastDirectionality: BlastDirectionality.directional,
            ),
          ),

          // 右側クラッカー
          Align(
            alignment: const Alignment(0.6, -0.15), // ← 発射位置を上げる
            child: ConfettiWidget(
              confettiController: _rightConfettiController,
              blastDirection: -3 * pi / 4, // 左上
              emissionFrequency: 0.01,
              numberOfParticles: 30,
              maxBlastForce: 45,
              minBlastForce: 28,
              gravity: 0.45,
              shouldLoop: false,
              blastDirectionality: BlastDirectionality.directional,
            ),
          ),
        ],
      ),
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
                    height: 0.8,
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
}