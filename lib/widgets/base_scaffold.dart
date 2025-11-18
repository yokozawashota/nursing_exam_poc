// lib/widgets/base_scaffold.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class BaseScaffold extends StatelessWidget {
  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showBack = true,
    this.showFooter = false, // ← デフォルトは表示しない
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showBack;

  /// © 2025 NurAI フッターを出すか（デフォルト false）
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBack,
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: showFooter ? const _CopyrightFooter() : null,
    );
  }
}

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
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 38,
        child: Center(
          child: Text(
            '© 2025 NurAI  ${_version.isEmpty ? "" : _version}',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}