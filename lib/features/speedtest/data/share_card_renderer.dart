import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Данные для карточки-картинки с результатом теста.
class ShareCardData {
  const ShareCardData({
    required this.downloadMbps,
    required this.uploadMbps,
    required this.pingMs,
    required this.jitterMs,
    required this.grade,
    this.provider,
    this.serverName,
    required this.dateLabel,
    required this.downloadLabel,
    required this.uploadLabel,
    required this.pingLabel,
    required this.jitterLabel,
  });

  final double downloadMbps;
  final double uploadMbps;
  final double pingMs;
  final double jitterMs;
  final String grade;
  final String? provider;
  final String? serverName;
  final String dateLabel;

  // Локализованные подписи.
  final String downloadLabel;
  final String uploadLabel;
  final String pingLabel;
  final String jitterLabel;
}

/// Рисует карточку результата и возвращает PNG-байты.
///
/// Рисуем прямо на Canvas, а не снимаем виджет с экрана: так картинка не
/// зависит от текущего состояния UI, размера окна и темы.
Future<Uint8List?> renderShareCard(ShareCardData d) async {
  const w = 1200.0, h = 630.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

  // Фон: тёмный градиент + мягкие пятна «северного сияния».
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0D1730), AppColors.bg0],
      ).createShader(const Rect.fromLTWH(0, 0, w, h)),
  );
  _blob(canvas, const Offset(180, 120), 320, AppColors.nebulaIndigo, 0.20);
  _blob(canvas, const Offset(1050, 180), 300, AppColors.nebulaPink, 0.18);
  _blob(canvas, const Offset(600, 640), 380, AppColors.nebulaViolet, 0.14);

  // Звёзды для узнаваемости стиля.
  final rnd = math.Random(11);
  final star = Paint();
  for (var i = 0; i < 90; i++) {
    final x = rnd.nextDouble() * w;
    final y = rnd.nextDouble() * h;
    final r = rnd.nextDouble() * 1.6 + 0.4;
    star.color = AppColors.onGlass.withValues(alpha: rnd.nextDouble() * 0.5 + 0.1);
    canvas.drawCircle(Offset(x, y), r, star);
  }

  // Заголовок.
  _text(canvas, 'Pulsar', const Offset(64, 52),
      size: 44, weight: FontWeight.w900, color: AppColors.onGlass);
  _text(canvas, d.dateLabel, const Offset(64, 108),
      size: 20, color: AppColors.textLo);

  // Плашка с оценкой справа.
  final gradeRect =
      RRect.fromRectAndRadius(const Rect.fromLTWH(1000, 48, 136, 136),
          const Radius.circular(28));
  canvas.drawRRect(
      gradeRect, Paint()..color = AppColors.nebulaViolet.withValues(alpha: 0.16));
  canvas.drawRRect(
    gradeRect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.nebulaViolet.withValues(alpha: 0.6),
  );
  _text(canvas, d.grade, const Offset(1068, 116),
      size: 64,
      weight: FontWeight.w900,
      color: AppColors.nebulaViolet,
      center: true);

  // Две крупные цифры: загрузка и отдача.
  _bigMetric(canvas, const Offset(64, 210), d.downloadLabel, d.downloadMbps,
      AppColors.nebulaViolet, '↓');
  _bigMetric(canvas, const Offset(620, 210), d.uploadLabel, d.uploadMbps,
      AppColors.nebulaPink, '↑');

  // Пинг и джиттер.
  _smallMetric(canvas, const Offset(64, 430), d.pingLabel, d.pingMs);
  _smallMetric(canvas, const Offset(340, 430), d.jitterLabel, d.jitterMs);

  // Подвал: провайдер и сервер.
  final footer = [
    if (d.provider != null && d.provider!.isNotEmpty) d.provider,
    if (d.serverName != null) d.serverName,
  ].join('  ·  ');
  if (footer.isNotEmpty) {
    _text(canvas, footer, const Offset(64, 552),
        size: 22, color: AppColors.textMid);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(w.toInt(), h.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes?.buffer.asUint8List();
}

void _blob(Canvas c, Offset at, double r, Color color, double alpha) {
  c.drawCircle(
    at,
    r,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: at, radius: r)),
  );
}

void _bigMetric(
    Canvas c, Offset at, String label, double value, Color color, String arrow) {
  _text(c, '$arrow $label', at, size: 24, color: AppColors.textMid);
  final v = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  _text(c, v, at + const Offset(0, 40),
      size: 104, weight: FontWeight.w900, color: color);
  // Ширина числа заранее неизвестна — «Mbps» ставим под ним.
  _text(c, 'Mbps', at + const Offset(4, 158), size: 26, color: AppColors.textLo);
}

void _smallMetric(Canvas c, Offset at, String label, double value) {
  _text(c, label, at, size: 22, color: AppColors.textLo);
  final v = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  _text(c, '$v ms', at + const Offset(0, 30),
      size: 40, weight: FontWeight.w700, color: AppColors.onGlass);
}

void _text(
  Canvas canvas,
  String text,
  Offset at, {
  required double size,
  Color color = Colors.white,
  FontWeight weight = FontWeight.w500,
  bool center = false,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: size, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
}
