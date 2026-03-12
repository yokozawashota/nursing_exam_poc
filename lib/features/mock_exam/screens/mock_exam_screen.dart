// lib/features/mock_exam/screens/mock_exam_screen.dart
import 'package:flutter/material.dart';

import '../../../shared/widgets/base_scaffold.dart';
import '../logic/mock_exam_controller.dart';
import '../screens/mock_exam_result_screen.dart';
import '../widgets/mock_exam_header.dart';
import '../widgets/mock_exam_loading_view.dart';
import '../widgets/mock_exam_question_view.dart';

class MockExamScreen extends StatefulWidget {
  const MockExamScreen({
    super.key,
    required this.questionCount,
    required this.examType,
    this.timeLimitMinutes = 0,
  });

  final int questionCount;
  final String examType;
  final int timeLimitMinutes;

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  late final MockExamController _controller;
  bool _hasNavigatedToResult = false;

  @override
  void initState() {
    super.initState();
    _controller = MockExamController(
      questionCount: widget.questionCount,
      examType: widget.examType,
      timeLimitMinutes: widget.timeLimitMinutes,
    );
    _controller.addListener(_handleControllerChanged);
    _controller.start();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;

    if (_controller.finished) {
      if (_hasNavigatedToResult) return;
      _hasNavigatedToResult = true;

      final result = _controller.buildResultData();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MockExamResultScreen(
              records: result.records,
              totalPlanned: result.totalPlanned,
              answeredCount: result.answeredCount,
              correctCount: result.correctCount,
              usedSeconds: result.usedSeconds,
              timeLimitSeconds: result.timeLimitSeconds,
              finishedByTimeout: result.finishedByTimeout,
            ),
          ),
        );
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _submitCurrent() async {
    try {
      await _controller.submitCurrent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  String _formatTime(int sec) {
    if (sec < 0) sec = 0;
    final m = sec ~/ 60;
    final s = sec % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _modeLabel() {
    switch (widget.examType) {
      case 'hisshu':
        return '必修のみ';
      case 'ippan':
        return '一般のみ';
      case 'jokyo':
        return '状況設定のみ';
      case 'mix':
      default:
        return '総合（ミックス）';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTimeLimit = _controller.hasTimeLimit;
    final progressTime = (!hasTimeLimit || _controller.totalSeconds == 0)
        ? 0.0
        : (1.0 - _controller.remainingSeconds / _controller.totalSeconds)
        .clamp(0.0, 1.0);

    final title =
        '模試 (${_controller.currentIndex + 1} / ${widget.questionCount})';

    return BaseScaffold(
      title: title,
      showBack: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MockExamHeader(
                modeLabel: _modeLabel(),
                currentIndex: _controller.currentIndex,
                questionCount: widget.questionCount,
                hasTimeLimit: hasTimeLimit,
                remainingSecondsText:
                _formatTime(_controller.remainingSeconds),
                progressTime: progressTime,
              ),
              Expanded(
                child: _controller.isLoading && _controller.questionText == null
                    ? const MockExamLoadingView()
                    : MockExamQuestionView(
                  questionText: _controller.questionText,
                  choices: _controller.choices,
                  questionKind: _controller.questionKind,
                  isMulti: _controller.isMulti,
                  userAnswers: _controller.userAnswers,
                  onSelectSingle: (val) =>
                      _controller.selectSingle(val),
                  onToggleMultiple: (val) =>
                      _controller.toggleMultiple(val),
                  onSubmit: _submitCurrent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}