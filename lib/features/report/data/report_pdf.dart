import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/l10n/app_strings.dart';
import '../../speedtest/domain/entities/speedtest_record.dart';
import '../domain/provider_report.dart';

/// 05.11.2026 14:30, the form providers read everywhere Nova is used.
String reportDate(DateTime t, {bool time = true}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final day = '${two(t.day)}.${two(t.month)}.${t.year}';
  return time ? '$day ${two(t.hour)}:${two(t.minute)}' : day;
}

String mbps(double v) => v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// The report as a PDF, white and printable: a summary page, then every
/// test, so the provider can check each figure. The text uses Roboto, which
/// has every letter of Nova's five languages; PDF's built-in fonts don't.
Future<Uint8List> buildReportPdf(
  ProviderReport report,
  AppStrings t, {
  required String version,
  String? provider,
}) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  final doc = pw.Document(
    title: t.reportDocTitle,
    creator: 'Nova $version',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  const ink = PdfColor.fromInt(0xFF15171F);
  const grey = PdfColor.fromInt(0xFF6B6F80);
  const line = PdfColor.fromInt(0xFFE3E5EC);
  const tint = PdfColor.fromInt(0xFFF4F5F9);
  const sun = PdfColor.fromInt(0xFFFFC61A);
  const indigo = PdfColor.fromInt(0xFF6366F1);
  const red = PdfColor.fromInt(0xFFE11D48);

  pw.Widget figure(String label, String value, {PdfColor color = ink, String? note}) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: tint, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: const pw.TextStyle(color: grey, fontSize: 8.5)),
              pw.SizedBox(height: 3),
              pw.Text(value, style: pw.TextStyle(color: color, fontSize: 16, fontWeight: pw.FontWeight.bold)),
              if (note != null) pw.Text(note, style: const pw.TextStyle(color: grey, fontSize: 8)),
            ],
          ),
        ),
      );

  final plan = report.planMbps;
  final share = report.shareOfPlan;
  final slowest = report.slowest!;
  final parts = report.byDayPart;
  final slowPart = report.slowestPart;
  String partName(DayPart p) => switch (p) {
        DayPart.night => t.reportNight,
        DayPart.morning => t.reportMorning,
        DayPart.afternoon => t.reportAfternoon,
        DayPart.evening => t.reportEvening,
      };

  final summary = [
    if (plan != null)
      AppStrings.fill(t.reportSummaryPlan, [mbps(report.avgDown), (share! * 100).round().toString(), mbps(plan)])
    else
      AppStrings.fill(t.reportSummaryNoPlan, [mbps(report.avgDown), mbps(report.avgUp)]),
    if (plan != null && report.underHalf! > 0)
      AppStrings.fill(t.reportSummaryUnderHalf, ['${report.underHalf}', '${report.tests.length}']),
    if (slowPart != null)
      AppStrings.fill(t.reportSummarySlowPart, [partName(slowPart), mbps(parts[slowPart]!.avgDown)]),
  ].join(' ');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(t.reportDocTitle, style: const pw.TextStyle(color: grey, fontSize: 9)),
            ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(AppStrings.fill(t.reportGenerated, [reportDate(report.to)]),
              style: const pw.TextStyle(color: grey, fontSize: 8)),
          pw.Text('${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(color: grey, fontSize: 8)),
        ],
      ),
      build: (context) => [
        pw.Container(height: 4, width: 48, color: sun),
        pw.SizedBox(height: 10),
        pw.Text(t.reportDocTitle, style: pw.TextStyle(color: ink, fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          [
            if (provider != null) AppStrings.fill(t.reportProvider, [provider]),
            '${reportDate(report.from, time: false)} – ${reportDate(report.to, time: false)}',
          ].join('   ·   '),
          style: const pw.TextStyle(color: grey, fontSize: 10),
        ),
        pw.SizedBox(height: 18),
        pw.Text(summary, style: const pw.TextStyle(color: ink, fontSize: 11, lineSpacing: 3)),
        pw.SizedBox(height: 16),
        pw.Row(children: [
          figure(t.reportTests, '${report.tests.length}'),
          pw.SizedBox(width: 8),
          figure(t.reportAvgDown, '${mbps(report.avgDown)} Mbps'),
          pw.SizedBox(width: 8),
          figure(t.reportAvgUp, '${mbps(report.avgUp)} Mbps'),
          pw.SizedBox(width: 8),
          figure(t.reportAvgPing, '${report.avgPing.round()} ms'),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          figure(t.reportSlowest, '${mbps(slowest.downloadMbps)} Mbps', color: red, note: reportDate(slowest.timestamp)),
          pw.SizedBox(width: 8),
          figure(t.reportFastest, '${mbps(report.fastest!.downloadMbps)} Mbps',
              note: reportDate(report.fastest!.timestamp)),
          if (plan != null) ...[
            pw.SizedBox(width: 8),
            figure(t.reportOfPlan, '${(share! * 100).round()}%', note: '${mbps(plan)} Mbps'),
            pw.SizedBox(width: 8),
            figure(t.reportUnderHalf, '${report.underHalf} / ${report.tests.length}',
                note: '< ${mbps(plan / 2)} Mbps'),
          ],
        ]),
        pw.SizedBox(height: 20),
        pw.Text(t.reportChart, style: pw.TextStyle(color: ink, fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        _chart(report.tests, plan, indigo: indigo, sun: sun, line: line),
        pw.SizedBox(height: 6),
        pw.Row(children: [
          pw.Container(width: 14, height: 2, color: indigo),
          pw.SizedBox(width: 5),
          pw.Text(t.reportDownload, style: const pw.TextStyle(color: grey, fontSize: 8.5)),
          if (plan != null) ...[
            pw.SizedBox(width: 16),
            pw.Container(width: 14, height: 2, color: sun),
            pw.SizedBox(width: 5),
            pw.Text('${t.reportPlan}: ${mbps(plan)} Mbps', style: const pw.TextStyle(color: grey, fontSize: 8.5)),
          ],
        ]),
        pw.SizedBox(height: 20),
        pw.Text(t.reportByTime, style: pw.TextStyle(color: ink, fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: [t.reportPart, t.reportAvgDown, t.reportTests],
          data: [
            for (final MapEntry(key: part, value: v) in parts.entries)
              [partName(part), '${mbps(v.avgDown)} Mbps', '${v.count}'],
          ],
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: line, width: 0.5)),
          headerStyle: pw.TextStyle(color: grey, fontSize: 9, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(color: ink, fontSize: 10),
          headerAlignment: pw.Alignment.centerLeft,
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 24),
        pw.Text(t.reportEveryTest, style: pw.TextStyle(color: ink, fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: [
            t.reportDate,
            t.reportDownload,
            t.reportUpload,
            t.reportPing,
            if (plan != null) t.reportOfPlan,
          ],
          data: [
            for (final test in report.tests.reversed)
              [
                reportDate(test.timestamp),
                mbps(test.downloadMbps),
                mbps(test.uploadMbps),
                test.pingMs.round().toString(),
                if (plan != null) '${(test.downloadMbps / plan * 100).round()}%',
              ],
          ],
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: line, width: 0.5)),
          headerStyle: pw.TextStyle(color: grey, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(color: ink, fontSize: 9),
          cellAlignments: {0: pw.Alignment.centerLeft},
          cellAlignment: pw.Alignment.centerRight,
          headerAlignments: {0: pw.Alignment.centerLeft},
          headerAlignment: pw.Alignment.centerRight,
          cellFormat: (column, data) => '$data',
          cellDecoration: plan == null
              ? null
              : (index, data, row) {
                  // The tests under half the plan, in pale red.
                  final test = report.tests.reversed.elementAt(row - 1);
                  return test.downloadMbps < plan / 2
                      ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFDECEF))
                      : const pw.BoxDecoration();
                },
        ),
        pw.SizedBox(height: 20),
        pw.Text(AppStrings.fill(t.reportMethod, [version]),
            style: const pw.TextStyle(color: grey, fontSize: 8.5, lineSpacing: 2)),
      ],
    ),
  );
  return doc.save();
}

/// Download over the period: a line through the tests, the plan dashed.
pw.Widget _chart(
  List<SpeedTestRecord> tests,
  double? plan, {
  required PdfColor indigo,
  required PdfColor sun,
  required PdfColor line,
}) {
  const height = 120.0;
  return pw.LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints!.maxWidth;
      return pw.CustomPaint(
        size: PdfPoint(width, height),
        painter: (canvas, size) {
          final top = math.max(tests.map((t) => t.downloadMbps).fold<double>(1, math.max), plan ?? 0) * 1.1;
          final first = tests.first.timestamp.millisecondsSinceEpoch.toDouble();
          final span = math.max(1.0, tests.last.timestamp.millisecondsSinceEpoch - first);
          double x(SpeedTestRecord t) =>
              tests.length == 1 ? size.x / 2 : (t.timestamp.millisecondsSinceEpoch - first) / span * size.x;
          // PDF drawing starts at the bottom left.
          double y(double v) => v / top * size.y;

          canvas
            ..setStrokeColor(line)
            ..setLineWidth(0.5)
            ..drawLine(0, 0, size.x, 0)
            ..strokePath();
          if (plan != null) {
            canvas
              ..setStrokeColor(sun)
              ..setLineWidth(1)
              ..setLineDashPattern([4, 3])
              ..drawLine(0, y(plan), size.x, y(plan))
              ..strokePath()
              ..setLineDashPattern();
          }
          canvas
            ..setStrokeColor(indigo)
            ..setLineWidth(1.4)
            ..moveTo(x(tests.first), y(tests.first.downloadMbps));
          for (final t in tests.skip(1)) {
            canvas.lineTo(x(t), y(t.downloadMbps));
          }
          canvas.strokePath();
          canvas.setFillColor(indigo);
          for (final t in tests) {
            canvas
              ..drawEllipse(x(t), y(t.downloadMbps), 1.6, 1.6)
              ..fillPath();
          }
        },
      );
    },
  );
}
