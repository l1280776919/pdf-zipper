import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_record.dart';

class HistoryStats {
  final int totalFiles;
  final int totalOriginalBytes;
  final int totalCompressedBytes;
  final int totalSavedBytes;
  final double averageSavingsRatio;
  final int totalImagesOptimized;

  HistoryStats({
    required this.totalFiles,
    required this.totalOriginalBytes,
    required this.totalCompressedBytes,
    required this.totalSavedBytes,
    required this.averageSavingsRatio,
    required this.totalImagesOptimized,
  });
}

class HistoryStorageService {
  static const String _storageKey = 'pptx_compression_history_v1';

  /// 获取所有历史记录（按时间倒序）
  static Future<List<HistoryRecord>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey);
      if (jsonList == null || jsonList.isEmpty) {
        return [];
      }
      return jsonList
          .map((item) => HistoryRecord.fromJson(item))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      return [];
    }
  }

  /// 添加一条压缩记录
  static Future<void> addRecord(HistoryRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getHistory();
      // 避免重复记录同一ID
      current.removeWhere((item) => item.id == record.id);
      current.insert(0, record);

      final stringList = current.map((r) => r.toJson()).toList();
      await prefs.setStringList(_storageKey, stringList);
    } catch (_) {}
  }

  /// 删除一条记录
  static Future<void> deleteRecord(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getHistory();
      current.removeWhere((item) => item.id == id);
      final stringList = current.map((r) => r.toJson()).toList();
      await prefs.setStringList(_storageKey, stringList);
    } catch (_) {}
  }

  /// 清空所有历史
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  /// 计算全局压缩统计指标
  static HistoryStats calculateStats(List<HistoryRecord> records) {
    if (records.isEmpty) {
      return HistoryStats(
        totalFiles: 0,
        totalOriginalBytes: 0,
        totalCompressedBytes: 0,
        totalSavedBytes: 0,
        averageSavingsRatio: 0.0,
        totalImagesOptimized: 0,
      );
    }

    int totalOriginal = 0;
    int totalCompressed = 0;
    int totalSaved = 0;
    int totalImages = 0;

    for (final r in records) {
      totalOriginal += r.originalSizeBytes;
      totalCompressed += r.compressedSizeBytes;
      totalSaved += r.savedSizeBytes;
      totalImages += r.reducedImages;
    }

    final avgRatio = totalOriginal > 0 ? (totalSaved / totalOriginal) : 0.0;

    return HistoryStats(
      totalFiles: records.length,
      totalOriginalBytes: totalOriginal,
      totalCompressedBytes: totalCompressed,
      totalSavedBytes: totalSaved,
      averageSavingsRatio: avgRatio,
      totalImagesOptimized: totalImages,
    );
  }
}
