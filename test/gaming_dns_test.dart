import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/features/dns_test/data/dns_probe.dart';
import 'package:net_pulse/features/dns_test/domain/dns_test.dart';
import 'package:net_pulse/features/gaming/domain/gaming.dart';

void main() {
  group('gaming', () {
    test('median ping, jitter as the average jump, loss', () {
      final r = RegionResult.from([40, 44, null, 42, 46, 40]);
      expect(r.pingMs, 42);
      expect(r.jitterMs, closeTo((4 + 2 + 4 + 6) / 4, 0.001));
      expect(r.lossPercent, closeTo(100 / 6, 0.01));
    });

    test('verdicts', () {
      expect(RegionResult.from([35, 37, 36, 38]).verdict, GamingVerdict.great);
      expect(RegionResult.from([80, 82, 79, 81]).verdict, GamingVerdict.good);
      expect(RegionResult.from([120, 125, 122]).verdict, GamingVerdict.slow);
      expect(RegionResult.from([210, 220]).verdict, GamingVerdict.far);
      expect(RegionResult.from([null, null, 40]).verdict, GamingVerdict.lost);
      // Close but shaky is no good for shooters.
      expect(RegionResult.from([30, 60, 30, 60]).verdict, isNot(GamingVerdict.great));
    });

    test('every region has a ping endpoint', () {
      for (final region in gameRegions) {
        expect(region.url, startsWith('https://dynamodb.${region.awsRegion}.amazonaws.com/'));
      }
    });
  });

  group('dns', () {
    test('a query asks for the IPv4 address with recursion', () {
      final q = buildQuery(0x1234, 'google.com');
      expect(q.sublist(0, 4), [0x12, 0x34, 0x01, 0x00]);
      expect(q.sublist(12), [6, ...'google'.codeUnits, 3, ...'com'.codeUnits, 0, 0, 1, 0, 1]);
    });

    test('switching only for a clear win', () {
      DnsResult r(double ms) => DnsResult(medianMs: ms, answered: 16, asked: 16);
      expect(worthSwitching(r(40), r(10)), isTrue);
      expect(worthSwitching(r(11), r(7)), isFalse); // 4 ms is noise
      expect(worthSwitching(r(100), r(85)), isFalse); // not a fifth faster
      expect(worthSwitching(const DnsResult(medianMs: null, answered: 0, asked: 16), r(30)), isTrue);
      expect(DnsResult.from([5, null, null, null]).works, isFalse);
    });
  });
}
