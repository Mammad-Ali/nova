import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/core/l10n/app_strings.dart';
import 'package:net_pulse/features/speedtest/data/datasources/azerbaijan_servers.dart';
import 'package:net_pulse/features/speedtest/data/datasources/speedtest_servers.dart';
import 'package:net_pulse/features/speedtest/presentation/widgets/server_picker_sheet.dart';

void main() {
  test('provider servers speak the Speedtest network\'s requests', () {
    final s = providerServerById(45546)!;
    expect(s.label, 'Aztelekom · Baku');
    expect(s.chunkUrl(), matches(RegExp(r'^https://speedtest\.aztelekom\.az:8080/download\?nocache=\d+&size=25000000$')));
    expect(s.probeUrl(), startsWith('https://speedtest.aztelekom.az:8080/hello?nocache='));
    expect(s.uploadTarget(), startsWith('https://speedtest.aztelekom.az:8080/upload?nocache='));
    // Every request is new to any cache in between.
    expect(s.chunkUrl(), isNot(s.chunkUrl()));
    expect(s.rangeHeader(), isNull);
  });

  test('the built-in servers are unchanged', () {
    final cloudflare = kSpeedTestServers.first;
    expect(cloudflare.label, 'Cloudflare');
    expect(cloudflare.chunkUrl(), 'https://speed.cloudflare.com/__down?bytes=5000000');
    expect(cloudflare.uploadTarget(), 'https://speed.cloudflare.com/__up');
  });

  test('the list is all Azerbaijan, every id once, every city named', () {
    final ids = kAzerbaijanServers.map((s) => s.id).toSet();
    expect(ids.length, kAzerbaijanServers.length);
    expect(kAzerbaijanServers.length, greaterThan(40));
    for (final s in kAzerbaijanServers) {
      expect(s.mode, ChunkMode.sizeParam);
      expect(cityName(s.city!, AppLocale.az), isNot(isEmpty));
    }
    expect(cityName('Baku', AppLocale.az), 'Bakı');
    expect(cityName('Ganja', AppLocale.ru), 'Гянджа');
    expect(cityName('Baku', AppLocale.de), 'Baku');
    expect(providerServerById(null), isNull);
    expect(providerServerById(1), isNull);
  });

  test('your own provider is recognised by name', () {
    SpeedTestServer by(String sponsor) => kAzerbaijanServers.firstWhere((s) => s.name == sponsor);
    expect(isOwnProvider(by('Aztelekom'), 'Aztelekom LLC'), isTrue);
    expect(isOwnProvider(by('Azercell Telecom'), 'Azercell Telecom LLC'), isTrue);
    expect(isOwnProvider(by('Nar'), 'Azerfon LLC'), isTrue);
    expect(isOwnProvider(by('Bakcell'), 'Aztelekom LLC'), isFalse);
    expect(isOwnProvider(by('Aztelekom'), null), isFalse);
  });
}
