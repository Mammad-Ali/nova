import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/comfort.dart';

/// The "what this speed is good for" card: a list of activities with ratings.
class ComfortSection extends StatelessWidget {
  const ComfortSection({
    super.key,
    required this.strings,
    required this.download,
    required this.upload,
    required this.ping,
  });

  final AppStrings strings;
  final double download;
  final double upload;
  final double ping;

  @override
  Widget build(BuildContext context) {
    final items = evaluateComfort(
      download: download,
      upload: upload,
      ping: ping,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.comfortTitle,
            style: TextStyle(
              color: AppColors.onGlass,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          for (final item in items) _ComfortRow(strings: strings, item: item),
        ],
      ),
    );
  }
}

class _ComfortRow extends StatelessWidget {
  const _ComfortRow({required this.strings, required this.item});

  final AppStrings strings;
  final ComfortItem item;

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(item.level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(_activityIcon(item.activity), size: 18, color: AppColors.textMid),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _activityLabel(strings, item.activity),
              style: TextStyle(color: AppColors.onGlass, fontSize: 14),
            ),
          ),
          _LevelPill(color: color, label: _levelLabel(strings, item.level)),
        ],
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color _levelColor(ComfortLevel level) => switch (level) {
      ComfortLevel.poor => AppColors.red,
      ComfortLevel.ok => AppColors.amber,
      ComfortLevel.good => AppColors.accentDown,
      ComfortLevel.great => AppColors.green,
    };

String _levelLabel(AppStrings t, ComfortLevel level) => switch (level) {
      ComfortLevel.poor => t.levelPoor,
      ComfortLevel.ok => t.levelOk,
      ComfortLevel.good => t.levelGood,
      ComfortLevel.great => t.levelGreat,
    };

IconData _activityIcon(ComfortActivity a) => switch (a) {
      ComfortActivity.browsing => Icons.public_rounded,
      ComfortActivity.hdVideo => Icons.smart_display_rounded,
      ComfortActivity.video4k => Icons.four_k_rounded,
      ComfortActivity.gaming => Icons.sports_esports_rounded,
      ComfortActivity.videoCalls => Icons.videocam_rounded,
      ComfortActivity.streaming => Icons.podcasts_rounded,
      ComfortActivity.bigDownloads => Icons.download_for_offline_rounded,
    };

String _activityLabel(AppStrings t, ComfortActivity a) => switch (a) {
      ComfortActivity.browsing => t.actBrowsing,
      ComfortActivity.hdVideo => t.actHdVideo,
      ComfortActivity.video4k => t.act4k,
      ComfortActivity.gaming => t.actGaming,
      ComfortActivity.videoCalls => t.actVideoCalls,
      ComfortActivity.streaming => t.actStreaming,
      ComfortActivity.bigDownloads => t.actBigDownloads,
    };
