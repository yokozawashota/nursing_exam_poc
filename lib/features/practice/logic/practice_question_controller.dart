// lib/features/practice/logic/practice_question_controller.dart

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'practice_question_state.dart';

import '../../../questioning/engine/question_engine.dart';
import '../../../questioning/models/question_spec.dart';
import '../../../questioning/repositories/category_repository.dart';
import '../../../data/categories.dart';

import '../../history/services/history_answer_service.dart';

class PracticeQuestionController extends ChangeNotifier {
  final PracticeQuestionState state = PracticeQuestionState();

  static const String modeHisshu = '必修問題';
  static const String modeSituational = '状況設定問題';

  static const List<String> loadingMessages = [
    '問題を生成しています…',
    '選択肢の整合性をチェック中…',
    '国試っぽい文章に整形中…',
    '正答と解説を最終確認中…',
    'まもなく表示します…',
  ];

  Timer? _loadingMessageTimer;
  Timer? _loadingProgressTimer;

  // ==========================
  // 単一選択
  // ==========================
  void selectSingle(String value) {
    state.userAnswers = {value};
    notifyListeners();
  }

  // ==========================
  // 複数選択
  // ==========================
  void toggleMultiple(String value) {
    if (state.userAnswers.contains(value)) {
      state.userAnswers.remove(value);
    } else {
      state.userAnswers.add(value);
    }
    notifyListeners();
  }

  void clearAnswers() {
    state.userAnswers = {};
    notifyListeners();
  }

  // ==========================
  // 初期化
  // ==========================
  void initialize() {
    state.mode = modeHisshu;

    final domains = CategoryRepository.generalDomains();
    state.selectedDomain = domains.isNotEmpty ? domains.first : '';

    final hisshuMajors = CategoryRepository.hisshuMajorItems();
    state.selectedHisshuMajor =
    hisshuMajors.isNotEmpty ? hisshuMajors.first : '';

    resetGeneralSelectionsForDomain(state.selectedDomain);
  }

  @override
  void dispose() {
    stopLoadingUi();
    super.dispose();
  }

  // ==========================
  // Loading UI
  // ==========================
  void startLoadingUi() {
    stopLoadingUi();

    state.loadingMessageIndex = 0;
    state.loadingProgress = 0;

    _loadingMessageTimer =
        Timer.periodic(const Duration(seconds: 2), (_) {
          if (!state.isLoading) return;

          if (state.loadingMessageIndex < loadingMessages.length - 1) {
            state.loadingMessageIndex++;
            notifyListeners();
          }
        });

    _loadingProgressTimer =
        Timer.periodic(const Duration(milliseconds: 80), (_) {
          if (!state.isLoading) return;

          if (state.loadingProgress < 0.99) {
            final next = state.loadingProgress + 0.008;
            state.loadingProgress = next.clamp(0.0, 0.99);
            notifyListeners();
          }
        });
  }

  void stopLoadingUi() {
    _loadingMessageTimer?.cancel();
    _loadingProgressTimer?.cancel();

    _loadingMessageTimer = null;
    _loadingProgressTimer = null;
  }

  Future<void> completeLoadingAndWait() async {
    stopLoadingUi();

    state.loadingMessageIndex = loadingMessages.length - 1;
    state.loadingProgress = 1.0;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ==========================
  // 出題条件の整合
  // ==========================
  void resetGeneralSelectionsForDomain(String domain) {
    final majors = CategoryRepository.generalMajorsOf(domain);
    final major = majors.isNotEmpty ? majors.first : '';

    final mids = major.isEmpty
        ? const <String>[]
        : CategoryRepository.generalMidsOf(domain, major);

    state.selectedDomain = domain;
    state.selectedMajor = major;
    state.selectedMid = mids.isNotEmpty ? mids.first : null;
  }

  void resetMidForMajor(String domain, String major) {
    final mids = CategoryRepository.generalMidsOf(domain, major);
    state.selectedMajor = major;
    state.selectedMid = mids.isNotEmpty ? mids.first : null;
  }

  void handleModeChanged(String mode) {
    state.mode = mode;

    if (mode != modeHisshu) {
      final domains = mode == modeSituational
          ? situationalDomains
          : CategoryRepository.generalDomains();

      final currentDomain = state.selectedDomain;
      final nextDomain = domains.contains(currentDomain)
          ? currentDomain
          : (domains.isNotEmpty ? domains.first : '');

      resetGeneralSelectionsForDomain(nextDomain);
    }

    notifyListeners();
  }

  void handleDomainChanged(String domain) {
    resetGeneralSelectionsForDomain(domain);
    notifyListeners();
  }

  void handleMajorChanged(String major) {
    resetMidForMajor(state.selectedDomain, major);
    notifyListeners();
  }

  void handleUseMidChanged(bool useMid) {
    state.useMid = useMid;

    if (useMid) {
      final mids = CategoryRepository.generalMidsOf(
        state.selectedDomain,
        state.selectedMajor,
      );
      state.selectedMid = mids.isNotEmpty ? mids.first : null;
    } else {
      state.selectedMid = null;
    }

    notifyListeners();
  }

  void handleMidChanged(String? mid) {
    state.selectedMid = mid;
    notifyListeners();
  }

  void handleHisshuMajorChanged(String major) {
    state.selectedHisshuMajor = major;
    notifyListeners();
  }

  void handleScenarioAspectChanged(String? aspectCode) {
    state.selectedScenarioAspectCode = aspectCode;
    notifyListeners();
  }

  // ==========================
  // 観点ランダム
  // ==========================
  String randomScenarioAspectCode() {
    const keys = ['A', 'B', 'C', 'D', 'E'];
    return keys[Random().nextInt(keys.length)];
  }

  // ==========================
  // カテゴリ解決
  // ==========================
  ({String domain, String major, String? mid}) resolveCategory({
    required String mode,
    required String selectedDomain,
    required String selectedMajor,
    required String? selectedMid,
    required bool useMid,
    required String hisshuMajor,
  }) {
    if (mode == modeHisshu) {
      return (domain: '必修', major: hisshuMajor, mid: null);
    }

    final rand = Random();

    final domainList = mode == modeSituational
        ? situationalDomains
        : CategoryRepository.generalDomains();

    String domain = selectedDomain;
    if (!domainList.contains(domain)) {
      domain = domainList[rand.nextInt(domainList.length)];
    }

    final majors = CategoryRepository.generalMajorsOf(domain);

    String major = selectedMajor;
    if (!majors.contains(major)) {
      major = majors[rand.nextInt(majors.length)];
    }

    String? mid;

    if (useMid) {
      final mids = CategoryRepository.generalMidsOf(domain, major);
      if (selectedMid != null && mids.contains(selectedMid)) {
        mid = selectedMid;
      } else if (mids.isNotEmpty) {
        mid = mids[rand.nextInt(mids.length)];
      }
    }

    return (domain: domain, major: major, mid: mid);
  }

  // ==========================
  // 問題生成
  // ==========================
  Future<Map<String, dynamic>> generateQuestion({
    required String mode,
    required String selectedDomain,
    required String selectedMajor,
    required String? selectedMid,
    required bool useMid,
    required String hisshuMajor,
    String? scenarioAspect,
  }) async {
    final resolved = resolveCategory(
      mode: mode,
      selectedDomain: selectedDomain,
      selectedMajor: selectedMajor,
      selectedMid: selectedMid,
      useMid: useMid,
      hisshuMajor: hisshuMajor,
    );

    String? aspect;

    if (mode == modeSituational) {
      aspect = scenarioAspect ?? randomScenarioAspectCode();
    }

    final data = await QuestionEngine.instance.generate(
      QuestionSpec(
        difficulty: mode,
        domain: resolved.domain,
        major: resolved.major,
        mid: resolved.mid,
        scenarioAspectCode: aspect,
      ),
    );

    return data;
  }

  // ==========================
  // 解答保存
  // ==========================
  Future<void> saveAnswer({
    required String difficulty,
    required String question,
    required Map<String, String> choices,
    required List<String> correctAnswers,
    required String questionKind,
    String? explanation,
    Map<String, String>? rationales,
    Map<String, dynamic>? meta,
    String? selectedDomain,
    String? selectedMajor,
    String? selectedMid,
    bool useMid = false,
  }) async {
    final rec = AnswerRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ts: DateTime.now(),
      difficulty: difficulty,
      domain: (meta?['domain'] as String?) ?? selectedDomain,
      major: (meta?['major'] as String?) ?? selectedMajor,
      mid: (meta?['mid'] as String?) ?? (useMid ? selectedMid : null),
      topic: meta?['topic'] as String?,
      question: question,
      choices: choices,
      explanation: explanation,
      rationales: rationales,
      choiceCount: choices.length,
      questionKind: questionKind,
      userAnswers: state.userAnswers.toList()..sort(),
      correctAnswers: correctAnswers.toList()..sort(),
    );

    await AnswerHistory.instance.add(rec);
  }
}