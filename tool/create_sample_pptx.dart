// ignore_for_file: avoid_print
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

void main() {
  print('正在生成用于测试的 PPTX 演示文稿...');

  // 1. 创建一张带透明通道的 PNG 图标（200x200，中间彩色徽标，背景完全透明）
  final png = img.Image(width: 200, height: 200, numChannels: 4);
  for (int y = 0; y < 200; y++) {
    for (int x = 0; x < 200; x++) {
      final dist = (x - 100) * (x - 100) + (y - 100) * (y - 100);
      if (dist <= 60 * 60) {
        png.setPixelRgba(x, y, 230, 80, 40, 255); // 鲜亮橙色
      } else {
        png.setPixelRgba(x, y, 0, 0, 0, 0); // 完全透明
      }
    }
  }
  final pngBytes = img.encodePng(png);

  // 2. 创建一张超大分辨率的高清 JPEG（3000x2000，画质98，体积约数MB）
  final jpg = img.Image(width: 3000, height: 2000, numChannels: 3);
  for (int y = 0; y < 2000; y += 4) {
    for (int x = 0; x < 3000; x += 4) {
      jpg.setPixelRgb(x, y, (x * 7) % 255, (y * 5) % 255, ((x + y) * 3) % 255);
    }
  }
  final jpgBytes = img.encodeJpg(jpg, quality: 98);

  // 3. 打包为合法的 OpenXML PPTX
  final archive = Archive();
  archive.addFile(ArchiveFile('[Content_Types].xml', 14, '<?xml ... />'.codeUnits));
  archive.addFile(ArchiveFile('ppt/presentation.xml', 14, '<p:presentation/>'.codeUnits));
  archive.addFile(ArchiveFile('ppt/slides/slide1.xml', 14, '<p:sld/>'.codeUnits));
  archive.addFile(ArchiveFile('ppt/slides/_rels/slide1.xml.rels', 14, '<Relationships/>'.codeUnits));
  archive.addFile(ArchiveFile('ppt/media/image1.png', pngBytes.length, pngBytes));
  archive.addFile(ArchiveFile('ppt/media/image2.jpeg', jpgBytes.length, jpgBytes));

  final zipData = ZipEncoder().encode(archive);
  final outputFile = File('测试演示文稿.pptx');
  outputFile.writeAsBytesSync(zipData);

  print('测试文件生成完毕！');
  print('路径: ${outputFile.absolute.path}');
  print('体积: ${(outputFile.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB');
  print('包含: 1张透明背景 PNG，1张超大超高清 JPEG');
}
