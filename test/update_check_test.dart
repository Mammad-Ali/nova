import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/features/updates/update_check.dart';

void main() {
  test('parses tags and build versions', () {
    expect(parseVersion('v1.3.0'), [1, 3, 0]);
    expect(parseVersion('1.3.0+4'), [1, 3, 0]);
    expect(parseVersion('2.0.0-beta'), [2, 0, 0]);
    expect(parseVersion('nova'), isNull);
    expect(parseVersion('1..2'), isNull);
  });

  test('compares versions number by number', () {
    expect(isNewerVersion('v1.3.1', '1.3.0'), isTrue);
    expect(isNewerVersion('v1.10.0', '1.9.9'), isTrue);
    expect(isNewerVersion('v2.0', '1.9.9'), isTrue);
    expect(isNewerVersion('v1.3.0', '1.3.0'), isFalse);
    expect(isNewerVersion('v1.2.9', '1.3.0'), isFalse);
    expect(isNewerVersion('v1.3', '1.3.0'), isFalse);
  });

  test('never treats a malformed tag as newer', () {
    expect(isNewerVersion('latest', '1.3.0'), isFalse);
    expect(isNewerVersion('v9.9.9', 'unknown'), isFalse);
  });
}
