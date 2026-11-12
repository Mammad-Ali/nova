import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../speedtest/data/datasources/ip_info.dart';
import '../../speedtest/data/export_service.dart';
import '../../speedtest/presentation/providers/speedtest_history_provider.dart';
import '../data/report_card.dart';
import '../data/report_pdf.dart';
import '../domain/provider_report.dart';

/// "Report for your provider": the test history summed up against the plan,
/// saved as a PDF to send with a complaint, or as one image to share.
void showReportSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ReportSheet(),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet();

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  late final TextEditingController _plan = TextEditingController(
    text: switch (ref.read(appSettingsProvider).planMbps) {
      final v? => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v',
      null => '',
    },
  );
  var _period = ReportPeriod.month;
  var _saving = false;

  @override
  void dispose() {
    _plan.dispose();
    super.dispose();
  }

  ProviderReport _report() => ProviderReport.build(
        ref.read(speedTestHistoryProvider),
        _period,
        planMbps: ref.read(appSettingsProvider).planMbps,
      );

  String _fileName(String extension) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'nova-report-${now.year}-${two(now.month)}-${two(now.day)}.$extension';
  }

  Future<void> _save({required bool pdf}) async {
    final t = ref.read(stringsProvider);
    final report = _report();
    final provider = ref.read(ipInfoProvider).asData?.value.isp;
    setState(() => _saving = true);
    String? where;
    try {
      if (pdf) {
        final version = (await PackageInfo.fromPlatform()).version;
        final bytes = await buildReportPdf(report, t, version: version, provider: provider);
        where = await const ExportService().savePdf(bytes, suggestedName: _fileName('pdf'));
      } else {
        final bytes = await renderReportCard(report, t, provider: provider);
        if (bytes != null) {
          where = await const ExportService().savePng(bytes, suggestedName: _fileName('png'));
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (where != null && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(AppStrings.fill(t.reportSaved, [where]))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    ref.watch(appSettingsProvider);
    ref.watch(speedTestHistoryProvider);
    final report = _report();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bg1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.fromBorderSide(BorderSide(color: AppColors.onGlass.withValues(alpha: 0.12))),
        ),
        child: SafeArea(
          top: false,
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.onGlass.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.summarize_rounded, color: AppColors.sun),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.reportMenu,
                            style: TextStyle(color: AppColors.onGlass, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(t.reportIntro, style: TextStyle(color: AppColors.textLo, fontSize: 12.5, height: 1.4)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _plan,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      style: TextStyle(color: AppColors.onGlass),
                      decoration: InputDecoration(
                        labelText: t.reportPlan,
                        helperText: t.reportPlanHint,
                        suffixText: 'Mbps',
                      ),
                      onChanged: (v) => ref
                          .read(appSettingsProvider.notifier)
                          .setPlan(double.tryParse(v.replaceAll(',', '.'))),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final period in ReportPeriod.values)
                          ChoiceChip(
                            label: Text(switch (period) {
                              ReportPeriod.week => t.reportWeek,
                              ReportPeriod.month => t.reportMonth,
                              ReportPeriod.all => t.reportAll,
                            }),
                            selected: period == _period,
                            onSelected: (_) => setState(() => _period = period),
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              color: period == _period ? Colors.black : AppColors.onGlass,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            selectedColor: Colors.white,
                            backgroundColor: AppColors.onGlass.withValues(alpha: 0.06),
                            side: BorderSide(color: AppColors.onGlass.withValues(alpha: 0.14)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (report.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(t.reportEmpty, style: TextStyle(color: AppColors.textMid, fontSize: 13, height: 1.4)),
                      )
                    else ...[
                      Row(
                        children: [
                          _Tile(label: t.reportTests, value: '${report.tests.length}'),
                          const SizedBox(width: 8),
                          _Tile(label: t.reportAvgDown, value: '${mbps(report.avgDown)} Mbps'),
                          const SizedBox(width: 8),
                          _Tile(
                            label: t.reportSlowest,
                            value: '${mbps(report.slowest!.downloadMbps)} Mbps',
                            color: AppColors.red,
                          ),
                        ],
                      ),
                      if (report.planMbps != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _Tile(label: t.reportOfPlan, value: '${(report.shareOfPlan! * 100).round()}%'),
                            const SizedBox(width: 8),
                            _Tile(label: t.reportUnderHalf, value: '${report.underHalf} / ${report.tests.length}'),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _saving ? null : () => _save(pdf: true),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                        label: Text(t.reportSavePdf),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : () => _save(pdf: false),
                        icon: const Icon(Icons.image_outlined, size: 20),
                        label: Text(t.reportSaveImage),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.onGlass,
                          side: BorderSide(color: AppColors.onGlass.withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: glassCard(radius: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textLo, fontSize: 11.5)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: color ?? AppColors.onGlass,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      );
}
