import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/core/l10n/app_strings.dart';
import 'package:net_pulse/features/report/data/report_pdf.dart';
import 'package:net_pulse/features/report/domain/provider_report.dart';
import 'package:net_pulse/features/speedtest/domain/entities/speedtest_record.dart';

SpeedTestRecord record(DateTime t, double down) =>
    SpeedTestRecord(timestamp: t, downloadMbps: down, uploadMbps: down / 2, pingMs: 20, jitterMs: 2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 12, 23);
  // Mornings fast, evenings slow, over ten days.
  final history = [
    for (var d = 0; d < 10; d++) ...[
      record(now.subtract(Duration(days: d, hours: 14)), 90), // 09:00
      record(now.subtract(Duration(days: d, hours: 2)), 30), // 21:00
    ],
  ];

  test('figures against the plan', () {
    final r = ProviderReport.build(history, ReportPeriod.week, planMbps: 100, now: now);
    expect(r.tests.length, 14);
    expect(r.avgDown, 60);
    expect(r.shareOfPlan, 0.6);
    expect(r.underHalf, 7);
    expect(r.slowest!.downloadMbps, 30);
    expect(r.slowestPart, DayPart.evening);
    expect(r.tests.first.timestamp.isBefore(r.tests.last.timestamp), isTrue);
  });

  test('no plan, no plan figures', () {
    final r = ProviderReport.build(history, ReportPeriod.all, now: now);
    expect(r.tests.length, 20);
    expect(r.shareOfPlan, isNull);
    expect(r.underHalf, isNull);
  });

  test('the PDF builds in every language', () async {
    // The fonts come from the asset bundle; in tests, from disk.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets',
        (message) async {
      final key = Uri.decodeFull(const StringCodec().decodeMessage(message)!);
      return ByteData.sublistView(File(key).readAsBytesSync());
    });
    final r = ProviderReport.build(history, ReportPeriod.month, planMbps: 100, now: now);
    for (final locale in AppLocale.values) {
      final strings = AppStrings.of(locale);
      final bytes = await buildReportPdf(r, strings, version: '1.6.0', provider: 'Aztelekom LLC');
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(10000));
    }
  });
}
