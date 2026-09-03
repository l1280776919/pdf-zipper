import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../models/compression_config.dart';
import '../../models/compression_task.dart';
import '../../models/history_record.dart';
import '../../services/history_storage_service.dart';
import '../../services/pptx_compressor_service.dart';
import 'widgets/config_panel.dart';
import 'widgets/drop_target_card.dart';
import 'widgets/task_item_tile.dart';

class CompressPage extends StatefulWidget {
  final VoidCallback onHistoryUpdated;

  const CompressPage({
    super.key,
    required this.onHistoryUpdated,
  });

  @override
  State<CompressPage> createState() => _CompressPageState();
}

class _CompressPageState extends State<CompressPage> {
  final List<CompressionTask> _tasks = [];
  CompressionConfig _config = CompressionConfig();
  bool _isProcessingBatch = false;

  void _addFiles(List<String> paths) {
    final newFiles = <String>[];

    for (final path in paths) {
      if (FileSystemEntity.isDirectorySync(path)) {
        // 递归或同级扫描文件夹
        try {
          final dir = Directory(path);
          final entities = dir.listSync(recursive: true);
          for (final entity in entities) {
            if (entity is File) {
              final ext = p.extension(entity.path).toLowerCase();
              if (['.pptx', '.ppt', '.pptm', '.ppsx'].contains(ext)) {
                newFiles.add(entity.path);
              }
            }
          }
        } catch (_) {}
      } else {
        final ext = p.extension(path).toLowerCase();
        if (['.pptx', '.ppt', '.pptm', '.ppsx'].contains(ext)) {
          newFiles.add(path);
        }
      }
    }

    if (newFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未找到有效的 PPT/PPTX 文件'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      for (final filePath in newFiles.reversed) {
        // 避免重复加入
        if (_tasks.any((t) => t.filePath == filePath)) continue;

        final file = File(filePath);
        final size = file.existsSync() ? file.lengthSync() : 0;
        final task = CompressionTask(
          id: '${DateTime.now().microsecondsSinceEpoch}_${_tasks.length}',
          filePath: filePath,
          fileName: p.basename(filePath),
          originalSizeBytes: size,
        );
        _tasks.insert(0, task); // 新任务置顶展示
      }
    });
  }

  void _removeTask(String id) {
    setState(() {
      _tasks.removeWhere((t) => t.id == id);
    });
  }

  void _clearAllTasks() {
    if (_isProcessingBatch) return;
    setState(() {
      _tasks.clear();
    });
  }

  Future<void> _processTask(CompressionTask task) async {
    if (task.status == TaskStatus.compressing ||
        task.status == TaskStatus.packaging) {
      return;
    }

    setState(() {
      task.status = TaskStatus.scanning;
      task.progress = 0.05;
      task.statusMessage = '准备压缩...';
      task.startTime = DateTime.now();
      task.errorMessage = null;
    });

    final outputPath = await PptxCompressorService.getOutputFilePath(
      task.filePath,
      _config,
    );
    final completer = Completer<PptxCompressionResult>();

    try {
      final stream = PptxCompressorService.compressAsync(
        inputPath: task.filePath,
        outputPath: outputPath,
        config: _config,
        completer: completer,
      );

      final subscription = stream.listen((update) {
        if (!mounted) return;
        setState(() {
          task.status = update.status;
          task.progress = update.progress;
          task.statusMessage = update.message;
          task.totalImages = update.totalImages;
          task.currentImageIndex = update.currentImageIndex;
          task.imagesReducedCount = update.imagesReducedCount;
        });
      });

      final result = await completer.future;
      await subscription.cancel();

      if (!mounted) return;

      if (result.success) {
        final endTime = DateTime.now();
        final durationSec = endTime.difference(task.startTime!).inMilliseconds / 1000.0;

        setState(() {
          task.status = TaskStatus.completed;
          task.progress = 1.0;
          task.statusMessage = '压缩成功！';
          task.compressedSizeBytes = result.compressedSize;
          task.outputPath = result.outputPath;
          task.finishTime = endTime;
          task.totalImages = result.totalImages;
          task.imagesReducedCount = result.reducedImages;
        });

        // 写入本地历史记录
        final historyRecord = HistoryRecord(
          id: task.id,
          sourceFilePath: task.filePath,
          fileName: task.fileName,
          outputFilePath: result.outputPath,
          originalSizeBytes: task.originalSizeBytes,
          compressedSizeBytes: result.compressedSize,
          savedSizeBytes: (task.originalSizeBytes - result.compressedSize) > 0
              ? (task.originalSizeBytes - result.compressedSize)
              : 0,
          savingsRatio: task.originalSizeBytes > 0
              ? ((task.originalSizeBytes - result.compressedSize) / task.originalSizeBytes)
              : 0.0,
          totalImages: result.totalImages,
          reducedImages: result.reducedImages,
          timestamp: endTime,
          durationSeconds: durationSec,
        );

        await HistoryStorageService.addRecord(historyRecord);
        widget.onHistoryUpdated();
      } else {
        setState(() {
          task.status = TaskStatus.failed;
          task.errorMessage = result.error ?? '压缩失败';
          task.statusMessage = '处理失败';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        task.status = TaskStatus.failed;
        task.errorMessage = e.toString().replaceFirst('Exception: ', '');
        task.statusMessage = '处理出错';
      });
    }
  }

  Future<void> _startAllPending() async {
    if (_isProcessingBatch) return;

    final pendingTasks = _tasks.where((t) => t.status == TaskStatus.pending).toList();
    if (pendingTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('队列中没有待处理的任务'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessingBatch = true);

    for (final task in pendingTasks) {
      if (!mounted) break;
      await _processTask(task);
    }

    if (mounted) {
      setState(() => _isProcessingBatch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingCount = _tasks.where((t) => t.status == TaskStatus.pending).length;
    final completedCount = _tasks.where((t) => t.status == TaskStatus.completed).length;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 16 : 28,
          vertical: isNarrow ? 16 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 直接进入内容区，无多余冗余文字

            // 1. 拖拽与选择文件入口
            DropTargetCard(
              onFilesSelected: _addFiles,
            ),
            const SizedBox(height: 18),

            // 2. 压缩参数配置面板
            ConfigPanel(
              config: _config,
              onConfigChanged: (newConfig) {
                setState(() => _config = newConfig);
              },
            ),
            const SizedBox(height: 20),

            // 3. 任务队列状态栏
            if (_tasks.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '任务队列 (${_tasks.length})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (completedCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '已完成 $completedCount',
                            style: const TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      if (!_isProcessingBatch && _tasks.isNotEmpty)
                        TextButton.icon(
                          onPressed: _clearAllTasks,
                          icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                          label: const Text('清空', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                          ),
                        ),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        onPressed: (_isProcessingBatch || pendingCount == 0)
                            ? null
                            : _startAllPending,
                        icon: _isProcessingBatch
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(
                          _isProcessingBatch ? '处理中...' : '压缩全部 ($pendingCount)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 任务列表条目
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return TaskItemTile(
                    key: ValueKey(task.id),
                    task: task,
                    onRemove: () => _removeTask(task.id),
                    onStartSingle: () => _processTask(task),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
