import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/compression_config.dart';
import '../models/compression_task.dart';
import 'image_optimizer_service.dart';

class PptxCompressionResult {
  final bool success;
  final String sourcePath;
  final String outputPath;
  final int originalSize;
  final int compressedSize;
  final int totalImages;
  final int reducedImages;
  final String? error;

  PptxCompressionResult({
    required this.success,
    required this.sourcePath,
    required this.outputPath,
    required this.originalSize,
    required this.compressedSize,
    required this.totalImages,
    required this.reducedImages,
    this.error,
  });
}

class PptxProgressUpdate {
  final TaskStatus status;
  final double progress;
  final String message;
  final int totalImages;
  final int currentImageIndex;
  final int imagesReducedCount;

  PptxProgressUpdate({
    required this.status,
    required this.progress,
    required this.message,
    this.totalImages = 0,
    this.currentImageIndex = 0,
    this.imagesReducedCount = 0,
  });
}

class _WorkerParams {
  final SendPort sendPort;
  final String inputPath;
  final String outputPath;
  final CompressionConfig config;

  _WorkerParams({
    required this.sendPort,
    required this.inputPath,
    required this.outputPath,
    required this.config,
  });
}

class PptxCompressorService {
  /// 计算输出文件路径：默认按选择文件的原始路径保存，仅修改文件名（添加后缀）
  static Future<String> getOutputFilePath(String inputPath, CompressionConfig config) async {
    final ext = p.extension(inputPath);
    final baseName = p.basenameWithoutExtension(inputPath);
    final outFileName = '$baseName${config.outputSuffix}$ext';

    if (config.customOutputDir != null && config.customOutputDir!.isNotEmpty) {
      return p.join(config.customOutputDir!, outFileName);
    }

    final originalDir = p.dirname(inputPath);

    // 1. 测试原文件所在目录是否实际具有写入权限
    bool isOriginalDirWritable = false;
    if (originalDir.isNotEmpty &&
        !originalDir.contains('/cache/file_picker') &&
        !originalDir.contains('\\cache\\file_picker')) {
      try {
        final dir = Directory(originalDir);
        if (dir.existsSync()) {
          final testPath = p.join(originalDir, '.tmp_test_write_${DateTime.now().millisecondsSinceEpoch}');
          final testFile = File(testPath);
          testFile.writeAsStringSync('test');
          if (testFile.existsSync()) {
            testFile.deleteSync();
            isOriginalDirWritable = true;
          }
        }
      } catch (_) {
        isOriginalDirWritable = false;
      }
    }

    if (isOriginalDirWritable) {
      return p.join(originalDir, outFileName);
    }

    // 2. 安卓端公共 Download 目录测试是否具有写入权限
    if (!kIsWeb && Platform.isAndroid) {
      const publicDownload = '/storage/emulated/0/Download';
      try {
        final downloadDir = Directory(publicDownload);
        if (downloadDir.existsSync()) {
          final testPath = p.join(publicDownload, '.tmp_test_write_${DateTime.now().millisecondsSinceEpoch}');
          final testFile = File(testPath);
          testFile.writeAsStringSync('test');
          if (testFile.existsSync()) {
            testFile.deleteSync();
            return p.join(publicDownload, outFileName);
          }
        }
      } catch (_) {}
    }

    // 3. 外部存储应用专用目录（在 Android 上完全免申请权限，且第三方软件可通过分享读取）
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final extDirs = await getExternalStorageDirectories(type: StorageDirectory.documents);
        if (extDirs != null && extDirs.isNotEmpty) {
          final extPath = extDirs.first.path;
          return p.join(extPath, outFileName);
        }
      } catch (_) {}
    }

    // 4. 兜底至应用专属文档目录
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      return p.join(docsDir.path, outFileName);
    } catch (_) {}

    return p.join(originalDir, outFileName);
  }

  /// 检查文件类型
  static void validateFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('文件不存在: $filePath');
    }

    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.ppt') {
      // 检查是否为旧版二进制 PPT
      final header = file.openSync().readSync(8);
      if (header.length >= 8 &&
          header[0] == 0xD0 &&
          header[1] == 0xCF &&
          header[2] == 0x11 &&
          header[3] == 0xE0) {
        throw Exception(
          '检测到该文件为 Office 97-2003 旧版二进制格式 (.ppt)。\n'
          '建议在 PowerPoint 中打开该文件并【另存为 .pptx】格式，然后再使用本工具进行高效无损压缩。',
        );
      }
    }

    if (ext != '.pptx' && ext != '.ppt' && ext != '.pptm' && ext != '.ppsx') {
      throw Exception('不支持的文件格式 ($ext)，仅支持 PowerPoint 演示文稿 (.pptx, .pptm, .ppsx)');
    }
  }

  /// 异步执行压缩任务，并通过 Stream 发送进度更新
  static Stream<PptxProgressUpdate> compressAsync({
    required String inputPath,
    required String outputPath,
    required CompressionConfig config,
    required Completer<PptxCompressionResult> completer,
  }) async* {
    validateFile(inputPath);

    final receivePort = ReceivePort();
    final workerParams = _WorkerParams(
      sendPort: receivePort.sendPort,
      inputPath: inputPath,
      outputPath: outputPath,
      config: config,
    );

    // 在独立 Isolate 中执行繁重的图片解压、缩放与重编码任务，杜绝主线程卡顿
    final isolate = await Isolate.spawn(_compressWorker, workerParams);

    try {
      await for (final message in receivePort) {
        if (message is PptxProgressUpdate) {
          yield message;
        } else if (message is PptxCompressionResult) {
          completer.complete(message);
          break;
        } else if (message is Map && message.containsKey('error')) {
          final errorMsg = message['error'] as String;
          completer.complete(
            PptxCompressionResult(
              success: false,
              sourcePath: inputPath,
              outputPath: outputPath,
              originalSize: File(inputPath).lengthSync(),
              compressedSize: 0,
              totalImages: 0,
              reducedImages: 0,
              error: errorMsg,
            ),
          );
          break;
        }
      }
    } finally {
      receivePort.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }

  /// 后台 Isolate 实际工作函数
  static void _compressWorker(_WorkerParams params) {
    final sendPort = params.sendPort;
    final inputPath = params.inputPath;
    final outputPath = params.outputPath;
    final config = params.config;

    try {
      sendPort.send(
        PptxProgressUpdate(
          status: TaskStatus.scanning,
          progress: 0.05,
          message: '正在读取并解析 PPTX 文件结构...',
        ),
      );

      final inputFile = File(inputPath);
      final originalBytes = inputFile.readAsBytesSync();
      final originalSize = originalBytes.length;

      // 验证 ZIP 魔数 (PK..)
      if (originalBytes.length < 4 ||
          originalBytes[0] != 0x50 ||
          originalBytes[1] != 0x4B) {
        throw Exception('文件不是合法的 PPTX/ZIP 格式或已损坏。');
      }

      final archive = ZipDecoder().decodeBytes(originalBytes);

      // 筛选 ppt/media/ 下的图片条目
      final allFiles = archive.files;
      final imageEntries = <ArchiveFile>[];

      for (final file in allFiles) {
        if (!file.isFile) continue;
        final name = file.name.toLowerCase();
        if (name.contains('ppt/media/') || name.contains('media/')) {
          if (name.endsWith('.png') ||
              name.endsWith('.jpg') ||
              name.endsWith('.jpeg')) {
            imageEntries.add(file);
          }
        }
      }

      final totalImages = imageEntries.length;
      int reducedImages = 0;

      sendPort.send(
        PptxProgressUpdate(
          status: TaskStatus.scanning,
          progress: 0.15,
          message: '共扫描到 $totalImages 张可优化图片，准备压缩...',
          totalImages: totalImages,
          currentImageIndex: 0,
        ),
      );

      // 新建 Archive，将非图片文件直接保留，图片文件视优化结果替换
      final newArchive = Archive();
      final imageMap = {for (var img in imageEntries) img.name: img};

      for (int i = 0; i < totalImages; i++) {
        final imgFile = imageEntries[i];
        final fileName = p.basename(imgFile.name);
        final ext = p.extension(imgFile.name);

        final currentProgress = 0.15 + ((i + 1) / (totalImages == 0 ? 1 : totalImages)) * 0.70;

        sendPort.send(
          PptxProgressUpdate(
            status: TaskStatus.compressing,
            progress: currentProgress,
            message: '正在优化 ($fileName) [${i + 1}/$totalImages]...',
            totalImages: totalImages,
            currentImageIndex: i + 1,
            imagesReducedCount: reducedImages,
          ),
        );

        final rawBytes = imgFile.content;

        final optResult = ImageOptimizerService.optimizeImage(
          bytes: rawBytes,
          extension: ext,
          config: config,
        );

        if (optResult.wasOptimized) {
          reducedImages++;
          // 保持原文件名与扩展名，仅更新内容与大小，确保 PPTX 内部 XML 关联 100% 完整
          final newImgFile = ArchiveFile(
            imgFile.name,
            optResult.data.length,
            optResult.data,
          );
          imageMap[imgFile.name] = newImgFile;
        }
      }

      sendPort.send(
        PptxProgressUpdate(
          status: TaskStatus.packaging,
          progress: 0.88,
          message: '正在重新生成并封装 PPTX 文档...',
          totalImages: totalImages,
          currentImageIndex: totalImages,
          imagesReducedCount: reducedImages,
        ),
      );

      // 组装新 Archive，按原顺序添加所有文件
      for (final file in allFiles) {
        if (imageMap.containsKey(file.name)) {
          newArchive.addFile(imageMap[file.name]!);
        } else {
          newArchive.addFile(file);
        }
      }

      // 重新打包为 ZIP
      final zipData = ZipEncoder().encode(newArchive);
      if (zipData.isEmpty) {
        throw Exception('PPTX 打包失败，生成数据为空。');
      }

      // 确保目标目录存在并尝试写入
      File outFile = File(outputPath);
      String actualOutputPath = outputPath;

      try {
        final outDir = Directory(p.dirname(actualOutputPath));
        if (!outDir.existsSync()) {
          outDir.createSync(recursive: true);
        }
        outFile.writeAsBytesSync(zipData);
      } catch (e) {
        // 若写入目标目录遭遇系统权限拒绝，自动降级写入系统临时安全目录，保证压缩顺利完成
        try {
          final tempDir = Directory.systemTemp;
          final fallbackPath = p.join(tempDir.path, p.basename(outputPath));
          outFile = File(fallbackPath);
          outFile.writeAsBytesSync(zipData);
          actualOutputPath = fallbackPath;
        } catch (e2) {
          throw Exception('保存压缩文件失败: $e');
        }
      }

      final finalSize = outFile.lengthSync();

      sendPort.send(
        PptxProgressUpdate(
          status: TaskStatus.completed,
          progress: 1.0,
          message: '压缩完成！',
          totalImages: totalImages,
          currentImageIndex: totalImages,
          imagesReducedCount: reducedImages,
        ),
      );

      sendPort.send(
        PptxCompressionResult(
          success: true,
          sourcePath: inputPath,
          outputPath: actualOutputPath,
          originalSize: originalSize,
          compressedSize: finalSize,
          totalImages: totalImages,
          reducedImages: reducedImages,
        ),
      );
    } catch (e, stack) {
      sendPort.send({
        'error': '处理失败: ${e.toString()}',
        'stack': stack.toString(),
      });
    }
  }
}
