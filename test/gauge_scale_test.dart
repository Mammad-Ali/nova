import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/features/speedtest/domain/gauge_scale.dart';

void main() {
  const s = GaugeScale.standard;

  test('every mark sits exactly where its number says', () {
    for (var i = 0; i < s.marks.length; i++) {
      expect(s.fractionOf(s.marks[i]), closeTo(s.markFraction(i), 1e-9), reason: '${s.marks[i]}');
    }
  });

  test('speeds between marks spread evenly between them', () {
    // 75 Mbps is halfway from the 50 mark to the 100 mark.
    expect(s.fractionOf(75), closeTo((s.markFraction(3) + s.markFraction(4)) / 2, 1e-9));
    // 86.5 Mbps sits just past halfway round the dial, not at a third.
    expect(s.fractionOf(86.5), greaterThan(0.45));
    expect(s.fractionOf(86.5), lessThan(0.5));
  });

  test('the needle never leaves the dial', () {
    expect(s.fractionOf(0), 0);
    expect(s.fractionOf(-3), 0);
    expect(s.fractionOf(double.nan), 0);
    expect(s.fractionOf(1500), 1);
  });

  test('only a line past gigabit gets the multi-gigabit dial', () {
    expect(GaugeScale.fitting(940), same(GaugeScale.standard));
    expect(GaugeScale.fitting(1200), same(GaugeScale.multiGig));
    expect(GaugeScale.multiGig.fractionOf(2500), closeTo(GaugeScale.multiGig.markFraction(7), 1e-9));
  });

  test('labels stay short', () {
    expect(GaugeScale.label(750), '750');
    expect(GaugeScale.label(1000), '1G');
    expect(GaugeScale.label(2500), '2.5G');
    expect(GaugeScale.label(10000), '10G');
  });
}
