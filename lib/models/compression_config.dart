enum CompressionPreset {
  highQuality('高质量', '适合大屏演示与高清投影', 85, 6, 2560),
  balanced('推荐', '画质与体积的最佳平衡', 75, 6, 1920),
  aggressive('强力', '最大程度压缩文件体积', 60, 9, 1280),
  custom('自定义', '手动调节压缩参数', 75, 6, 1920);

  final String label;
  final String description;
  final int defaultJpgQuality;
  final int defaultPngLevel;
  final int? defaultMaxDimension;

  const CompressionPreset(
    this.label,
    this.description,
    this.defaultJpgQuality,
    this.defaultPngLevel,
    this.defaultMaxDimension,
  );
}

enum MaxDimensionOption {
  noResize('保持原分辨率', null),
  k4('4K 超高清 (3840px)', 3840),
  k2('2K 高清 (2048px)', 2048),
  fhd('1080P 全高清 (1920px)', 1920),
  hd('720P 标清 (1280px)', 1280);

  final String label;
  final int? dimension;

  const MaxDimensionOption(this.label, this.dimension);

  static MaxDimensionOption fromDimension(int? dim) {
    if (dim == null) return MaxDimensionOption.noResize;
    for (final opt in MaxDimensionOption.values) {
      if (opt.dimension == dim) return opt;
    }
    return MaxDimensionOption.fhd;
  }
}

class CompressionConfig {
  CompressionPreset preset;
  int jpgQuality; // 10-100
  int pngLevel; // 1-9
  int? maxDimension; // e.g. 1920, or null
  bool keepIfLarger; // 仅当压缩后尺寸更小时替换，安全兜底
  bool preserveAlpha; // 严格保留透明通道（强制为true）
  String? customOutputDir; // 自定义输出目录，若为空则在源文件同级目录输出
  String outputSuffix; // 压缩文件后缀，默认为 "_compressed"

  CompressionConfig({
    this.preset = CompressionPreset.balanced,
    int? jpgQuality,
    int? pngLevel,
    int? maxDimension,
    this.keepIfLarger = true,
    this.preserveAlpha = true,
    this.customOutputDir,
    this.outputSuffix = '_compressed',
  })  : jpgQuality = jpgQuality ?? preset.defaultJpgQuality,
        pngLevel = pngLevel ?? preset.defaultPngLevel,
        maxDimension = maxDimension ?? preset.defaultMaxDimension;

  void applyPreset(CompressionPreset newPreset) {
    preset = newPreset;
    if (newPreset != CompressionPreset.custom) {
      jpgQuality = newPreset.defaultJpgQuality;
      pngLevel = newPreset.defaultPngLevel;
      maxDimension = newPreset.defaultMaxDimension;
    }
  }

  CompressionConfig copyWith({
    CompressionPreset? preset,
    int? jpgQuality,
    int? pngLevel,
    int? maxDimension,
    bool? keepIfLarger,
    bool? preserveAlpha,
    String? customOutputDir,
    String? outputSuffix,
  }) {
    return CompressionConfig(
      preset: preset ?? this.preset,
      jpgQuality: jpgQuality ?? this.jpgQuality,
      pngLevel: pngLevel ?? this.pngLevel,
      maxDimension: maxDimension ?? this.maxDimension,
      keepIfLarger: keepIfLarger ?? this.keepIfLarger,
      preserveAlpha: preserveAlpha ?? this.preserveAlpha,
      customOutputDir: customOutputDir ?? this.customOutputDir,
      outputSuffix: outputSuffix ?? this.outputSuffix,
    );
  }
}
