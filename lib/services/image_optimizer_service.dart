import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/compression_config.dart';

class OptimizationResult {
  final Uint8List data;
  final bool wasOptimized;
  final int originalSize;
  final int optimizedSize;
  final String format;
  final bool hadAlpha;

  OptimizationResult({
    required this.data,
    required this.wasOptimized,
    required this.originalSize,
    required this.optimizedSize,
    required this.format,
    required this.hadAlpha,
  });
}

class ImageOptimizerService {
  /// 优化单张图片，严格确保透明通道不丢失，且压缩后体积若增大则自动回退原图
  static OptimizationResult optimizeImage({
    required Uint8List bytes,
    required String extension,
    required CompressionConfig config,
  }) {
    final lowerExt = extension.toLowerCase();
    final originalSize = bytes.length;

    // 只对 JPG/JPEG 和 PNG 进行压缩处理。
    // EMF, WMF, SVG, TIFF, 以及视频媒体等一律原样保留，防止矢量或专用图元损坏
    if (lowerExt != '.png' &&
        lowerExt != '.jpg' &&
        lowerExt != '.jpeg') {
      return OptimizationResult(
        data: bytes,
        wasOptimized: false,
        originalSize: originalSize,
        optimizedSize: originalSize,
        format: lowerExt,
        hadAlpha: false,
      );
    }

    try {
      img.Image? decoded;
      if (lowerExt == '.png') {
        decoded = img.decodePng(bytes) ?? img.decodeImage(bytes);
      } else {
        decoded = img.decodeJpg(bytes) ?? img.decodeImage(bytes);
      }

      if (decoded == null) {
        // 解码失败（可能是特殊色彩配置文件或异常格式），安全返回原数据
        return OptimizationResult(
          data: bytes,
          wasOptimized: false,
          originalSize: originalSize,
          optimizedSize: originalSize,
          format: lowerExt,
          hadAlpha: false,
        );
      }

      final hasAlpha = decoded.hasAlpha;

      // 1. 分辨率尺寸缩放计算（保持纵横比，不拉伸）
      img.Image processedImage = decoded;
      final maxDim = config.maxDimension;
      if (maxDim != null && maxDim > 0) {
        final curW = decoded.width;
        final curH = decoded.height;
        final largerDim = curW > curH ? curW : curH;

        if (largerDim > maxDim) {
          int newW, newH;
          if (curW >= curH) {
            newW = maxDim;
            newH = ((curH * maxDim) / curW).round();
          } else {
            newH = maxDim;
            newW = ((curW * maxDim) / curH).round();
          }
          if (newW > 0 && newH > 0) {
            // 使用三次卷积或线性插值，同时保留 RGBA 四通道（包含Alpha透明度）
            processedImage = img.copyResize(
              decoded,
              width: newW,
              height: newH,
              interpolation: img.Interpolation.linear,
            );
          }
        }
      }

      // 2. 重新编码（严格维持原文件格式，绝对不改变文件类型以防止破坏 PPTX 内部关系）
      Uint8List compressedData;
      if (lowerExt == '.png') {
        // PNG 压缩：
        // 严格保留透明通道（RGBA）。如果原本有透明通道，保证其依然存在且透明像素无黑底变质
        compressedData = img.encodePng(
          processedImage,
          level: config.pngLevel,
        );
      } else {
        // JPEG 压缩：
        compressedData = img.encodeJpg(
          processedImage,
          quality: config.jpgQuality,
        );
      }

      // 3. 安全兜底判断：
      // 如果压缩后体积未减小（甚至反向变大），或者数据异常，则坚决使用原图数据
      if (config.keepIfLarger && compressedData.length >= originalSize) {
        return OptimizationResult(
          data: bytes,
          wasOptimized: false,
          originalSize: originalSize,
          optimizedSize: originalSize,
          format: lowerExt,
          hadAlpha: hasAlpha,
        );
      }

      return OptimizationResult(
        data: compressedData,
        wasOptimized: compressedData.length < originalSize,
        originalSize: originalSize,
        optimizedSize: compressedData.length,
        format: lowerExt,
        hadAlpha: hasAlpha,
      );
    } catch (e) {
      // 任何异常情况下均兜底返回原图数据，确保不破坏 PPT
      return OptimizationResult(
        data: bytes,
        wasOptimized: false,
        originalSize: originalSize,
        optimizedSize: originalSize,
        format: lowerExt,
        hadAlpha: false,
      );
    }
  }
}
