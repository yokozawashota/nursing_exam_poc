// lib/shared/services/category_repository.dart

import '../models/category_models.dart';

// 既存のデータ定義をそのまま利用
import '../../data/categories.dart';          // domains, majorsOf(), midsOf(), topicsOf()
import '../../data/hisshu_categories.dart';   // kHisshuCategory, hisshuMajors(), hisshuMidsOf(), hisshuTopicsOf()

/// 既存の関数群（majorsOf/midsOf/topicsOf 等）を“型付きツリー”に変換するリポジトリ。
/// まずは追加だけ。徐々にこちらの型へ置き換えていけます。
class CategoryRepository {
  /// 一般/状況設定の分野ツリーを構築（ドメイン名で指定）
  static DomainCategory buildGeneralDomainTree(String domain) {
    final majorNames = majorsOf(domain);
    final majors = majorNames.map((maj) {
      final midNames = midsOf(domain, maj);
      final mids = midNames.map((mid) {
        final topicNames = topicsOf(domain, maj, mid);
        final topics = topicNames
            .map((t) => Topic(id: t, label: t))
            .toList(growable: false);
        return MidCategory(id: mid, label: mid, topics: topics);
      }).toList(growable: false);
      return MajorCategory(id: maj, label: maj, mids: mids);
    }).toList(growable: false);

    return DomainCategory(id: domain, label: domain, majors: majors);
  }

  /// 必修ツリーを構築（ドメインは kHisshuCategory 固定）
  static DomainCategory buildHisshuTree() {
    final majorNames = hisshuMajors();
    final majors = majorNames.map((maj) {
      final midNames = hisshuMidsOf(maj);
      final mids = midNames.map((mid) {
        final topicNames = hisshuTopicsOf(maj, mid);
        final topics = topicNames
            .map((t) => Topic(id: t, label: t))
            .toList(growable: false);
        return MidCategory(id: mid, label: mid, topics: topics);
      }).toList(growable: false);
      return MajorCategory(id: maj, label: maj, mids: mids);
    }).toList(growable: false);

    return DomainCategory(id: kHisshuCategory, label: kHisshuCategory, majors: majors);
  }

  // ========== 以下は“移行を楽にする”ための薄いFacade（今のAPIを保ったまま裏で型へ） ==========

  static List<String> generalDomains() => domains;

  static List<String> generalMajorsOf(String domain) => majorsOf(domain);

  static List<String> generalMidsOf(String domain, String major) =>
      midsOf(domain, major);

  static List<String> generalTopicsOf(String domain, String major, String mid) =>
      topicsOf(domain, major, mid);

  static List<String> hisshuMajorItems() => hisshuMajors();

  static List<String> hisshuMids(String major) => hisshuMidsOf(major);

  static List<String> hisshuTopics(String major, String mid) =>
      hisshuTopicsOf(major, mid);
}