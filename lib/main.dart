import 'package:flutter/material.dart';
import 'views/main_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PptxCompressorApp());
}

class PptxCompressorApp extends StatefulWidget {
  const PptxCompressorApp({super.key});

  @override
  State<PptxCompressorApp> createState() => _PptxCompressorAppState();
}

class _PptxCompressorAppState extends State<PptxCompressorApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 清新轻快的主色调：薄荷青蓝 (Fresh Teal)
    const seedColor = Color(0xFF0D9488);

    return MaterialApp(
      title: 'PPT 瘦身大师 - PPTX 图片压缩工具',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // 清爽浅灰底色
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
        ),
        fontFamily: 'Segoe UI',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Segoe UI',
      ),
      home: MainLayout(
        onToggleTheme: _toggleTheme,
        themeMode: _themeMode,
      ),
    );
  }
}
