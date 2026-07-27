import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:net_pulse/features/speedtest/data/datasources/speedtest_engine.dart';
import 'package:net_pulse/features/speedtest/domain/entities/speedtest_models.dart';

void main() {
  test('полный тест: download, upload, bufferbloat и сервер', () async {
    final engine = SpeedTestEngine();
    SpeedTestProgress? result;
    final completer = Completer<void>();

    engine.run().listen((p) {
      if (p.phase == TestPhase.done || p.phase == TestPhase.error) {
        result = p;
        if (!completer.isCompleted) completer.complete();
      }
    });

    await completer.future.timeout(const Duration(seconds: 55));

    expect(result, isNotNull);
    expect(result!.phase, TestPhase.done, reason: 'ошибка: ${result!.error}');

    expect(result!.downloadMbps! > 0, isTrue,
        reason: 'download должен быть > 0, получили ${result!.downloadMbps}');
    expect(result!.uploadMbps! > 0, isTrue,
        reason: 'upload должен быть > 0, получили ${result!.uploadMbps}');

    // Новое: пинг под нагрузкой и имя выбранного сервера.
    expect(result!.serverName, isNotNull, reason: 'сервер должен быть выбран');
    expect(result!.loadedPingMs, isNotNull,
        reason: 'пинг под нагрузкой должен измеряться');
    expect(result!.loadedPingMs! > 0, isTrue);

    // ignore: avoid_print
    print('server=${result!.serverName} '
        'down=${result!.downloadMbps!.toStringAsFixed(1)} '
        'up=${result!.uploadMbps!.toStringAsFixed(1)} '
        'ping=${result!.pingMs!.toStringAsFixed(1)} '
        'loaded=${result!.loadedPingMs!.toStringAsFixed(1)}');
  }, timeout: const Timeout(Duration(seconds: 70)));
}
