import 'package:flutter/material.dart';
import '../services/version_service.dart';

/// 全画面共通のヘッダー／フッター＆背景
class BaseScaffold extends StatelessWidget {
  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showBack = true,
    this.footer,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? footer;

  /// 色の一元管理（メニュー等と統一）
  static const Color edgeBg = Color(0xFFF1EAF5);   // ヘッダー/フッター/外側
  static const Color centerBg = Color(0xFFF7F2FA); // 中央
  static const Color divider = Colors.black12;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Scaffold(
      backgroundColor: edgeBg,
      body: SafeArea(
        child: Column(
          children: [
            // ===== Header =====
            Container(
              decoration: const BoxDecoration(
                color: edgeBg,
                border: Border(
                  bottom: BorderSide(color: divider, width: 0.5),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Row(
                children: [
                  if (showBack && canPop)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  // 右側アクション（サイズ合わせ）
                  SizedBox(
                    width: 48,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions ?? const [],
                    ),
                  ),
                ],
              ),
            ),

            // ===== Center =====
            Expanded(
              child: Container(
                color: centerBg,
                child: body,
              ),
            ),

            // ===== Footer =====
            Container(
              decoration: const BoxDecoration(
                color: edgeBg,
                border: Border(
                  top: BorderSide(color: divider, width: 0.5),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              alignment: Alignment.center,
              child: footer ??
                  FutureBuilder<String>(
                    future: VersionService.footerText(),
                    builder: (context, snap) {
                      final text = snap.hasData
                          ? snap.data!
                          : '© 2025 NurAI Ver —';
                      return Text(
                        text,
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}