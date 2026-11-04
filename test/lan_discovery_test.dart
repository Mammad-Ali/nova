import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/features/lan_scan/data/discovery.dart';
import 'package:net_pulse/features/lan_scan/domain/lan_device.dart';
import 'package:net_pulse/features/lan_scan/presentation/lan_scan_provider.dart';

void main() {
  group('ARP table', () {
    test('reads macOS arp -an', () {
      const table = '''
? (192.168.0.1) at b4:b0:24:64:df:b9 on en0 ifscope [ethernet]
? (192.168.0.23) at 1:2:3:a:b:c on en0 ifscope [ethernet]
? (192.168.0.40) at (incomplete) on en0 ifscope [ethernet]
? (192.168.0.100) at c0:c7:db:12:34:56 on en0 ifscope permanent [ethernet]
? (192.168.0.255) at ff:ff:ff:ff:ff:ff on en0 ifscope [ethernet]
? (224.0.0.251) at 1:0:5e:0:0:fb on en0 ifscope permanent [ethernet]
''';
      expect(Discovery.parseArpTable(table), {
        '192.168.0.1': 'b4:b0:24:64:df:b9',
        '192.168.0.23': '01:02:03:0a:0b:0c',
        '192.168.0.100': 'c0:c7:db:12:34:56',
      });
    });

    test('reads Windows arp -a, in any language', () {
      const table = '''
Interface: 192.168.0.100 --- 0xb
  Internet Address      Physical Address      Type
  192.168.0.1           b4-b0-24-64-df-b9     dynamic
  192.168.0.31          9a-11-22-33-44-55     динамический
  192.168.0.255         ff-ff-ff-ff-ff-ff     static
  224.0.0.22            01-00-5e-00-00-16     static
''';
      expect(Discovery.parseArpTable(table), {
        '192.168.0.1': 'b4:b0:24:64:df:b9',
        '192.168.0.31': '9a:11:22:33:44:55',
      });
    });

    test('reads Linux /proc/net/arp', () {
      const table = '''
IP address       HW type     Flags       HW address            Mask     Device
192.168.0.1      0x1         0x2         b4:b0:24:64:df:b9     *        wlan0
192.168.0.50     0x1         0x0         00:00:00:00:00:00     *        wlan0
''';
      expect(Discovery.parseArpTable(table), {'192.168.0.1': 'b4:b0:24:64:df:b9'});
    });
  });

  group('device', () {
    test('a random hardware address is private and names no maker', () {
      const phone = LanDevice(ip: '192.168.0.31', mac: '9a:11:22:33:44:55');
      expect(phone.privateMac, isTrue);
      expect(phone.macPrefix, isNull);
      expect(phone.kind, DeviceKind.phone);

      const router = LanDevice(ip: '192.168.0.2', mac: 'b4:b0:24:64:df:b9');
      expect(router.privateMac, isFalse);
      expect(router.macPrefix, 'B4B024');
      expect(router.kind, DeviceKind.unknown);
    });

    test('announced services say what a device is', () {
      LanDevice heard(Set<String> hints) => LanDevice(ip: '192.168.0.9', hints: hints);
      expect(heard({'mdns:_googlecast'}).kind, DeviceKind.tv);
      expect(heard({'mdns:_ipps', 'mdns:_uscan'}).kind, DeviceKind.printer);
      expect(heard({'mdns:_hap'}).kind, DeviceKind.smartHome);
      // A Mac offers AirPlay too; screen sharing settles it.
      expect(heard({'mdns:_airplay', 'mdns:_rfb'}).kind, DeviceKind.computer);
      expect(
        heard({'ssdp:urn:dial-multiscreen-org:service:dial:1'}).kind,
        DeviceKind.tv,
      );
    });

    test('the name beats services, services beat the maker', () {
      const named = LanDevice(
        ip: '192.168.0.9',
        name: 'Living-Room-PS5',
        hints: {'ssdp:urn:schemas-upnp-org:device:mediarenderer:1'},
      );
      expect(named.kind, DeviceKind.console);

      const sonyTv = LanDevice(
        ip: '192.168.0.9',
        vendor: 'Sony PlayStation',
        hints: {'mdns:_googlecast'},
      );
      expect(sonyTv.kind, DeviceKind.tv);
      expect(const LanDevice(ip: '192.168.0.9', vendor: 'Espressif').kind,
          DeviceKind.smartHome);
    });
  });

  test('the bundled vendor list names makers', () {
    final vendors = parseVendors(File('assets/oui/vendors.txt').readAsStringSync());
    expect(vendors.length, greaterThan(5000));
    expect(vendors['B4B024'], 'TP-Link');
    expect(vendors['C0C7DB'], 'Apple');
    expect(vendors.keys.every((k) => RegExp(r'^[0-9A-F]{6}$').hasMatch(k)), isTrue);
  });
}
