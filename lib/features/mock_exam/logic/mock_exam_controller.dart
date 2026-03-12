// lib/features/mock_exam/logic/mock_exam_controller.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../questioning/engine/question_engine.dart';
import '../../history/services/history_answer_service.dart';
import '../models/mock_exam_result_data.dart';
import '../models/mock_exam_state.dart';
import 'mock_exam_planner.dart';
import 'mock_exam_prefetch_controller.dart';

class MockExamController extends ChangeNotifier {
  MockExamController({
    required this.questionCount,
    required this.examType,
    required this.timeLimitMinutes,
  }) : _rand = Random(DateTime.now().microsecondsSinceEpoch) {
    _totalSeconds = timeLimitMinutes * 60;
    _remainingSeconds = _totalSeconds;
  }

  final int questionCount;
  final String examType;
  final int timeLimitMinutes;

  final MockExamPrefetchController _prefetchController =
  MockExamPrefetchController();
  final Random _rand;

  final MockExamState state = MockExamState();

  late final int _totalSeconds;
  Timer? _timer;

  int _currentIndex = 0;
  bool _finished = false;
  bool _finishedByTimeout = false;
  int _remainingSeconds = 0;

  final List<AnswerRecord> _records = [];

  int get currentIndex => _currentIndex;
  bool get finished => _finished;
  bool get finishedByTimeout => _finishedByTimeout;
  int get totalSeconds => _totalSeconds;
  int get remainingSeconds => _remainingSeconds;

  bool get isLoading => state.isLoading;

  String? get questionText => state.questionText;
  Map<String, String>? get choices => state.choices;
  List<String>? get correctAnswers => state.correctAnswers;
  String? get explanation => state.explanation;
  Map<String, String>? get rationales => state.rationales;
  Set<String> get userAnswers => state.userAnswers;
  String get questionKind => state.questionKind;
  Map<String, dynamic>? get meta => state.meta;

  List<AnswerRecord> get records => List.unmodifiable(_records);

  bool get hasTimeLimit => _totalSeconds > 0;

  bool get isMulti =>
      state.questionKind == 'multiple' ||
          state.questionKind == 'select_incorrect' ||
          (state.correctAnswers?.length ?? 0) >= 2;

  void start() {
    if (_totalSeconds > 0) {
      _startTimer();
    }
    loadCurrentQuestionFirst();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _prefetchController.dispose();
    super.dispose();
  }

  void selectSingle(String value) {
    state.userAnswers = {value};
    notifyListeners();
  }

  void toggleMultiple(String value) {
    if (state.userAnswers.contains(value)) {
      state.userAnswers.remove(value);
    } else {
      state.userAnswers.add(value);
    }
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_finished) return;

      _remainingSeconds -= 1;
      if (_remainingSeconds < 0) {
        _remainingSeconds = 0;
      }
      notifyListeners();

      if (_remainingSeconds <= 0) {
        finishExam(byTimeout: true);
      }
    });
  }

  Future<void> loadCurrentQuestionFirst() async {
    state.isLoading = true;
    notifyListeners();

    try {
      final q = await _fetchQuestionForIndex(_currentIndex);
      _applyQuestion(q);
      _kickPrefetch();
    } finally {
      state.isLoading = false;
      notifyListeners();
    }
  }

  Future<void> goNext() async {
    if (_finished) return;

    final nextIndex = _currentIndex + 1;
    if (nextIndex >= questionCount) {
      finishExam(byTimeout: false);
      return;
    }

    _currentIndex = nextIndex;
    state.isLoading = true;
    state.clearQuestion();
    notifyListeners();

    try {
      final ready = _prefetchController.consumeIfReady(nextIndex);
      if (ready != null) {
        _applyQuestion(ready);
        _kickPrefetch();
        return;
      }

      if (_prefetchController.inFlight != null) {
        try {
          final q = await _prefetchController.inFlight!;
          if (q.index == nextIndex) {
            _prefetchController.clearCache();
            _applyQuestion(q);
            _kickPrefetch();
            return;
          }
        } catch (_) {
          _prefetchController.clearCache();
        }
      }

      final q = await _fetchQuestionForIndex(nextIndex);
      _applyQuestion(q);
      _kickPrefetch();
    } finally {
      state.isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitCurrent() async {
    if (state.questionText == null ||
        state.choices == null ||
        state.correctAnswers == null) {
      throw StateError('問題を読み込んでから解答してください。');
    }
    if (state.userAnswers.isEmpty) {
      throw StateError('選択肢を選んでください。');
    }

    final rec = AnswerRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ts: DateTime.now(),
      difficulty:
      state.currentDifficulty ?? (state.meta?['difficulty']?.toString() ?? ''),
      domain: (state.meta?['domain'] as String?) ?? state.currentDomain,
      major: (state.meta?['major'] as String?) ?? state.currentMajor,
      mid: (state.meta?['mid'] as String?) ?? state.currentMid,
      topic: (state.meta?['topic'] as String?) ?? state.currentTopic,
      question: state.questionText!,
      choices: state.choices!,
      explanation: state.explanation,
      rationales: state.rationales,
      choiceCount: state.choices!.length,
      questionKind: state.questionKind,
      userAnswers: state.userAnswers.toList()..sort(),
      correctAnswers: state.correctAnswers!..sort(),
    );

    _records.add(rec);
    await AnswerHistory.instance.add(rec);

    debugPrint(
      '[log] [MOCK] saved record: diff=${rec.difficulty}, domain=${rec.domain}, major=${rec.major}',
    );

    if (_finished) return;
    await goNext();
  }

  MockExamResultData buildResultData() {
    final usedSeconds =
    _totalSeconds > 0 ? (_totalSeconds - _remainingSeconds) : 0;
    final correct = _records.where((r) => r.isCorrect).length;
    final answered = _records.length;

    return MockExamResultData(
      records: List<AnswerRecord>.unmodifiable(_records),
      totalPlanned: questionCount,
      answeredCount: answered,
      correctCount: correct,
      usedSeconds: usedSeconds,
      timeLimitSeconds: _totalSeconds,
      finishedByTimeout: _finishedByTimeout,
    );
  }

  bool finishExam({required bool byTimeout}) {
    if (_finished) return false;
    _finished = true;
    _finishedByTimeout = byTimeout;
    _timer?.cancel();
    notifyListeners();
    return true;
  }

  Future<MockExamPrefetchedQuestion> _fetchQuestionForIndex(int index) async {
    final spec = MockExamPlanner.pick(
      examType: examType,
      random: _rand,
    );

    final data = await QuestionEngine.instance.generate(spec);

    return MockExamPrefetchedQuestion(
      index: index,
      difficulty: spec.difficulty,
      domain: spec.domain,
      major: spec.major,
      mid: spec.mid,
      topic: (data['meta'] as Map?)?['topic']?.toString(),
      data: data,
    );
  }

  void _kickPrefetch() {
    _prefetchController.kickPrefetch(
      currentIndex: _currentIndex,
      questionCount: questionCount,
      fetcher: _fetchQuestionForIndex,
    );
  }

  void _applyQuestion(MockExamPrefetchedQuestion q) {
    state.currentDifficulty = q.difficulty;
    state.currentDomain = q.domain;
    state.currentMajor = q.major;
    state.currentMid = q.mid;
    state.currentTopic = q.topic;

    final data = q.data;
    state.questionText = (data['question'] as String?)?.trim();

    final rawChoices = data['choices'] as Map?;
    state.choices =
        rawChoices?.map((k, v) => MapEntry(k.toString(), v.toString()));

    state.correctAnswers = (data['correctAnswers'] as List?)
        ?.map((e) => e.toString())
        .toList() ??
        [(data['correct'] ?? '').toString()];

    state.questionKind = (data['questionKind'] as String?) ?? 'single';

    state.explanation = (data['explanation'] as String?) ?? '';
    final rawRat = data['rationales'] as Map?;
    state.rationales =
        rawRat?.map((k, v) => MapEntry(k.toString(), v.toString()));

    final rawMeta = data['meta'] as Map?;
    state.meta = rawMeta?.map((k, v) => MapEntry(k.toString(), v));

    state.userAnswers = {};

    debugPrint(
      '[log] [MOCK] applied q index=${q.index} diff=${q.difficulty} '
          'domain=${q.domain} major=${q.major} mid=${q.mid ?? '(none)'}',
    );
  }
}