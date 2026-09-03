enum TaskStatus {
  pending('等待中'),
  scanning('扫描解包中'),
  compressing('压缩图片中'),
  packaging('打包生成中'),
  completed('已完成'),
  failed('失败');

  final String label;
  const TaskStatus(this.label);
}

class CompressionTask {
  final String id;
  final String filePath;
  final String fileName;
  final int originalSizeBytes;
  
  TaskStatus status;
  double progress; // 0.0 - 1.0
  String statusMessage;
  
  int totalImages;
  int currentImageIndex;
  int imagesReducedCount; // 体积减小的图片数量
  int removedVideos; // 移除的视频数量
  
  int? compressedSizeBytes;
  String? outputPath;
  String? errorMessage;
  DateTime? startTime;
  DateTime? finishTime;

  CompressionTask({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.originalSizeBytes,
    this.status = TaskStatus.pending,
    this.progress = 0.0,
    this.statusMessage = '等待处理',
    this.totalImages = 0,
    this.currentImageIndex = 0,
    this.imagesReducedCount = 0,
    this.removedVideos = 0,
    this.compressedSizeBytes,
    this.outputPath,
    this.errorMessage,
    this.startTime,
    this.finishTime,
  });

  int? get savedSizeBytes {
    if (compressedSizeBytes == null) return null;
    final diff = originalSizeBytes - compressedSizeBytes!;
    return diff > 0 ? diff : 0;
  }

  double? get savingsPercentage {
    if (compressedSizeBytes == null || originalSizeBytes == 0) return null;
    final diff = originalSizeBytes - compressedSizeBytes!;
    if (diff <= 0) return 0.0;
    return (diff / originalSizeBytes) * 100.0;
  }

  Duration? get duration {
    if (startTime == null) return null;
    final end = finishTime ?? DateTime.now();
    return end.difference(startTime!);
  }
}
