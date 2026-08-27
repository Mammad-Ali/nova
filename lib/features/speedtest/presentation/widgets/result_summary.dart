import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/ip_info.dart';
import '../../data/export_service.dart';
import '../../data/share_card_renderer.dart';
import '../../domain/entities/speed_grade.dart';
import '../providers/speedtest_history_provider.dart';

/// Result summary: the A+…E grade, the personal best, a comparison with the
/// previous test, and buttons to copy or save the result.
class ResultSummary extends ConsumerWidget {
  const ResultSummary({
    super.key,
    required this.strings,
    required this.download,
    required this.upload,
    required this.ping,
    required this.jitter,
  });

  final AppStrings strings;
  final double download;
  final double upload;
  final double ping;
  final double jitter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(speedTestHistoryProvider);
    final grade = gradeForDownload(download);
    final color = _tierColor(grade.tier);

    // Personal best and the previous-test comparison both come from history.
    final downloads = history.map((r) => r.downloadMbps).toList();
    final personalBest =
        downloads.isEmpty ? download : downloads.reduce(math.max);
    final prev = history.length >= 2 ? history[history.length - 2] : null;
    final bestBefore = history.length >= 2
        ? history
            .sublist(0, history.length - 1)
            .map((r) => r.downloadMbps)
            .reduce(math.max)
        : null;
    final isRecord = bestBefore != null && download > bestBefore + 0.01;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCard(glow: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.overall,
                  style: TextStyle(
                    color: AppColors.onGlass,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Saving writes a file through a native save dialog; the web
              // build keeps copy-to-clipboard only.
              if (!kIsWeb)
                _IconAction(
                  icon: Icons.image_outlined,
                  label: strings.saveImage,
                  onTap: () => _saveImage(context, ref),
                ),
              _IconAction(
                icon: Icons.copy_rounded,
                label: strings.copyResult,
                onTap: () => _copy(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _GradeBadge(letter: grade.letter, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tierLabel(strings, grade.tier),
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.emoji_events_rounded,
                            size: 14, color: AppColors.amber),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${strings.personalBest}: ${_fmt(personalBest)} Mbps',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textMid,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isRecord) _RecordChip(label: strings.newRecord),
            ],
          ),
          if (prev != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DeltaChip(
                    label: strings.download,
                    current: download,
                    previous: prev.downloadMbps,
                    suffix: strings.vsLast,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DeltaChip(
                    label: strings.upload,
                    current: upload,
                    previous: prev.uploadMbps,
                    suffix: strings.vsLast,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Renders the result card and offers to save it as a file.
  Future<void> _saveImage(BuildContext context, WidgetRef ref) async {
    final info = ref.read(ipInfoProvider).asData?.value;
    final grade = gradeForDownload(download);
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')}.'
        '${now.month.toString().padLeft(2, '0')}.${now.year}';

    final bytes = await renderShareCard(ShareCardData(
      downloadMbps: download,
      uploadMbps: upload,
      pingMs: ping,
      jitterMs: jitter,
      grade: grade.letter,
      provider: info?.hasIsp == true ? info!.isp : null,
      dateLabel: date,
      downloadLabel: strings.download,
      uploadLabel: strings.upload,
      pingLabel: strings.ping,
      jitterLabel: strings.jitter,
    ));
    if (bytes == null || !context.mounted) return;

    final path = await const ExportService().savePng(bytes);
    if (path == null || !context.mounted) return;
    _toast(context, '${strings.savedTo}: $path');
  }

  void _copy(BuildContext context, WidgetRef ref) {
    final info = ref.read(ipInfoProvider).asData?.value;
    final grade = gradeForDownload(download);
    final buffer = StringBuffer()
      ..writeln('Nova — speedtest')
      ..writeln('${strings.download}: ${_fmt(download)} Mbps')
      ..writeln('${strings.upload}: ${_fmt(upload)} Mbps')
      ..writeln('${strings.ping}: ${_fmt(ping)} ms')
      ..writeln('${strings.jitter}: ${_fmt(jitter)} ms')
      ..writeln('${strings.overall}: ${grade.letter}');
    if (info != null && info.hasIsp) {
      buffer.writeln('${strings.providerLabel}: ${info.isp}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    _toast(context, strings.copied);
  }

  static void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
      ));
  }
}

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.letter, required this.color});
  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 18,
              spreadRadius: -4),
        ],
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}

class _RecordChip extends StatelessWidget {
  const _RecordChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.amber,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.label,
    required this.current,
    required this.previous,
    required this.suffix,
  });

  final String label;
  final double current;
  final double previous;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final valid = previous > 0.01;
    final pct = valid ? (current - previous) / previous * 100 : 0.0;
    final up = pct >= 0;
    final color = !valid
        ? AppColors.textMid
        : (up ? AppColors.green : AppColors.red);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.onGlass.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.onGlass.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label · $suffix',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textLo, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(
                up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 2),
              Text(
                valid ? '${pct.abs().toStringAsFixed(0)}%' : '—',
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: AppColors.nebulaViolet),
      tooltip: label,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }
}

Color _tierColor(SpeedTier tier) => switch (tier) {
      SpeedTier.blazing => AppColors.green,
      SpeedTier.fast => AppColors.accentDown,
      SpeedTier.good => AppColors.accentInfo,
      SpeedTier.moderate => AppColors.amber,
      SpeedTier.slow => AppColors.red,
    };

String _tierLabel(AppStrings t, SpeedTier tier) => switch (tier) {
      SpeedTier.blazing => t.gradeBlazing,
      SpeedTier.fast => t.gradeFast,
      SpeedTier.good => t.gradeGood,
      SpeedTier.moderate => t.gradeModerate,
      SpeedTier.slow => t.gradeSlow,
    };

String _fmt(double v) => v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
