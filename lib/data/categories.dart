// lib/data/categories.dart
// 出題範囲ドメインの集約とディスパッチ

// 一般問題（領域別）
import 'general/body_structure.dart';
import 'general/disease_recovery.dart';
import 'general/health_social_security.dart';
import 'general/adult_nursing.dart';
import 'general/geriatric_nursing.dart';
import 'general/pediatric_nursing.dart';
import 'general/maternal_nursing.dart';
import 'general/psychiatric_nursing.dart';
import 'general/home_community_nursing.dart';
import 'general/nursing_integration_practice.dart'; // ← ファイル名を統一

// 必修は別ファイル（hisshu_categories.dart）で管理している想定。
// ※このファイルでは必修のデータ構造は扱いません。

// ドメイン定数（表示名は原典どおり）
const String kDomainBodyStructure        = '人体の構造と機能';
const String kDomainDiseaseRecovery      = '疾病の成り立ちと回復の促進';
const String kDomainHealthSocial         = '健康支援と社会保障制度';
const String kDomainAdultNursing         = '成人看護学';
const String kDomainGeriatricNursing     = '老年看護学';
const String kDomainPediatricNursing     = '小児看護学';
const String kDomainMaternalNursing      = '母性看護学';
const String kDomainPsychiatricNursing   = '精神看護学';
const String kDomainHomeCommunityNursing = '在宅看護論／地域・在宅看護論';
const String kDomainIntegrationPractice  = '看護の統合と実践';

// 画面のドロップダウンに出す並び順（一般問題用）
const List<String> domains = <String>[
  kDomainBodyStructure,
  kDomainDiseaseRecovery,
  kDomainHealthSocial,
  kDomainAdultNursing,
  kDomainGeriatricNursing,
  kDomainPediatricNursing,
  kDomainMaternalNursing,
  kDomainPsychiatricNursing,
  kDomainHomeCommunityNursing,
  kDomainIntegrationPractice,
];

// 状況設定問題で選択可能な分野（要件: 老年/小児/母性/精神/在宅/統合）
const List<String> situationalDomains = <String>[
  kDomainGeriatricNursing,
  kDomainPediatricNursing,
  kDomainMaternalNursing,
  kDomainPsychiatricNursing,
  kDomainHomeCommunityNursing,
  kDomainIntegrationPractice,
];

/// 大項目一覧を返す
List<String> majorsOf(String domain) {
  if (domain == kDomainBodyStructure)        return bodyStructureMajors();
  if (domain == kDomainDiseaseRecovery)      return diseaseRecoveryMajors();
  if (domain == kDomainHealthSocial)         return healthSocialMajors();
  if (domain == kDomainAdultNursing)         return adultNursingMajors();
  if (domain == kDomainGeriatricNursing)     return geriatricNursingMajors();
  if (domain == kDomainPediatricNursing)     return pediatricNursingMajors();
  if (domain == kDomainMaternalNursing)      return maternalNursingMajors();
  if (domain == kDomainPsychiatricNursing)   return psychiatricNursingMajors();
  if (domain == kDomainHomeCommunityNursing) return homeCommunityNursingMajors();
  if (domain == kDomainIntegrationPractice)  return nursingIntegrationPracticeMajors(); // ← 関数名も統一
  return const [];
}

/// 指定ドメイン・大項目の中項目一覧
List<String> midsOf(String domain, String major) {
  if (domain == kDomainBodyStructure)        return bodyStructureMids(major);
  if (domain == kDomainDiseaseRecovery)      return diseaseRecoveryMids(major);
  if (domain == kDomainHealthSocial)         return healthSocialMids(major);
  if (domain == kDomainAdultNursing)         return adultNursingMids(major);
  if (domain == kDomainGeriatricNursing)     return geriatricNursingMids(major);
  if (domain == kDomainPediatricNursing)     return pediatricNursingMids(major);
  if (domain == kDomainMaternalNursing)      return maternalNursingMids(major);
  if (domain == kDomainPsychiatricNursing)   return psychiatricNursingMids(major);
  if (domain == kDomainHomeCommunityNursing) return homeCommunityNursingMids(major);
  if (domain == kDomainIntegrationPractice)  return nursingIntegrationPracticeMids(major); // ← 統一
  return const [];
}

/// 指定（ドメイン, 大項目[, 中項目]）の小項目（キーワード）
/// mid を省略/ null の場合は、その大項目配下の全キーワードを結合して返す
List<String> topicsOf(String domain, String major, [String? mid]) {
  List<String> _collectAll(
      List<String> mids,
      List<String> Function(String major, String mid) getter,
      ) {
    final list = <String>[];
    for (final m in mids) {
      list.addAll(getter(major, m));
    }
    return list;
  }

  if (domain == kDomainBodyStructure) {
    return (mid == null)
        ? _collectAll(bodyStructureMids(major), bodyStructureTopicsOf)
        : bodyStructureTopicsOf(major, mid);
  }

  if (domain == kDomainDiseaseRecovery) {
    return (mid == null)
        ? _collectAll(diseaseRecoveryMids(major), diseaseRecoveryTopicsOf)
        : diseaseRecoveryTopicsOf(major, mid);
  }

  if (domain == kDomainHealthSocial) {
    return (mid == null)
        ? _collectAll(healthSocialMids(major), healthSocialTopicsOf)
        : healthSocialTopicsOf(major, mid);
  }

  if (domain == kDomainAdultNursing) {
    return (mid == null)
        ? _collectAll(adultNursingMids(major), adultNursingTopicsOf)
        : adultNursingTopicsOf(major, mid);
  }

  if (domain == kDomainGeriatricNursing) {
    return (mid == null)
        ? _collectAll(geriatricNursingMids(major), geriatricNursingTopicsOf)
        : geriatricNursingTopicsOf(major, mid);
  }

  if (domain == kDomainPediatricNursing) {
    return (mid == null)
        ? _collectAll(pediatricNursingMids(major), pediatricNursingTopicsOf)
        : pediatricNursingTopicsOf(major, mid);
  }

  if (domain == kDomainMaternalNursing) {
    return (mid == null)
        ? _collectAll(maternalNursingMids(major), maternalNursingTopicsOf)
        : maternalNursingTopicsOf(major, mid);
  }

  if (domain == kDomainPsychiatricNursing) {
    return (mid == null)
        ? _collectAll(psychiatricNursingMids(major), psychiatricNursingTopicsOf)
        : psychiatricNursingTopicsOf(major, mid);
  }

  if (domain == kDomainHomeCommunityNursing) {
    return (mid == null)
        ? _collectAll(homeCommunityNursingMids(major), homeCommunityNursingTopicsOf)
        : homeCommunityNursingTopicsOf(major, mid);
  }

  if (domain == kDomainIntegrationPractice) {
    return (mid == null)
        ? _collectAll(nursingIntegrationPracticeMids(major), nursingIntegrationPracticeTopicsOf)
        : nursingIntegrationPracticeTopicsOf(major, mid);
  }

  return const [];
}