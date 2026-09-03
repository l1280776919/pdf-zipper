import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MediaScannerService {
  static const MethodChannel _channel = MethodChannel('com.example.ppt_zipper/media_store');

  /// 广播通知 Android 系统媒体库与最近文件数据库索引新文件
  /// 使得手机文件管理器的“最近文件”、微信/钉钉选择文件时能够立刻读取并显示该文件
  static Future<void> notifySystemScan(String filePath) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scanFile', {'filePath': filePath});
    } catch (_) {}
  }
}
