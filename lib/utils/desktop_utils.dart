import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class DesktopUtils {
  /// 打开文件（使用系统关联的默认程序，支持 Android / iOS / Windows / macOS / Linux）
  static Future<OpenResult> openFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return OpenResult(
        type: ResultType.fileNotFound,
        message: '文件不存在或已被删除',
      );
    }

    final lower = filePath.toLowerCase();
    String? mimeType;
    if (lower.endsWith('.pptx')) {
      mimeType = 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    } else if (lower.endsWith('.ppt')) {
      mimeType = 'application/vnd.ms-powerpoint';
    }

    final result = await OpenFilex.open(filePath, type: mimeType);
    if (result.type != ResultType.done && mimeType != null) {
      return await OpenFilex.open(filePath);
    }
    return result;
  }

  /// 分享文件（针对手机端 Android / iOS）
  static Future<void> shareFile(String filePath, {String? text}) async {
    final xfile = XFile(filePath);
    await SharePlus.instance.share(
      ShareParams(
        files: [xfile],
        text: text ?? '分享已瘦身的 PPT 演示文稿',
      ),
    );
  }

  /// 在系统文件管理器中定位并选中文件，或在手机端调起系统分享
  static Future<void> revealInFileManager(String filePath) async {
    final file = File(filePath);

    if (Platform.isAndroid || Platform.isIOS) {
      // 手机端：调起系统分享菜单，可一键发送至微信、QQ、网盘或保存到文件管理
      await shareFile(filePath);
      return;
    }

    if (!file.existsSync()) {
      final dir = Directory(filePath);
      if (dir.existsSync()) {
        await OpenFilex.open(filePath);
      }
      return;
    }

    if (Platform.isWindows) {
      final winPath = filePath.replaceAll('/', '\\');
      await Process.run('explorer.exe', ['/select,', winPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      final parentDir = file.parent.path;
      await Process.run('xdg-open', [parentDir]);
    } else {
      await OpenFilex.open(file.parent.path);
    }
  }

  /// 打开文件夹
  static Future<void> openDirectory(String dirPath) async {
    if (kIsWeb) return;

    if (Platform.isAndroid || Platform.isIOS) {
      // 手机端直接使用系统关联器尝试打开
      await OpenFilex.open(dirPath);
      return;
    }

    if (Platform.isWindows) {
      final winPath = dirPath.replaceAll('/', '\\');
      await Process.run('explorer.exe', [winPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [dirPath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dirPath]);
    } else {
      await OpenFilex.open(dirPath);
    }
  }
}
