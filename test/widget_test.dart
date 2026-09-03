import 'package:flutter_test/flutter_test.dart';
import 'package:ppt_zipper/main.dart';

void main() {
  testWidgets('PptxCompressorApp smoke test', (WidgetTester tester) async {
    // Build app and trigger frame
    await tester.pumpWidget(const PptxCompressorApp());

    // Verify app title and navigation items exist
    expect(find.text('PPT 瘦身大师'), findsOneWidget);
    expect(find.text('压缩工作台'), findsOneWidget);
    expect(find.text('压缩历史记录'), findsOneWidget);
  });
}
