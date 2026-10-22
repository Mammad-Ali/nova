import 'package:flutter_test/flutter_test.dart';

import 'package:net_pulse/features/throttling/data/throttle_engine.dart';
import 'package:net_pulse/features/throttling/domain/throttle_result.dart';

void main() {
  test('the verdict is classified from the speed ratio', () {
    expect(verdictFor(100, 130), ThrottleVerdict.localCache);
    expect(verdictFor(100, 95), ThrottleVerdict.none);
    expect(verdictFor(100, 70), ThrottleVerdict.suspected);
    expect(verdictFor(100, 30), ThrottleVerdict.likely);
    // With no neutral-CDN data we don't blame the ISP.
    expect(verdictFor(0, 50), ThrottleVerdict.none);
  });

  test('the engine actually measures both speeds', () async {
    final result = await ThrottleEngine().run();

    expect(result.neutralMbps > 0, isTrue,
        reason: 'neutral CDN: ${result.neutralMbps}');
    expect(result.videoMbps > 0, isTrue,
        reason: 'video CDN: ${result.videoMbps}');
    expect(result.videoHost, isNotNull);

    // ignore: avoid_print
    print('neutral=${result.neutralMbps.toStringAsFixed(1)} '
        'video=${result.videoMbps.toStringAsFixed(1)} '
        'ratio=${(result.ratio * 100).round()}% '
        'verdict=${result.verdict.name} host=${result.videoHost}');
  }, timeout: const Timeout(Duration(seconds: 60)), tags: 'network');
}
