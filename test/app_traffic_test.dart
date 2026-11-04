import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/features/traffic_monitor/data/datasources/app_traffic_source.dart';

void main() {
  test('reads nettop, names with dots and spaces included', () {
    const out = ''',bytes_in,bytes_out,
mDNSResponder.504,33949027,25880944,
Google Chrome H.35148,82661,73378,
com.apple.WebKi.812,1200,300,
airportd.475,0,0,
''';
    final p = MacAppTrafficSource.parseNettop(out);
    expect(p.keys, unorderedEquals([504, 35148, 812, 475]));
    expect(p[35148]!.name, 'Google Chrome H');
    expect(p[35148]!.bytesIn, 82661);
    expect(p[35148]!.bytesOut, 73378);
    expect(p[812]!.name, 'com.apple.WebKi');
  });

  test('finds the app a process belongs to', () {
    expect(
      MacAppTrafficSource.appFromPath('/Applications/Google Chrome.app/Contents/Frameworks/'
          'Google Chrome Framework.framework/Versions/156/Helpers/Google Chrome Helper.app/'
          'Contents/MacOS/Google Chrome Helper'),
      'Google Chrome',
    );
    expect(MacAppTrafficSource.appFromPath('/Applications/Nova.app/Contents/MacOS/Nova'), 'Nova');
    expect(MacAppTrafficSource.appFromPath('/opt/homebrew/bin/node'), 'node');
    // macOS's own services go together.
    expect(MacAppTrafficSource.appFromPath('/usr/sbin/mDNSResponder'), isNull);
    expect(
      MacAppTrafficSource.appFromPath(
          '/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter'),
      isNull,
    );
  });
}
