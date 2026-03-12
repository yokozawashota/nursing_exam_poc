// lib/features/mock_exam/logic/mock_exam_prefetch_controller.dart
import 'package:flutter/material.dart';

class MockExamPrefetchedQuestion {
  final int index;
  final String difficulty;
  final String domain;
  final String major;
  final String? mid;
  final String? topic;
  final Map<String, dynamic> data;

  MockExamPrefetchedQuestion({
    required this.index,
    required this.difficulty,
    required this.domain,
    required this.major,
    required this.mid,
    required this.topic,
    required this.data,
  });
}

class MockExamPrefetchController {
  MockExamPrefetchedQuestion? _prefetched;
  Future<MockExamPrefetchedQuestion>? _prefetchFuture;
  int _prefetchToken = 0;

  Future<MockExamPrefetchedQuestion>? get inFlight => _prefetchFuture;

  MockExamPrefetchedQuestion? consumeIfReady(int index) {
    if (_prefetched != null && _prefetched!.index == index) {
      final q = _prefetched!;
      _prefetched = null;
      return q;
    }
    return null;
  }

  void clearCache() {
    _prefetched = null;
    _prefetchFuture = null;
  }

  void dispose() {
    _prefetched = null;
    _prefetchFuture = null;
    _prefetchToken++;
  }

  void kickPrefetch({
    required int currentIndex,
    required int questionCount,
    required Future<MockExamPrefetchedQuestion> Function(int index) fetcher,
  }) {
    final nextIndex = currentIndex + 1;
    if (nextIndex >= questionCount) return;

    if (_prefetched != null && _prefetched!.index == nextIndex) return;

    final myToken = ++_prefetchToken;

    _prefetchFuture = fetcher(nextIndex).then((q) {
      if (myToken != _prefetchToken) return q;

      _prefetched = q;
      debugPrint(
        '[log] [MOCK] prefetched ready: index=${q.index} diff=${q.difficulty}',
      );
      return q;
    }).catchError((e) {
      debugPrint('[warn] [MOCK] prefetch failed: $e');

      if (myToken == _prefetchToken) {
        _prefetchFuture = null;
        _prefetched = null;
      }

      return Future<MockExamPrefetchedQuestion>.error(e);
    });
  }
}