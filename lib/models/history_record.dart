import 'dart:convert';

class HistoryRecord {
  final String id;
  final String sourceFilePath;
  final String fileName;
  final String outputFilePath;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final int savedSizeBytes;
  final double savingsRatio;
  final int totalImages;
  final int reducedImages;
  final int removedVideos;
  final DateTime timestamp;
  final double durationSeconds;

  HistoryRecord({
    required this.id,
    required this.sourceFilePath,
    required this.fileName,
    required this.outputFilePath,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.savedSizeBytes,
    required this.savingsRatio,
    required this.totalImages,
    required this.reducedImages,
    this.removedVideos = 0,
    required this.timestamp,
    required this.durationSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sourceFilePath': sourceFilePath,
      'fileName': fileName,
      'outputFilePath': outputFilePath,
      'originalSizeBytes': originalSizeBytes,
      'compressedSizeBytes': compressedSizeBytes,
      'savedSizeBytes': savedSizeBytes,
      'savingsRatio': savingsRatio,
      'totalImages': totalImages,
      'reducedImages': reducedImages,
      'removedVideos': removedVideos,
      'timestamp': timestamp.toIso8601String(),
      'durationSeconds': durationSeconds,
    };
  }

  factory HistoryRecord.fromMap(Map<String, dynamic> map) {
    return HistoryRecord(
      id: map['id'] as String,
      sourceFilePath: map['sourceFilePath'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      outputFilePath: map['outputFilePath'] as String? ?? '',
      originalSizeBytes: map['originalSizeBytes'] as int? ?? 0,
      compressedSizeBytes: map['compressedSizeBytes'] as int? ?? 0,
      savedSizeBytes: map['savedSizeBytes'] as int? ?? 0,
      savingsRatio: (map['savingsRatio'] as num?)?.toDouble() ?? 0.0,
      totalImages: map['totalImages'] as int? ?? 0,
      reducedImages: map['reducedImages'] as int? ?? 0,
      removedVideos: map['removedVideos'] as int? ?? 0,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      durationSeconds: (map['durationSeconds'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory HistoryRecord.fromJson(String source) =>
      HistoryRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
