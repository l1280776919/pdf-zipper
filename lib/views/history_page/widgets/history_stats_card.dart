import 'package:flutter/material.dart';
import '../../../services/history_storage_service.dart';
import '../../../utils/file_size_formatter.dart';

class HistoryStatsCard extends StatelessWidget {
  final HistoryStats stats;

  const HistoryStatsCard({
    super.key,
    required this.stats,
  });

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required Color accentColor,
    required String value,
    required String label,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? colorScheme.outlineVariant : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.0 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? accentColor.withOpacity(0.15) : iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final item1 = _buildStatItem(
          context: context,
          icon: Icons.description_outlined,
          iconBgColor: const Color(0xFFE0F2FE),
          accentColor: const Color(0xFF0284C7),
          value: '${stats.totalFiles} 份',
          label: '累计瘦身 PPT',
        );
        final item2 = _buildStatItem(
          context: context,
          icon: Icons.cloud_done_outlined,
          iconBgColor: const Color(0xFFDCFCE7),
          accentColor: const Color(0xFF059669),
          value: FileSizeFormatter.format(stats.totalSavedBytes),
          label: '累计节省空间',
        );
        final item3 = _buildStatItem(
          context: context,
          icon: Icons.pie_chart_outline_rounded,
          iconBgColor: const Color(0xFFFEF3C7),
          accentColor: const Color(0xFFD97706),
          value: FileSizeFormatter.formatRatio(stats.averageSavingsRatio),
          label: '平均瘦身比率',
        );
        final item4 = _buildStatItem(
          context: context,
          icon: Icons.photo_library_outlined,
          iconBgColor: const Color(0xFFF3E8FF),
          accentColor: const Color(0xFF7C3AED),
          value: '${stats.totalImagesOptimized} 张',
          label: '优化内嵌图片',
        );

        if (constraints.maxWidth > 720) {
          return Row(
            children: [
              Expanded(child: item1),
              const SizedBox(width: 10),
              Expanded(child: item2),
              const SizedBox(width: 10),
              Expanded(child: item3),
              const SizedBox(width: 10),
              Expanded(child: item4),
            ],
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: item1),
                  const SizedBox(width: 10),
                  Expanded(child: item2),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: item3),
                  const SizedBox(width: 10),
                  Expanded(child: item4),
                ],
              ),
            ],
          );
        }
      },
    );
  }
}
