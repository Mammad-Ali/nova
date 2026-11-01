import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/core/utils/byte_format.dart';

void main() {
  group('formatFixedWidth', () {
    String shown(num bytes) =>
        formatFixedWidth(bytes).replaceAll(punctuationSpace, '_');

    test('three digits and a point (or a space as wide) every time', () {
      for (final bytes in [0, 1, 512, 6150, 10235, 63488, 102349, 634880,
          1023487, 1023489, 1048576, 93323264, 1073741824, 5e12, 2e15, 9.2e18]) {
        final text = formatFixedWidth(bytes);
        expect(text.length, 5, reason: '$bytes → $text');
        expect(RegExp(r'\d').allMatches(text).length, 3, reason: '$bytes → $text');
      }
    });

    test('keeps three significant digits', () {
      expect(shown(6150), '6.01K');
      expect(shown(63488), '62.0K');
      expect(shown(634880), '_620K');
    });

    test('rounds without growing a digit', () {
      expect(shown(10235), '10.0K'); // 9.995 K
      expect(shown(102349), '_100K'); // 99.95 K
      expect(shown(1023487), '_999K'); // 999.499 K
      expect(shown(1023489), '0.98M'); // 999.501 K
    });

    test('starts at K and moves up a unit at a time', () {
      expect(shown(0), '0.00K');
      expect(shown(512), '0.50K');
      expect(shown(1048576), '1.00M');
      expect(shown(1073741824), '1.00G');
    });

    test('treats nonsense as zero', () {
      expect(shown(-5), '0.00K');
      expect(shown(double.nan), '0.00K');
    });
  });
}
