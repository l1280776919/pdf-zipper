import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:ppt_zipper/models/compression_config.dart';
import 'package:ppt_zipper/models/history_record.dart';
import 'package:ppt_zipper/services/history_storage_service.dart';
import 'package:ppt_zipper/services/pptx_compressor_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pptx_test_');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('E2E PPTX compression with transparent PNG and large JPEG', () async {
    // 1. 生成一张带透明通道的 PNG（200x200，中间圆形不透明，四周完全透明）
    final pngImage = img.Image(width: 200, height: 200, numChannels: 4);
    for (int y = 0; y < 200; y++) {
      for (int x = 0; x < 200; x++) {
        final dist = (x - 100) * (x - 100) + (y - 100) * (y - 100);
        if (dist <= 50 * 50) {
          pngImage.setPixelRgba(x, y, 255, 120, 0, 255); // 橙色不透明
        } else {
          pngImage.setPixelRgba(x, y, 0, 0, 0, 0); // 完全透明
        }
      }
    }
    final rawPngBytes = img.encodePng(pngImage);

    // 2. 生成一张超高分辨率的大 JPEG（2400x1600）
    final jpgImage = img.Image(width: 2400, height: 1600, numChannels: 3);
    for (int y = 0; y < 1600; y += 10) {
      for (int x = 0; x < 2400; x += 10) {
        jpgImage.setPixelRgb(x, y, (x % 255), (y % 255), 180);
      }
    }
    final rawJpgBytes = img.encodeJpg(jpgImage, quality: 98);

    // 3. 构建模拟 PPTX (ZIP) 结构
    final dummyPptxArchive = Archive();
    dummyPptxArchive.addFile(ArchiveFile('[Content_Types].xml', 12, '<?xml ... />'.codeUnits));
    dummyPptxArchive.addFile(ArchiveFile('ppt/presentation.xml', 12, '<p:presentation/>'.codeUnits));
    dummyPptxArchive.addFile(ArchiveFile('ppt/slides/_rels/slide1.xml.rels', 12, '<Relationships/>'.codeUnits));
    dummyPptxArchive.addFile(ArchiveFile('ppt/media/image1.png', rawPngBytes.length, rawPngBytes));
    dummyPptxArchive.addFile(ArchiveFile('ppt/media/image2.jpeg', rawJpgBytes.length, rawJpgBytes));

    final pptxBytes = ZipEncoder().encode(dummyPptxArchive);
    final inputPptxPath = p.join(tempDir.path, 'sample_presentation.pptx');
    File(inputPptxPath).writeAsBytesSync(pptxBytes);

    final originalFileSize = File(inputPptxPath).lengthSync();
    expect(originalFileSize, greaterThan(0));

    // 4. 配置压缩参数（推荐平衡模式：最大边长1920，JPEG质量75，保留透明通道）
    final config = CompressionConfig(
      preset: CompressionPreset.balanced,
      maxDimension: 1920,
      jpgQuality: 75,
      keepIfLarger: true,
      preserveAlpha: true,
    );

    final outputPath = await PptxCompressorService.getOutputFilePath(inputPptxPath, config);

    // 5. 执行优化
    final completer = PptxCompressorService.compressAsync(
      inputPath: inputPptxPath,
      outputPath: outputPath,
      config: config,
      completer: Completer<PptxCompressionResult>(),
    );

    final updates = <PptxProgressUpdate>[];
    await for (final u in completer) {
      updates.add(u);
    }

    expect(File(outputPath).existsSync(), isTrue);
    final compressedFileSize = File(outputPath).lengthSync();

    // 压缩后的体积应显著小于原体积
    expect(compressedFileSize, lessThan(originalFileSize));

    // 6. 解包压缩后的 PPTX 校验内部完整性与透明度
    final compressedArchive = ZipDecoder().decodeBytes(File(outputPath).readAsBytesSync());
    expect(compressedArchive.findFile('[Content_Types].xml'), isNotNull);
    expect(compressedArchive.findFile('ppt/presentation.xml'), isNotNull);

    // 校验 PNG
    final compressedPngFile = compressedArchive.findFile('ppt/media/image1.png')!;
    final verifiedPng = img.decodePng(compressedPngFile.content)!;
    expect(verifiedPng.hasAlpha, isTrue, reason: 'PNG 必须保留透明通道');
    expect(verifiedPng.getPixel(10, 10).a, 0, reason: '四周必须依然是全透明');
    expect(verifiedPng.getPixel(100, 100).a, 255, reason: '中心点依然不透明');

    // 校验 JPEG（应被缩放至 1920 宽）
    final compressedJpgFile = compressedArchive.findFile('ppt/media/image2.jpeg')!;
    final verifiedJpg = img.decodeJpg(compressedJpgFile.content)!;
    expect(verifiedJpg.width, 1920, reason: '超大图应等比重采样至设定上限 1920');

    // 7. 测试历史记录读写
    final record = HistoryRecord(
      id: 'test_id_1',
      sourceFilePath: inputPptxPath,
      fileName: 'sample_presentation.pptx',
      outputFilePath: outputPath,
      originalSizeBytes: originalFileSize,
      compressedSizeBytes: compressedFileSize,
      savedSizeBytes: originalFileSize - compressedFileSize,
      savingsRatio: (originalFileSize - compressedFileSize) / originalFileSize,
      totalImages: 2,
      reducedImages: 2,
      timestamp: DateTime.now(),
      durationSeconds: 1.2,
    );

    await HistoryStorageService.addRecord(record);
    final history = await HistoryStorageService.getHistory();
    expect(history.length, 1);
    expect(history.first.fileName, 'sample_presentation.pptx');

    final stats = HistoryStorageService.calculateStats(history);
    expect(stats.totalFiles, 1);
    expect(stats.totalSavedBytes, originalFileSize - compressedFileSize);
    expect(stats.averageSavingsRatio, greaterThan(0));
  });
}
