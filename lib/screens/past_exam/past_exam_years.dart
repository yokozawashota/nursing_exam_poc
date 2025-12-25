// lib/screens/past_exam/past_exam_years.dart
import 'package:flutter/foundation.dart';

@immutable
class PastExamYearMeta {
  final String id;    // '111' など
  final String title; // '第111回（2022年）' など

  const PastExamYearMeta({
    required this.id,
    required this.title,
  });
}

/// ✅ 年度追加はここだけ（表示名だけ）
///
/// - assets/past_exam/<id>/... を置いておけば、画面側は自動で総問題数などを算出します。
const pastExamYears = <PastExamYearMeta>[
  PastExamYearMeta(id: '111', title: '第111回（2022年）'),
  PastExamYearMeta(id: '113', title: '第113回（2024年）'),
];