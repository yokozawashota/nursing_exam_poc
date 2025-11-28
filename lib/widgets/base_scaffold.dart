// lib/widgets/base_scaffold.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';

class BaseScaffold extends StatelessWidget {
  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showBack = true,
    this.showFooter = false, // デフォルト非表示
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showBack;
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.background, // ← 画面背景をテーマに統一

      appBar: AppBar(
        automaticallyImplyLeading: showBack,

        // AppBar のタイトルスタイルを Theme に完全準拠
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),

        // actions はそのまま
        actions: actions,
      ),

      body: body,

      bottomNavigationBar:
      showFooter ? const _CopyrightFooter() : null,
    );
  }
}

/// © 2025 NurAI フッター（テーマ準拠）
class _CopyrightFooter extends StatefulWidget {
  const _CopyrightFooter();

  @override
  State<_CopyrightFooter> createState() => _CopyrightFooterState();
}

class _CopyrightFooterState extends State<_CopyrightFooter> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() => _version = 'Ver ${info.version}');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        height: 38,
        color: cs.background, // ← フッター背景も統一
        child: Center(
          child: Text(
            '© 2025 NurAI  ${_version.isEmpty ? "" : _version}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary.withOpacity(0.75),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}