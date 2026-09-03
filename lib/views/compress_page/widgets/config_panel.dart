import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../models/compression_config.dart';

class ConfigPanel extends StatefulWidget {
  final CompressionConfig config;
  final ValueChanged<CompressionConfig> onConfigChanged;

  const ConfigPanel({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  State<ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends State<ConfigPanel> {
  bool _isExpanded = false;

  Future<void> _selectCustomOutputDir() async {
    final selected = await FilePicker.getDirectoryPath(
      dialogTitle: '选择压缩后文件存放的文件夹',
      initialDirectory: widget.config.customOutputDir,
    );
    if (selected != null) {
      widget.onConfigChanged(
        widget.config.copyWith(customOutputDir: selected),
      );
    }
  }

  void _clearCustomOutputDir() {
    final updated = widget.config.copyWith();
    updated.customOutputDir = null;
    widget.onConfigChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final config = widget.config;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? colorScheme.outlineVariant : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '压缩设置',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF64748B),
                ),
                tooltip: _isExpanded ? '收起设置' : '展开高级设置',
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 预设模式切换栏
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<CompressionPreset>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              segments: CompressionPreset.values.map((preset) {
                return ButtonSegment<CompressionPreset>(
                  value: preset,
                  label: Text(
                    preset.label,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
              selected: {config.preset},
              onSelectionChanged: (Set<CompressionPreset> newSelection) {
                final newPreset = newSelection.first;
                setState(() {
                  config.applyPreset(newPreset);
                  widget.onConfigChanged(config);
                });
              },
            ),
          ),

          // 高级展开参数
          if (_isExpanded || config.preset == CompressionPreset.custom) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 520;

                final dimSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '最大图片分辨率限制：',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<MaxDimensionOption>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                      initialValue: MaxDimensionOption.fromDimension(config.maxDimension),
                      items: MaxDimensionOption.values.map((opt) {
                        return DropdownMenuItem<MaxDimensionOption>(
                          value: opt,
                          child: Text(opt.label, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (opt) {
                        if (opt != null) {
                          setState(() {
                            config.maxDimension = opt.dimension;
                            if (config.preset != CompressionPreset.custom) {
                              config.preset = CompressionPreset.custom;
                            }
                            widget.onConfigChanged(config);
                          });
                        }
                      },
                    ),
                  ],
                );

                final outDirSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '输出目录设置：',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            config.customOutputDir ?? '默认输出至应用私有文档目录 (自动添加 _compressed 后缀)',
                            style: TextStyle(
                              fontSize: 12,
                              color: config.customOutputDir != null
                                  ? colorScheme.onSurface
                                  : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (config.customOutputDir != null)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            tooltip: '重置为原目录',
                            onPressed: _clearCustomOutputDir,
                          ),
                        OutlinedButton.icon(
                          onPressed: _selectCustomOutputDir,
                          icon: const Icon(Icons.folder_open, size: 14),
                          label: const Text('更改目录', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      dimSection,
                      const SizedBox(height: 14),
                      outDirSection,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: dimSection),
                    const SizedBox(width: 16),
                    Expanded(child: outDirSection),
                  ],
                );
              },
            ),

            // 自定义滑块
            if (config.preset == CompressionPreset.custom) ...[
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;
                  final jpgSlider = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('JPEG 压缩画质: ${config.jpgQuality}%', style: const TextStyle(fontSize: 13)),
                      Slider(
                        value: config.jpgQuality.toDouble(),
                        activeColor: const Color(0xFF0D9488),
                        min: 30,
                        max: 95,
                        divisions: 13,
                        label: '${config.jpgQuality}%',
                        onChanged: (val) {
                          setState(() {
                            config.jpgQuality = val.toInt();
                            widget.onConfigChanged(config);
                          });
                        },
                      ),
                    ],
                  );
                  final pngSlider = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PNG 压缩等级: ${config.pngLevel}', style: const TextStyle(fontSize: 13)),
                      Slider(
                        value: config.pngLevel.toDouble(),
                        activeColor: const Color(0xFF0D9488),
                        min: 1,
                        max: 9,
                        divisions: 8,
                        label: '${config.pngLevel}',
                        onChanged: (val) {
                          setState(() {
                            config.pngLevel = val.toInt();
                            widget.onConfigChanged(config);
                          });
                        },
                      ),
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        jpgSlider,
                        const SizedBox(height: 8),
                        pngSlider,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: jpgSlider),
                      const SizedBox(width: 20),
                      Expanded(child: pngSlider),
                    ],
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}
