import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/compression_task.dart';
import '../../../utils/desktop_utils.dart';
import '../../../utils/file_size_formatter.dart';

class TaskItemTile extends StatelessWidget {
  final CompressionTask task;
  final VoidCallback onRemove;
  final VoidCallback? onStartSingle;

  const TaskItemTile({
    super.key,
    required this.task,
    required this.onRemove,
    this.onStartSingle,
  });

  Color _getStatusColor(BuildContext context, TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return const Color(0xFF94A3B8);
      case TaskStatus.scanning:
      case TaskStatus.compressing:
      case TaskStatus.packaging:
        return const Color(0xFF0D9488); // Fresh Teal
      case TaskStatus.completed:
        return const Color(0xFF059669); // Emerald Green
      case TaskStatus.failed:
        return const Color(0xFFE11D48); // Rose Red
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor(context, task.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.status == TaskStatus.completed
              ? const Color(0xFFA7F3D0)
              : task.status == TaskStatus.failed
                  ? const Color(0xFFFECDD3)
                  : (isDark ? colorScheme.outlineVariant : const Color(0xFFE2E8F0)),
          width: task.status == TaskStatus.completed ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.0 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：PPT 图标、名称、状态徽章、操作
            Row(
              children: [
                // 清新优雅的 PPT 标志
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B4A), Color(0xFFFF8E53)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B4A).withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.slideshow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // 文件名与路径
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '原始大小: ${FileSizeFormatter.format(task.originalSizeBytes)}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 状态胶囊
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (task.status == TaskStatus.compressing ||
                          task.status == TaskStatus.scanning ||
                          task.status == TaskStatus.packaging)
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: statusColor,
                            ),
                          ),
                        ),
                      Text(
                        task.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // 单任务快速启动与移除
                if (task.status == TaskStatus.pending && onStartSingle != null)
                  IconButton(
                    icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF0D9488)),
                    tooltip: '立即压缩此文件',
                    onPressed: onStartSingle,
                  ),
                if (task.status != TaskStatus.compressing &&
                    task.status != TaskStatus.packaging)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                    tooltip: '移出队列',
                    onPressed: onRemove,
                  ),
              ],
            ),

            // 第二行：进度条（在进行中展示）
            if (task.status != TaskStatus.pending && task.status != TaskStatus.completed) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: task.progress > 0 ? task.progress : null,
                  backgroundColor: isDark ? colorScheme.surfaceContainerHighest : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      task.statusMessage,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task.status == TaskStatus.compressing)
                    Text(
                      '${(task.progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                ],
              ),
            ],

            // 完成状态：清新的成效展示与操作栏
            if (task.status == TaskStatus.completed) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? colorScheme.surfaceContainerHighest.withAlpha(50) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? colorScheme.outlineVariant : const Color(0xFFDCFCE7),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 体积变化与优化统计
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          FileSizeFormatter.format(task.originalSizeBytes),
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF059669)),
                        Text(
                          FileSizeFormatter.format(task.compressedSizeBytes ?? 0),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                            fontSize: 14,
                          ),
                        ),
                        if (task.savingsPercentage != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '-${task.savingsPercentage!.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Text(
                          '优化 ${task.imagesReducedCount}/${task.totalImages} 图',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 快捷按钮独立成行
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () {
                            if (task.outputPath != null) {
                              DesktopUtils.openFile(task.outputPath!);
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('打开', style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFCCFBF1),
                            foregroundColor: const Color(0xFF0F766E),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (task.outputPath != null) {
                              DesktopUtils.revealInFileManager(task.outputPath!);
                            }
                          },
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
                            foregroundColor: const Color(0xFF059669),
                            side: const BorderSide(color: Color(0xFF86EFAC)),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // 失败详情
            if (task.status == TaskStatus.failed && task.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? colorScheme.errorContainer.withAlpha(50) : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? colorScheme.outlineVariant : const Color(0xFFFECDD3),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFE11D48),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFBE123C),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
