import 'package:flutter_test/flutter_test.dart';

import 'package:net_pulse/features/speedtest/presentation/widgets/odometer_text.dart';

void main() {
  group('odometer wheels', () {
    test('a value at rest shows crisp digits', () {
      // 89.0 with one decimal is 890: the case that used to show a
      // half-rolled 8.
      expect(odometerOffsets(890, 3), [0, 9, 8]);
      // 18.4 is 184: the case that used to show a raised 1.
      expect(odometerOffsets(184, 3), [4, 8, 1]);
    });

    test('a higher wheel turns only while the one below passes 9', () {
      // 189.9: the lowest wheel is halfway from 9 to 0, so the tens wheel is
      // halfway from 8 to 9 — and the hundreds wheel has not moved.
      final w = odometerOffsets(189.9, 3);
      expect(w[0], closeTo(9.5, 1e-9));
      expect(w[1], closeTo(8.5, 1e-9));
      expect(w[2], 1);
    });

    test('a carry runs all the way up through nines', () {
      // 199.95: every wheel is mid-way through rolling over to 200.
      final w = odometerOffsets(199.95, 3);
      expect(w[0], closeTo(9.75, 1e-9));
      expect(w[1], closeTo(9.75, 1e-9));
      expect(w[2], closeTo(1.75, 1e-9));
    });

    test('floating-point noise just below a whole number reads right', () {
      // 0.29 * 100 is 28.999999999999996 in binary floating point.
      final w = odometerOffsets(0.29 * 100, 2);
      expect(w[0], closeTo(9, 1e-6));
      expect(w[1], closeTo(2, 1e-6));
    });
  });
}
