// lib/questioning/services/question_topic_resolver.dart

import '../../data/hisshu_categories.dart';
import '../models/category_models.dart';
import '../repositories/category_repository.dart';
import 'topic_picker.dart';

class QuestionTopicResolution {
  final String? resolvedMid;
  final String? topic;

  const QuestionTopicResolution({
    required this.resolvedMid,
    required this.topic,
  });
}

class QuestionTopicResolver {
  const QuestionTopicResolver._();

  static Future<QuestionTopicResolution> resolve({
    required String domain,
    required String major,
    String? mid,
  }) async {
    final bool isHisshu = domain == kHisshuCategory;

    if (isHisshu) {
      return _resolveHisshu(
        major: major,
      );
    }

    return _resolveGeneral(
      domain: domain,
      major: major,
      mid: mid,
    );
  }

  static Future<QuestionTopicResolution> _resolveHisshu({
    required String major,
  }) async {
    final DomainCategory tree = CategoryRepository.buildHisshuTree();

    final MajorCategory majorNode = tree.majors.firstWhere(
          (m) => m.id == major,
      orElse: () => tree.majors.isNotEmpty
          ? tree.majors.first
          : MajorCategory(id: major, label: major, mids: const []),
    );

    final mids = majorNode.mids.map((m) => m.id).toList();
    if (mids.isEmpty) {
      return const QuestionTopicResolution(
        resolvedMid: null,
        topic: null,
      );
    }

    final resolvedMid =
    await TopicPicker.pickHisshuMidForMajor(majorNode.id, mids);

    final midNode = _findMidNode(majorNode, resolvedMid);
    final topics = (midNode?.topics ?? const <Topic>[])
        .map((t) => t.label)
        .where((s) => s.trim().isNotEmpty)
        .toList();

    String? topic;
    if (topics.isNotEmpty && resolvedMid.isNotEmpty) {
      topic = await TopicPicker.pickTopic(
        domain: kHisshuCategory,
        major: majorNode.id,
        mid: resolvedMid,
        topics: topics,
      );
    }

    return QuestionTopicResolution(
      resolvedMid: resolvedMid,
      topic: topic,
    );
  }

  static Future<QuestionTopicResolution> _resolveGeneral({
    required String domain,
    required String major,
    String? mid,
  }) async {
    final DomainCategory tree = CategoryRepository.buildGeneralDomainTree(domain);

    final MajorCategory majorNode = tree.majors.firstWhere(
          (m) => m.id == major,
      orElse: () => tree.majors.isNotEmpty
          ? tree.majors.first
          : MajorCategory(id: major, label: major, mids: const []),
    );

    String? resolvedMid;
    if (mid != null && mid.trim().isNotEmpty) {
      resolvedMid = mid.trim();
    } else {
      final mids = majorNode.mids.map((m) => m.id).toList();
      if (mids.isNotEmpty) {
        resolvedMid = await TopicPicker.pickMidForMajor(
          domain: domain,
          major: majorNode.id,
          mids: mids,
        );
      }
    }

    if (resolvedMid == null || resolvedMid.isEmpty) {
      return const QuestionTopicResolution(
        resolvedMid: null,
        topic: null,
      );
    }

    final midNode = _findMidNode(majorNode, resolvedMid);
    final topics = (midNode?.topics ?? const <Topic>[])
        .map((t) => t.label)
        .where((s) => s.trim().isNotEmpty)
        .toList();

    String? topic;
    if (topics.isNotEmpty) {
      topic = await TopicPicker.pickTopic(
        domain: domain,
        major: majorNode.id,
        mid: resolvedMid,
        topics: topics,
      );
    }

    return QuestionTopicResolution(
      resolvedMid: resolvedMid,
      topic: topic,
    );
  }

  static MidCategory? _findMidNode(MajorCategory majorNode, String? midId) {
    if (majorNode.mids.isEmpty) return null;

    if (midId != null && midId.isNotEmpty) {
      for (final m in majorNode.mids) {
        if (m.id == midId) {
          return m;
        }
      }
    }

    return majorNode.mids.first;
  }
}