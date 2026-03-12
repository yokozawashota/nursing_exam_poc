// lib/features/mock_exam/logic/mock_exam_planner.dart
import 'dart:math';

import '../../../data/categories.dart';
import '../../../data/hisshu_categories.dart';
import '../../../questioning/models/question_spec.dart';
import '../../../questioning/repositories/category_repository.dart';

class MockExamPlanner {
  const MockExamPlanner._();

  static QuestionSpec pick({
    required String examType,
    required Random random,
  }) {
    // mix: 3種ランダム
    // hisshu: 必修固定
    // ippan: 一般固定
    // jokyo: 状況固定
    final String difficulty;
    switch (examType) {
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
        difficulty = pool[random.nextInt(pool.length)];
        break;
    }

    if (difficulty == '必修問題') {
      final majorItems = CategoryRepository.hisshuMajorItems();
      final major = majorItems.isNotEmpty
          ? majorItems[random.nextInt(majorItems.length)]
          : '1. 健康の定義と理解';

      return QuestionSpec(
        difficulty: '必修問題',
        domain: kHisshuCategory,
        major: major,
        mid: null,
        scenarioAspectCode: null,
      );
    }

    if (difficulty == '状況設定問題') {
      final domain = _pickRandomFrom(situationalDomains, random);
      final majors = CategoryRepository.generalMajorsOf(domain);
      final major = _pickRandomFrom(majors, random);

      final midList = CategoryRepository.generalMidsOf(domain, major);
      final mid = midList.isNotEmpty ? _pickRandomFrom(midList, random) : null;

      // 観点はランダム（A..E）
      const aspectKeys = ['A', 'B', 'C', 'D', 'E'];
      final aspect = aspectKeys[random.nextInt(aspectKeys.length)];

      return QuestionSpec(
        difficulty: '状況設定問題',
        domain: domain,
        major: major,
        mid: mid,
        scenarioAspectCode: aspect,
      );
    }

    // 一般問題
    final domains = CategoryRepository.generalDomains();
    final domain = _pickRandomFrom(domains, random);

    final majors = CategoryRepository.generalMajorsOf(domain);
    final major = _pickRandomFrom(majors, random);

    final midList = CategoryRepository.generalMidsOf(domain, major);
    final mid = midList.isNotEmpty ? _pickRandomFrom(midList, random) : null;

    return QuestionSpec(
      difficulty: '一般問題',
      domain: domain,
      major: major,
      mid: mid,
      scenarioAspectCode: null,
    );
  }

  static T _pickRandomFrom<T>(List<T> list, Random random) {
    if (list.isEmpty) {
      throw StateError('カテゴリ候補が空です');
    }
    return list[random.nextInt(list.length)];
  }
}