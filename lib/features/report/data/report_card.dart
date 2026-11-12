import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/provider_report.dart';
import 'report_pdf.dart' show mbps, reportDate;

/// The report on one image, portrait, to send in a chat: the period, the
/// averages, the slowest test, and how much of the plan arrived.
Future<Uint8List?> renderReportCard(ProviderReport report, AppStrings t, {String? provider}) async {
  const w = 1080.0, h = 1350.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF10142A), Color(0xFF04050A)],
      ).createShader(const Rect.fromLTWH(0, 0, w, h)),
  );
  canvas.drawCircle(
    const Offset(w, 0),
    520,
    Paint()
      ..shader = RadialGradient(colors: [AppColors.sun.withValues(alpha: 0.16), AppColors.sun.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: const Offset(w, 0), radius: 520)),
  );
  final rnd = math.Random(5);
  final star = Paint();
  for (var i = 0; i < 110; i++) {
    star.color = AppColors.onGlass.withValues(alpha: rnd.nextDouble() * 0.45 + 0.08);
    canvas.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * h), rnd.nextDouble() * 1.8 + 0.4, star);
  }

  _text(canvas, 'Nova', const Offset(72, 72), size: 48, weight: FontWeight.w900, color: AppColors.sun);
  // The title may take two lines in some languages: what follows flows.
  var head = 136.0;
  head += _text(canvas, t.reportDocTitle, Offset(72, head), size: 54, weight: FontWeight.w800, maxWidth: w - 144);
  head += 12;
  head += _text(
    canvas,
    [
      ?provider,
      '${reportDate(report.from, time: false)} – ${reportDate(report.to, time: false)}',
    ].join('  ·  '),
    Offset(72, head),
    size: 28,
    color: AppColors.textMid,
    maxWidth: w - 144,
  );

  // Three tiles: average, slowest, how many tests.
  final top = math.max(300.0, head + 44);
  const tileW = (w - 144 - 48) / 3, tileH = 200.0;
  final tiles = [
    (t.reportAvgDown, mbps(report.avgDown), 'Mbps', AppColors.onGlass),
    (t.reportSlowest, mbps(report.slowest!.downloadMbps), 'Mbps', AppColors.red),
    (t.reportTests, '${report.tests.length}', '', AppColors.onGlass),
  ];
  for (var i = 0; i < tiles.length; i++) {
    final (label, value, unit, color) = tiles[i];
    final left = 72 + i * (tileW + 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, top, tileW, tileH), const Radius.circular(28)),
      Paint()..color = AppColors.onGlass.withValues(alpha: 0.07),
    );
    _text(canvas, label, Offset(left + 28, top + 28), size: 26, color: AppColors.textMid, maxWidth: tileW - 56);
    _text(canvas, value, Offset(left + 28, top + 76), size: 68, weight: FontWeight.w900, color: color);
    if (unit.isNotEmpty) _text(canvas, unit, Offset(left + 30, top + 154), size: 24, color: AppColors.textLo);
  }

  var y = top + tileH + 48;
  final plan = report.planMbps;
  if (plan != null) {
    // A bar: how much of the plan arrived on average.
    final share = report.shareOfPlan!.clamp(0.0, 1.0);
    final box = RRect.fromRectAndRadius(Rect.fromLTWH(72, y, w - 144, 270), const Radius.circular(28));
    canvas.drawRRect(box, Paint()..color = AppColors.onGlass.withValues(alpha: 0.07));
    _text(canvas, AppStrings.fill(t.reportCardPlan, [mbps(plan)]), Offset(100, y + 28), size: 28,
        color: AppColors.textMid, maxWidth: w - 200);
    _text(canvas, '${(report.shareOfPlan! * 100).round()}%', Offset(100, y + 74), size: 76,
        weight: FontWeight.w900, color: share >= 0.8 ? AppColors.green : share >= 0.5 ? AppColors.amber : AppColors.red);
    final barTop = y + 178;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(100, barTop, w - 200, 16), const Radius.circular(8)),
      Paint()..color = AppColors.onGlass.withValues(alpha: 0.10),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(100, barTop, (w - 200) * share, 16), const Radius.circular(8)),
      Paint()..color = AppColors.accentDown,
    );
    _text(
      canvas,
      AppStrings.fill(t.reportCardUnderHalf, ['${report.underHalf}', '${report.tests.length}']),
      Offset(100, barTop + 34),
      size: 26,
      color: AppColors.textMid,
      maxWidth: w - 200,
    );
    y += 270 + 40;
  }

  // The rest of the story, in words.
  final slowPart = report.slowestPart;
  final lines = [
    AppStrings.fill(t.reportCardAverages, [mbps(report.avgUp), report.avgPing.round().toString()]),
    AppStrings.fill(t.reportCardSlowest, [reportDate(report.slowest!.timestamp)]),
    if (slowPart != null)
      AppStrings.fill(t.reportSummarySlowPart, [
        switch (slowPart) {
          DayPart.night => t.reportNight,
          DayPart.morning => t.reportMorning,
          DayPart.afternoon => t.reportAfternoon,
          DayPart.evening => t.reportEvening,
        },
        mbps(report.byDayPart[slowPart]!.avgDown),
      ]),
  ];
  for (final line in lines) {
    y += _text(canvas, line, Offset(72, y), size: 30, color: AppColors.onGlass, maxWidth: w - 144) + 18;
  }

  _text(canvas, t.reportCardFooter, const Offset(72, h - 96), size: 24, color: AppColors.textLo, maxWidth: w - 144);

  final picture = recorder.endRecording();
  final image = await picture.toImage(w.toInt(), h.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes?.buffer.asUint8List();
}

/// Paints [text] at [at], wrapping at [maxWidth]; returns its height.
double _text(
  Canvas canvas,
  String text,
  Offset at, {
  required double size,
  Color color = Colors.white,
  FontWeight weight = FontWeight.w500,
  double? maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight, height: 1.25)),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth ?? double.infinity);
  painter.paint(canvas, at);
  return painter.height;
}
