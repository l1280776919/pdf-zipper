import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DropTargetCard extends StatefulWidget {
  final Function(List<String> paths) onFilesSelected;

  const DropTargetCard({
    super.key,
    required this.onFilesSelected,
  });

  @override
  State<DropTargetCard> createState() => _DropTargetCardState();
}

class _DropTargetCardState extends State<DropTargetCard> {
  bool _isDragging = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pptx', 'ppt', 'pptm', 'ppsx'],
      dialogTitle: '选择要压缩的 PowerPoint 演示文稿',
    );

    if (result.isNotEmpty) {
      final validPaths = result.map((f) => f.path).whereType<String>().toList();
      if (validPaths.isNotEmpty) {
        widget.onFilesSelected(validPaths);
      }
    }
  }

  Future<void> _pickDirectory() async {
    final selectedDir = await FilePicker.getDirectoryPath(
      dialogTitle: '选择包含 PPTX 文件的文件夹',
    );

    if (selectedDir != null) {
      widget.onFilesSelected([selectedDir]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DropTarget(
      onDragEntered: (detail) => setState(() => _isDragging = true),
      onDragExited: (detail) => setState(() => _isDragging = false),
      onDragDone: (detail) {
        setState(() => _isDragging = false);
        final paths = detail.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) {
          widget.onFilesSelected(paths);
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _pickFiles,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              gradient: isDark
                  ? null
                  : LinearGradient(
                      colors: _isDragging
                          ? [const Color(0xFFCCFBF1), const Color(0xFFE0F2FE)]
                          : [const Color(0xFFF0FDFA), const Color(0xFFF8FAFC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: isDark ? colorScheme.surfaceContainerHighest.withAlpha(80) : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isDragging
                    ? colorScheme.primary
                    : (isDark ? colorScheme.outlineVariant : const Color(0xFF99F6E4).withValues(alpha: 0.8)),
                width: _isDragging ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.0 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部中心浮动图标
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? colorScheme.primaryContainer : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    size: 38,
                    color: isDark ? colorScheme.onPrimaryContainer : const Color(0xFF0D9488),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isDragging ? '松开添加文件' : '点击选择 PPT 文档',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isDragging ? colorScheme.primary : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '支持 .pptx / .ppt / .pptm',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? colorScheme.outline : const Color(0xFF94A3B8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),

                // 操作按钮组
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('选择文件'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickDirectory,
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('选择文件夹'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? colorScheme.primary : const Color(0xFF0F766E),
                        side: BorderSide(
                          color: isDark ? colorScheme.outlineVariant : const Color(0xFF5EEAD4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
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
  }
}

