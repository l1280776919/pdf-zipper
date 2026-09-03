import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/media_scanner_service.dart';
import 'compress_page/compress_page.dart';
import 'history_page/history_page.dart';

class MainLayout extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  const MainLayout({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final GlobalKey<HistoryPageState> _historyPageKey = GlobalKey<HistoryPageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestPermissionOnStartup();
    });
  }

  Future<void> _checkAndRequestPermissionOnStartup() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final hasPerm = await MediaScannerService.hasStoragePermission();
    if (!hasPerm && mounted) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('授予存储管理权限'),
          content: const Text(
            '为了将压缩后的 PPT 直接保存在原文件所在目录，并让系统文件管理与钉钉立刻识别，请在接下来的设置中开启“所有文件访问权限”。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('暂不开启'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('去开启'),
            ),
          ],
        ),
      );
      if (shouldRequest == true) {
        await MediaScannerService.requestStoragePermission();
      }
    }
  }

  void _onHistoryUpdated() {
    _historyPageKey.currentState?.loadHistory();
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'PPT 压缩',
      applicationVersion: '1.0.6',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D9488).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF0D9488), size: 36),
      ),
      children: const [
        Text('PowerPoint (.pptx) 图片保真压缩工具。'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = widget.themeMode == ThemeMode.dark ||
        (widget.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;

        if (isMobile) {
          // 手机端原生体验：底部导航栏 + 顶部 AppBar
          return Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_fix_high_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'PPT 压缩',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                  tooltip: isDark ? '浅色' : '深色',
                  onPressed: widget.onToggleTheme,
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 22),
                  tooltip: '关于',
                  onPressed: _showAboutDialog,
                ),
              ],
            ),
            body: IndexedStack(
              index: _selectedIndex,
              children: [
                CompressPage(onHistoryUpdated: _onHistoryUpdated),
                HistoryPage(key: _historyPageKey),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
                if (index == 1) {
                  _historyPageKey.currentState?.loadHistory();
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.compress_outlined),
                  selectedIcon: Icon(Icons.compress_rounded),
                  label: '压缩',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history_rounded),
                  label: '历史',
                ),
              ],
            ),
          );
        }

        // 平板与桌面端：侧边常驻栏
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                extended: true,
                minExtendedWidth: 200,
                backgroundColor: colorScheme.surfaceContainerLow,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepOrange.withAlpha(80),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.slideshow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'PPT 压缩',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                            tooltip: isDark ? '浅色' : '深色',
                            onPressed: widget.onToggleTheme,
                          ),
                          const SizedBox(height: 4),
                          IconButton(
                            icon: const Icon(Icons.info_outline, size: 20),
                            tooltip: '关于',
                            onPressed: _showAboutDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.compress_outlined),
                    selectedIcon: Icon(Icons.compress_rounded),
                    label: Text('压缩'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history_rounded),
                    label: Text('历史'),
                  ),
                ],
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() => _selectedIndex = index);
                  if (index == 1) {
                    _historyPageKey.currentState?.loadHistory();
                  }
                },
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    CompressPage(onHistoryUpdated: _onHistoryUpdated),
                    HistoryPage(key: _historyPageKey),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
