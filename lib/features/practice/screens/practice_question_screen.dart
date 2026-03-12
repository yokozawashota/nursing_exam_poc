// lib/features/practice/screens/practice_question_screen.dart

import 'package:flutter/material.dart';

import '../../../shared/widgets/base_scaffold.dart';

import '../logic/practice_question_controller.dart';
import '../widgets/practice_loading_card.dart';
import '../widgets/practice_question_controls.dart';
import '../widgets/practice_question_view.dart';

import '../../../questioning/repositories/category_repository.dart';
import '../../../data/categories.dart';

import 'practice_result_screen.dart';

// ランダム指定用の内部ID
const String kRandomDomainId = '__RANDOM_DOMAIN__';
const String kRandomMajorId = '__RANDOM_MAJOR__';

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  final PracticeQuestionController _controller = PracticeQuestionController();

  static const String modeSituational = '状況設定問題';

  List<String> get hisshuMajorItems => CategoryRepository.hisshuMajorItems();

  static const Map<String, String> _scenarioAspects = {
    'A': 'A. 対象や家族に切れ目のない支援を提供するための継続した看護',
    'B': 'B. 複合的な状況にある対象や、複合的に提供されている看護の状況を判断し、危険を回避する取組み',
    'C': 'C. 看護の提供者が、看護場面において自身の安全を確保するための総合的な判断や対応',
    'D': 'D. 発災からの経過に応じて被災者に提供されている診療や支援を促進するための看護',
    'E': 'E. A～Dを促進するための多職種連携',
  };

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _controller.initialize();
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generateQuestion() async {
    setState(() {
      _controller.state.isLoading = true;
      _controller.state.clearQuestion();
      _controller.clearAnswers();
      _controller.state.loadingMessageIndex = 0;
      _controller.state.loadingProgress = 0;
    });

    _controller.startLoadingUi();

    try {
      final data = await _controller.generateQuestion(
        mode: _controller.state.mode,
        selectedDomain: _controller.state.selectedDomain,
        selectedMajor: _controller.state.selectedMajor,
        selectedMid: _controller.state.selectedMid,
        useMid: _controller.state.useMid,
        hisshuMajor: _controller.state.selectedHisshuMajor,
        scenarioAspect: _controller.state.selectedScenarioAspectCode,
      );

      await _controller.completeLoadingAndWait();

      if (!mounted) return;

      setState(() {
        _controller.state.questionText =
            (data['question'] as String?)?.trim();

        final rawChoices = data['choices'] as Map?;
        _controller.state.choices =
            rawChoices?.map((k, v) => MapEntry(k.toString(), v.toString()));

        _controller.state.correctAnswers =
            (data['correctAnswers'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
                [(data['correct'] ?? '').toString()];

        _controller.state.questionKind =
            (data['questionKind'] as String?) ?? 'single';

        _controller.state.explanation =
            (data['explanation'] as String?) ?? '';

        final rawRat = data['rationales'] as Map?;
        _controller.state.rationales =
            rawRat?.map((k, v) => MapEntry(k.toString(), v.toString()));

        final rawMeta = data['meta'] as Map?;
        _controller.state.meta =
            rawMeta?.map((k, v) => MapEntry(k.toString(), v));

        _controller.state.isLoading = false;
      });
    } catch (e) {
      _controller.stopLoadingUi();

      if (!mounted) return;

      setState(() {
        _controller.state.isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('問題の生成に失敗しました：$e')),
      );
    }
  }

  Future<void> _submitAnswer() async {
    if (_controller.state.questionText == null ||
        _controller.state.choices == null ||
        _controller.state.correctAnswers == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題を生成してから解答してください。')),
      );
      return;
    }

    if (_controller.state.userAnswers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('選択肢を選んでください。')),
      );
      return;
    }

    try {
      await _controller.saveAnswer(
        difficulty: _controller.state.mode,
        question: _controller.state.questionText!,
        choices: _controller.state.choices!,
        correctAnswers: _controller.state.correctAnswers!,
        questionKind: _controller.state.questionKind,
        explanation: _controller.state.explanation,
        rationales: _controller.state.rationales,
        meta: _controller.state.meta,
        selectedDomain: _controller.state.selectedDomain,
        selectedMajor: _controller.state.selectedMajor,
        selectedMid: _controller.state.selectedMid,
        useMid: _controller.state.useMid,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('履歴の保存に失敗しました：$e')),
        );
      }
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          question: _controller.state.questionText!,
          choices: _controller.state.choices!,
          selectedAnswers: _controller.state.userAnswers.toList(),
          correctAnswers: _controller.state.correctAnswers!,
          explanation: _controller.state.explanation ?? '',
          rationales: _controller.state.rationales,
          onGenerateNext: _generateQuestion,
          difficulty: _controller.state.mode,
          domain: _controller.state.meta?['domain'] as String?,
          major: _controller.state.meta?['major'] as String?,
          mid: _controller.state.meta?['mid'] as String?,
          topic: _controller.state.meta?['topic'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final domainList = _controller.state.mode == modeSituational
        ? situationalDomains
        : CategoryRepository.generalDomains();

    return BaseScaffold(
      title: '出題',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QuestionControls(
                mode: _controller.state.mode,
                onModeChanged: (val) {
                  setState(() {
                    _controller.handleModeChanged(val);
                  });
                },
                isLoading: false,
                onGeneratePressed: _generateQuestion,
                domainItems: domainList,
                selectedDomain: _controller.state.selectedDomain,
                onDomainChanged: (val) {
                  setState(() {
                    _controller.handleDomainChanged(val);
                  });
                },
                majorItems: CategoryRepository.generalMajorsOf(
                  _controller.state.selectedDomain,
                ),
                selectedMajor: _controller.state.selectedMajor,
                onMajorChanged: (val) {
                  setState(() {
                    _controller.handleMajorChanged(val);
                  });
                },
                useMid: _controller.state.useMid,
                onUseMidChanged: (v) {
                  setState(() {
                    _controller.handleUseMidChanged(v);
                  });
                },
                midItems: CategoryRepository.generalMidsOf(
                  _controller.state.selectedDomain,
                  _controller.state.selectedMajor,
                ),
                selectedMid: _controller.state.selectedMid,
                onMidChanged: (val) {
                  setState(() {
                    _controller.handleMidChanged(val);
                  });
                },
                hisshuMajorItems: hisshuMajorItems,
                selectedHisshuMajor: _controller.state.selectedHisshuMajor,
                onHisshuMajorChanged: (val) {
                  setState(() {
                    _controller.handleHisshuMajorChanged(val);
                  });
                },
                scenarioAspects: _scenarioAspects,
                selectedScenarioAspectCode:
                _controller.state.selectedScenarioAspectCode,
                onScenarioAspectChanged: (val) {
                  setState(() {
                    _controller.handleScenarioAspectChanged(val);
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_controller.state.isLoading)
                PracticeLoadingCard(
                  message: PracticeQuestionController.loadingMessages[
                  _controller.state.loadingMessageIndex.clamp(
                    0,
                    PracticeQuestionController.loadingMessages.length - 1,
                  )],
                  progress: _controller.state.loadingProgress,
                ),
              if (_controller.state.questionText != null &&
                  _controller.state.choices != null)
                PracticeQuestionView(
                  questionText: _controller.state.questionText!,
                  choices: _controller.state.choices!,
                  questionKind: _controller.state.questionKind,
                  selectedAnswers: _controller.state.userAnswers.toList(),
                  onSelectSingle: (val) {
                    _controller.selectSingle(val);
                    setState(() {});
                  },
                  onToggleMultiple: (val) {
                    _controller.toggleMultiple(val);
                    setState(() {});
                  },
                  onSubmit: _submitAnswer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}