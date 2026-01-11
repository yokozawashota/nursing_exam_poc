// lib/features/mock_exam/screens/mock_exam_screen.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/base_scaffold.dart';
import '../../practice/widgets/question_block.dart';
import '../../practice/services/question_service.dart';

import '../../../shared/services/category_repository.dart';
import '../../../data/categories.dart';
import '../../../data/hisshu_categories.dart';
import '../../../shared/models/answer_history.dart';

class MockExamScreen extends StatefulWidget {
  const MockExamScreen({
    super.key,
    required this.questionCount,
    required this.examType, // ✅ configから渡す: mix / hisshu / ippan / jokyo
    this.timeLimitMinutes = 0, // ✅ 0: 制限なし（configに項目がないためデフォルト）
  });

  final int questionCount;

  /// 'mix' | 'hisshu' | 'ippan' | 'jokyo'
  final String examType;

  /// 0なら無制限
  final int timeLimitMinutes;

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  // ==========================
  // 進行管理
  // ==========================
  int _currentIndex = 0;
  bool _finished = false;

  late final int _totalSeconds;
  int _remainingSeconds = 0;
  Timer? _timer;

  // ==========================
  // 出題データ（表示中）
  // ==========================
  bool _isLoading = false;

  String? _questionText;
  Map<String, String>? _choices;
  List<String>? _correctAnswers;
  String? _explanation;
  Map<String, String>? _rationales;
  Set<String> _userAnswers = {};
  String _questionKind = 'single';

  // 履歴保存用（表示中の問題のカテゴリ情報）
  String? _currentDifficulty;
  String? _currentDomain;
  String? _currentMajor;
  String? _currentMid;
  String? _currentTopic;
  Map<String, dynamic>? _meta;

  // 解答履歴
  final List<AnswerRecord> _records = [];

  // ==========================
  // ✅ プリフェッチ（次問を裏生成）
  // ==========================
  _PrefetchedQuestion? _prefetched; // 完了済み（次問が置かれる）
  Future<_PrefetchedQuestion>? _prefetchFuture; // 進行中
  int _prefetchToken = 0; // 競合防止（古いprefetchを破棄）

  // 乱数
  final Random _rand = Random(DateTime.now().microsecondsSinceEpoch);

  @override
  void initState() {
    super.initState();

    _totalSeconds = widget.timeLimitMinutes * 60;
    _remainingSeconds = _totalSeconds;

    if (_totalSeconds > 0) {
      _startTimer();
    }

    _loadCurrentQuestionFirst();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _finished) return;
      setState(() {
        _remainingSeconds -= 1;
      });
      if (_remainingSeconds <= 0) {
        _finishExam(byTimeout: true);
      }
    });
  }

  // ==========================
  // 初回ロード
  // ==========================
  Future<void> _loadCurrentQuestionFirst() async {
    setState(() => _isLoading = true);
    try {
      final q = await _fetchQuestionForIndex(_currentIndex);
      if (!mounted) return;

      _applyQuestion(q);
      _kickPrefetch(); // ✅ 次問を裏で開始
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('問題の取得に失敗しました：$e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================
  // ✅ 次問へ進む（prefetch優先）
  // ==========================
  Future<void> _goNext() async {
    if (_finished) return;
    final nextIndex = _currentIndex + 1;

    if (nextIndex >= widget.questionCount) {
      _finishExam(byTimeout: false);
      return;
    }

    setState(() {
      _currentIndex = nextIndex;
      _isLoading = true;

      // ここは「一旦クリア」でもOK。
      // チラつきが気になるなら、クリアせずに上にローディング表示だけ出す方式にもできます。
      _questionText = null;
      _choices = null;
      _correctAnswers = null;
      _explanation = null;
      _rationales = null;
      _userAnswers = {};
      _questionKind = 'single';
      _meta = null;
      _currentDifficulty = null;
      _currentDomain = null;
      _currentMajor = null;
      _currentMid = null;
      _currentTopic = null;
    });

    try {
      // ✅ 1) prefetchが「次index」のものなら最優先で使う
      if (_prefetched != null && _prefetched!.index == nextIndex) {
        final q = _prefetched!;
        _prefetched = null; // consume
        _applyQuestion(q);
        _kickPrefetch(); // ✅ さらに次を裏生成
        return;
      }

      // ✅ 2) prefetchが進行中で「次index」なら待って使う
      if (_prefetchFuture != null) {
        try {
          final q = await _prefetchFuture!;
          if (!mounted) return;
          if (q.index == nextIndex) {
            _prefetchFuture = null;
            _prefetched = null;
            _applyQuestion(q);
            _kickPrefetch();
            return;
          }
        } catch (e) {
          // prefetch待機が失敗したら、下の通常取得へフォールバック
          debugPrint('[warn] [MOCK] prefetch(await) failed: $e');
          _prefetchFuture = null;
          _prefetched = null;
        }
      }

      // ✅ 3) なければ通常取得
      final q = await _fetchQuestionForIndex(nextIndex);
      if (!mounted) return;
      _applyQuestion(q);
      _kickPrefetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('問題の取得に失敗しました：$e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================
  // ✅ 表示中の問題をAnswerRecordとして保存して次へ
  // ==========================
  Future<void> _submitCurrent() async {
    if (_questionText == null || _choices == null || _correctAnswers == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題を読み込んでから解答してください。')),
      );
      return;
    }
    if (_userAnswers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('選択肢を選んでください。')),
      );
      return;
    }

    try {
      final rec = AnswerRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ts: DateTime.now(),
        difficulty: _currentDifficulty ?? (_meta?['difficulty']?.toString() ?? ''),
        domain: (_meta?['domain'] as String?) ?? _currentDomain,
        major: (_meta?['major'] as String?) ?? _currentMajor,
        mid: (_meta?['mid'] as String?) ?? _currentMid,
        topic: (_meta?['topic'] as String?) ?? _currentTopic,
        question: _questionText!,
        choices: _choices!,
        explanation: _explanation,
        rationales: _rationales,
        choiceCount: _choices!.length,
        questionKind: _questionKind,
        userAnswers: _userAnswers.toList()..sort(),
        correctAnswers: _correctAnswers!..sort(),
      );

      _records.add(rec);
      await AnswerHistory.instance.add(rec);

      debugPrint(
        '[log] [MOCK] saved record: diff=${rec.difficulty}, domain=${rec.domain}, major=${rec.major}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('履歴の保存に失敗しました：$e')),
        );
      }
      return;
    }

    if (!mounted || _finished) return;

    await _goNext();
  }

  // ==========================
  // ✅ プリフェッチ開始（常に「次の1問」だけ持つ）
  // ==========================
  void _kickPrefetch() {
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= widget.questionCount) return;

    // すでに「次index」のprefetchが完了しているなら何もしない
    if (_prefetched != null && _prefetched!.index == nextIndex) return;

    // token更新（古いprefetchは自然に破棄）
    final myToken = ++_prefetchToken;

    _prefetchFuture = _fetchQuestionForIndex(nextIndex).then((q) {
      if (myToken != _prefetchToken) return q; // 古いprefetchは捨てる

      _prefetched = q;
      debugPrint(
        '[log] [MOCK] prefetched ready: index=${q.index} diff=${q.difficulty}',
      );
      return q;
    }).catchError((e) {
      // prefetchの失敗は致命傷にしない（次に通常取得する）
      debugPrint('[warn] [MOCK] prefetch failed: $e');

      // 失敗しても状態を壊さない
      if (myToken == _prefetchToken) {
        _prefetchFuture = null;
        _prefetched = null;
      }
      // ここではthrowしない（await側で落ちないように）
      return Future<_PrefetchedQuestion>.error(e);
    });
  }

  // ==========================
  // 問題をstateへ反映
  // ==========================
  void _applyQuestion(_PrefetchedQuestion q) {
    setState(() {
      _currentDifficulty = q.difficulty;
      _currentDomain = q.domain;
      _currentMajor = q.major;
      _currentMid = q.mid;
      _currentTopic = q.topic;

      final data = q.data;
      _questionText = (data['question'] as String?)?.trim();

      final rawChoices = data['choices'] as Map?;
      _choices = rawChoices?.map((k, v) => MapEntry(k.toString(), v.toString()));

      _correctAnswers = (data['correctAnswers'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          [(data['correct'] ?? '').toString()];

      _questionKind = (data['questionKind'] as String?) ?? 'single';

      _explanation = (data['explanation'] as String?) ?? '';
      final rawRat = data['rationales'] as Map?;
      _rationales = rawRat?.map((k, v) => MapEntry(k.toString(), v.toString()));

      final rawMeta = data['meta'] as Map?;
      _meta = rawMeta?.map((k, v) => MapEntry(k.toString(), v));

      _userAnswers = {};
    });

    debugPrint(
      '[log] [MOCK] applied q index=${q.index} diff=${q.difficulty} '
          'domain=${q.domain} major=${q.major} mid=${q.mid ?? '(none)'}',
    );
  }

  // ==========================
  // 次index用の問題を取得（内部）
  // ==========================
  Future<_PrefetchedQuestion> _fetchQuestionForIndex(int index) async {
    final spec = _pickSpecForNextQuestion();

    final data = await QuestionService.fetchQuestion(
      difficulty: spec.difficulty,
      domain: spec.domain,
      major: spec.major,
      mid: spec.mid,
      scenarioAspect: spec.scenarioAspectCode,
    );

    return _PrefetchedQuestion(
      index: index,
      difficulty: spec.difficulty,
      domain: spec.domain,
      major: spec.major,
      mid: spec.mid,
      topic: (data['meta'] as Map?)?['topic']?.toString(),
      data: data,
    );
  }

  // ==========================
  // ✅ examType（mix/hisshu/ippan/jokyo）から出題種別を決定
  // ==========================
  _QuestionSpec _pickSpecForNextQuestion() {
    // mix: 3種ランダム
    // hisshu: 必修固定
    // ippan: 一般固定
    // jokyo: 状況固定
    final String difficulty;
    switch (widget.examType) {
      case 'hisshu':
        difficulty = '必修問題';
        break;
      case 'ippan':
        difficulty = '一般問題';
        break;
      case 'jokyo':
        difficulty = '状況設定問題';
        break;
      case 'mix':
      default:
        const pool = ['必修問題', '一般問題', '状況設定問題'];
        difficulty = pool[_rand.nextInt(pool.length)];
        break;
    }

    if (difficulty == '必修問題') {
      final majorItems = CategoryRepository.hisshuMajorItems();
      final major = majorItems.isNotEmpty
          ? majorItems[_rand.nextInt(majorItems.length)]
          : '1. 健康の定義と理解';

      return _QuestionSpec(
        difficulty: '必修問題',
        domain: kHisshuCategory,
        major: major,
        mid: null,
        scenarioAspectCode: null,
      );
    }

    if (difficulty == '状況設定問題') {
      final domain = _pickRandomFrom(situationalDomains);
      final majors = CategoryRepository.generalMajorsOf(domain);
      final major = _pickRandomFrom(majors);

      final midList = CategoryRepository.generalMidsOf(domain, major);
      final mid = midList.isNotEmpty ? _pickRandomFrom(midList) : null;

      // 観点はランダム（A..E）
      const aspectKeys = ['A', 'B', 'C', 'D', 'E'];
      final aspect = aspectKeys[_rand.nextInt(aspectKeys.length)];

      return _QuestionSpec(
        difficulty: '状況設定問題',
        domain: domain,
        major: major,
        mid: mid,
        scenarioAspectCode: aspect,
      );
    }

    // 一般問題
    final domains = CategoryRepository.generalDomains();
    final domain = _pickRandomFrom(domains);

    final majors = CategoryRepository.generalMajorsOf(domain);
    final major = _pickRandomFrom(majors);

    final midList = CategoryRepository.generalMidsOf(domain, major);
    final mid = midList.isNotEmpty ? _pickRandomFrom(midList) : null;

    return _QuestionSpec(
      difficulty: '一般問題',
      domain: domain,
      major: major,
      mid: mid,
      scenarioAspectCode: null,
    );
  }

  T _pickRandomFrom<T>(List<T> list) {
    if (list.isEmpty) {
      throw StateError('カテゴリ候補が空です');
    }
    return list[_rand.nextInt(list.length)];
  }

  // ==========================
  // 終了処理
  // ==========================
  void _finishExam({required bool byTimeout}) {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();

    final usedSeconds = _totalSeconds > 0 ? (_totalSeconds - _remainingSeconds) : 0;
    final correct = _records.where((r) => r.isCorrect).length;
    final answered = _records.length;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MockExamResultScreen(
          records: _records,
          totalPlanned: widget.questionCount,
          answeredCount: answered,
          correctCount: correct,
          usedSeconds: usedSeconds,
          timeLimitSeconds: _totalSeconds,
          finishedByTimeout: byTimeout,
        ),
      ),
    );
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
    final theme = Theme.of(context);

    final hasTimeLimit = _totalSeconds > 0;
    final progressTime = (!hasTimeLimit || _totalSeconds == 0)
        ? 0.0
        : (1.0 - _remainingSeconds / _totalSeconds).clamp(0.0, 1.0);

    final title = '模試 (${_currentIndex + 1} / ${widget.questionCount})';

    final bool isMulti =
        _questionKind == 'multiple' || _questionKind == 'select_incorrect' || (_correctAnswers?.length ?? 0) >= 2;

    return BaseScaffold(
      title: title,
      showBack: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー（タグ + 残り時間）
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _modeLabel(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Q${_currentIndex + 1} / ${widget.questionCount}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  if (hasTimeLimit) ...[
                    const Icon(Icons.timer_outlined, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              if (hasTimeLimit) ...[
                LinearProgressIndicator(
                  value: progressTime,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const SizedBox(height: 8),
              ],

              // 本文
              Expanded(
                child: _isLoading && _questionText == null
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '次の問題を読み込み中…',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
                    : (_questionText == null || _choices == null)
                    ? Center(
                  child: Text(
                    '問題を読み込めませんでした。',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
                    : SingleChildScrollView(
                  child: QuestionBlock(
                    questionText: _questionText!,
                    choices: _choices!,
                    questionKind: _questionKind,

                    // 単一選択
                    selectedLabel: !isMulti && _userAnswers.isNotEmpty ? _userAnswers.first : null,
                    onSelect: !isMulti
                        ? (val) => setState(() => _userAnswers = {val})
                        : null,

                    // 複数選択
                    selectedLabels: isMulti ? _userAnswers.toList() : null,
                    onToggle: isMulti
                        ? (val) {
                      setState(() {
                        if (_userAnswers.contains(val)) {
                          _userAnswers.remove(val);
                        } else {
                          _userAnswers.add(val);
                        }
                      });
                    }
                        : null,

                    onSubmit: _submitCurrent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================
// 内部モデル
// ==========================
class _QuestionSpec {
  final String difficulty;
  final String domain;
  final String major;
  final String? mid;
  final String? scenarioAspectCode;

  _QuestionSpec({
    required this.difficulty,
    required this.domain,
    required this.major,
    required this.mid,
    required this.scenarioAspectCode,
  });
}

class _PrefetchedQuestion {
  final int index;
  final String difficulty;
  final String domain;
  final String major;
  final String? mid;
  final String? topic;
  final Map<String, dynamic> data;

  _PrefetchedQuestion({
    required this.index,
    required this.difficulty,
    required this.domain,
    required this.major,
    required this.mid,
    required this.topic,
    required this.data,
  });
}

// === 結果画面（元のまま） ===
class MockExamResultScreen extends StatelessWidget {
  const MockExamResultScreen({
    super.key,
    required this.records,
    required this.totalPlanned,
    required this.answeredCount,
    required this.correctCount,
    required this.usedSeconds,
    required this.timeLimitSeconds,
    required this.finishedByTimeout,
  });

  final List<AnswerRecord> records;
  final int totalPlanned;
  final int answeredCount;
  final int correctCount;
  final int usedSeconds;
  final int timeLimitSeconds;
  final bool finishedByTimeout;

  String _formatTime(int sec) {
    if (sec < 0) sec = 0;
    final m = sec ~/ 60;
    final s = sec % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final total = answeredCount;
    final rate = total == 0 ? 0.0 : correctCount / total;

    return BaseScaffold(
      title: '模試結果',
      showBack: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('おつかれさまでした！', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('結果サマリ', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('回答数: $answeredCount / $totalPlanned'),
                    Text('正解数: $correctCount'),
                    Text('正答率: ${(rate * 100).toStringAsFixed(1)}%'),
                    const SizedBox(height: 8),
                    Text('所要時間: ${_formatTime(usedSeconds)}'),
                    if (timeLimitSeconds > 0) Text('制限時間: ${_formatTime(timeLimitSeconds)}'),
                    if (finishedByTimeout)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('※制限時間により終了しました', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('※詳細分析はスコア画面をご確認ください', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}