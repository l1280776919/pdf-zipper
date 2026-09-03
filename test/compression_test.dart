import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Verify image and archive compatibility', () {
    // 1. Create a transparent PNG image
    final image = img.Image(width: 100, height: 100, numChannels: 4);
    // Fill with transparent color (A=0) except a center square (A=255)
    for (int y = 0; y < 100; y++) {
      for (int x = 0; x < 100; x++) {
        if (x >= 25 && x < 75 && y >= 25 && y < 75) {
          image.setPixelRgba(x, y, 255, 0, 0, 255); // Red opaque
        } else {
          image.setPixelRgba(x, y, 0, 0, 0, 0); // Transparent
        }
      }
    }

    final pngBytes = img.encodePng(image);
    expect(pngBytes.isNotEmpty, true);

    // Decode and verify alpha channel
    final decoded = img.decodePng(pngBytes)!;
    expect(decoded.hasAlpha, true);
    final transparentPixel = decoded.getPixel(10, 10);
    expect(transparentPixel.a, 0);
    final opaquePixel = decoded.getPixel(50, 50);
    expect(opaquePixel.a, 255);
    expect(opaquePixel.r, 255);

    // 2. Test Archive creation and ZipDecoder/ZipEncoder
    final archive = Archive();
    archive.addFile(ArchiveFile('ppt/presentation.xml', 10, 'dummy xml'.codeUnits));
    archive.addFile(ArchiveFile('ppt/media/image1.png', pngBytes.length, pngBytes));

    final zipData = ZipEncoder().encode(archive);
    expect(zipData, isNotNull);

    final decodedArchive = ZipDecoder().decodeBytes(zipData);
    expect(decodedArchive.files.length, 2);
    final imageFile = decodedArchive.findFile('ppt/media/image1.png');
    expect(imageFile, isNotNull);
    final decodedPngFromZip = img.decodePng(imageFile!.content)!;
    expect(decodedPngFromZip.hasAlpha, true);
    expect(decodedPngFromZip.getPixel(10, 10).a, 0);
  });
}
