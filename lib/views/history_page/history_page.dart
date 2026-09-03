import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../../models/history_record.dart';
import '../../services/history_storage_service.dart';
import '../../utils/desktop_utils.dart';
import '../../utils/file_size_formatter.dart';
import 'widgets/history_stats_card.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  List<HistoryRecord> _records = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadHistory() async {
    setState(() => _isLoading = true);
    final list = await HistoryStorageService.getHistory();
    if (mounted) {
      setState(() {
        _records = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRecord(String id) async {
    await HistoryStorageService.deleteRecord(id);
    await loadHistory();
  }

  Future<void> _handleOpenFile(String filePath) async {
    final result = await DesktopUtils.openFile(filePath);
    if (!mounted) return;

    if (result.type != ResultType.done) {
      String msg = '无法打开文件';
      if (result.type == ResultType.fileNotFound) {
        msg = '文件不存在或已被移动';
      } else if (result.type == ResultType.noAppToOpen) {
        msg = '未检测到可打开 PPT 的应用（如 WPS Office）';
      } else if (result.type == ResultType.permissionDenied) {
        msg = '无权限访问该文件';
      } else {
        msg = '打开失败: ${result.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '分享/发送',
            onPressed: () => DesktopUtils.shareFile(filePath),
          ),
        ),
      );
    }
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空历史记录'),
        content: const Text('确定要清空所有的 PPT 压缩历史记录吗？此操作不可撤销（不会删除实际磁盘文件）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确定清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HistoryStorageService.clearAll();
      await loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stats = HistoryStorageService.calculateStats(_records);
    final isDark = theme.brightness == Brightness.dark;

    final sortedRecords = List<HistoryRecord>.from(_records)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final filteredRecords = sortedRecords.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.fileName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 16 : 28,
                vertical: isNarrow ? 16 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部标题与清空操作
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '压缩历史',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_records.isNotEmpty)
                        TextButton.icon(
                          onPressed: _confirmClearAll,
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('清空', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFE11D48),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 统计数据看板
                  HistoryStatsCard(stats: stats),
                  const SizedBox(height: 20),

                  // 搜索筛选栏
                  if (_records.isNotEmpty)
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '按文件名搜索历史记录...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? colorScheme.surface : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                    ),
                  const SizedBox(height: 16),

                  // 列表为空状态
                  if (_records.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 48,
                            color: colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '暂无历史记录',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (filteredRecords.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Text(
                        '未找到符合 "$_searchQuery" 的记录',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    )
                  else
                    // 历史记录列表
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        final record = filteredRecords[index];
                        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(record.timestamp);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? colorScheme.surface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? colorScheme.outlineVariant : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _handleOpenFile(record.outputFilePath),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFFF6B4A), Color(0xFFFF8E53)],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.slideshow_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                record.fileName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '输出: ${record.outputFilePath}',
                                                style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          dateStr,
                                          style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 11,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                                          tooltip: '删除此记录',
                                          onPressed: () => _deleteRecord(record.id),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 18, color: Color(0xFFE2E8F0)),
                                    // 体积对比与优化统计
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        Text(
                                          FileSizeFormatter.format(record.originalSizeBytes),
                                          style: const TextStyle(
                                            decoration: TextDecoration.lineThrough,
                                            color: Color(0xFF94A3B8),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 14,
                                          color: Color(0xFF059669),
                                        ),
                                        Text(
                                          FileSizeFormatter.format(record.compressedSizeBytes),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF059669),
                                            fontSize: 14,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF059669),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '-${(record.savingsRatio * 100).toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? colorScheme.surfaceContainerHighest
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            record.removedVideos > 0
                                                ? '优化 ${record.reducedImages}/${record.totalImages} 图 · 移除 ${record.removedVideos} 视频 · ${record.durationSeconds.toStringAsFixed(1)}s'
                                                : '优化 ${record.reducedImages}/${record.totalImages} 图 · ${record.durationSeconds.toStringAsFixed(1)}s',
                                            style: TextStyle(
                                              color: isDark ? colorScheme.onSurfaceVariant : const Color(0xFF64748B),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // 操作按钮独立一行
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        FilledButton.tonalIcon(
                                          onPressed: () => _handleOpenFile(record.outputFilePath),
                                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                                          label: const Text('打开', style: TextStyle(fontSize: 12)),
                                          style: FilledButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              DesktopUtils.revealInFileManager(record.outputFilePath),
                                          icon: Icon(
                                            (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                                                ? Icons.share_rounded
                                                : Icons.folder_open_rounded,
                                            size: 14,
                                          ),
                                          label: Text(
                                            (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                                                ? '分享'
                                                : '定位',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
