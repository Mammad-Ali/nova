import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:net_pulse/features/lan_scan/data/name_lookup.dart';
import 'package:net_pulse/features/lan_scan/domain/lan_device.dart';

/// Builds a DNS reply carrying one PTR answer, the shape a device sends back
/// to the unicast mDNS question.
Uint8List ptrReply(String question, String answer) {
  final b = BytesBuilder()
    ..add([0x12, 0x34])
    ..add([0x84, 0x00]) // response, authoritative
    ..add([0x00, 0x01]) // one question
    ..add([0x00, 0x01]) // one answer
    ..add([0x00, 0x00, 0x00, 0x00]);
  for (final label in question.split('.')) {
    b
      ..addByte(label.length)
      ..add(label.codeUnits);
  }
  b
    ..addByte(0)
    ..add([0x00, 0x0C, 0x00, 0x01]) // PTR, IN
    ..add([0xC0, 0x0C]) // answer name: pointer back to the question
    ..add([0x00, 0x0C, 0x00, 0x01]) // PTR, IN
    ..add([0x00, 0x00, 0x00, 0x78]); // ttl

  final rdata = BytesBuilder();
  for (final label in answer.split('.')) {
    rdata
      ..addByte(label.length)
      ..add(label.codeUnits);
  }
  rdata.addByte(0);
  final rd = rdata.toBytes();
  b
    ..add([(rd.length >> 8) & 0xff, rd.length & 0xff])
    ..add(rd);
  return b.toBytes();
}

void main() {
  group('mDNS parsing', () {
    test('reads the name out of a PTR answer', () {
      final reply = ptrReply(
        '104.0.168.192.in-addr.arpa',
        'Alis-MacBook-Air.local',
      );
      expect(parseDnsName(reply), 'Alis-MacBook-Air.local');
    });

    test('returns null when the reply carries no answer', () {
      final empty = Uint8List.fromList([
        0x12, 0x34, 0x84, 0x00, //
        0x00, 0x01, 0x00, 0x00, // one question, no answers
        0x00, 0x00, 0x00, 0x00,
      ]);
      expect(parseDnsName(empty), isNull);
    });

    test('survives a truncated packet', () {
      expect(parseDnsName(Uint8List.fromList([0x12, 0x34])), isNull);
    });

    test('asks for the address in reverse order', () {
      final query = buildReverseQuery('192.168.0.104');
      final text = String.fromCharCodes(query);
      expect(text, contains('104'));
      expect(text, contains('in-addr'));
      expect(text, contains('arpa'));
      // Question count is one, and the type is PTR (12).
      expect(query[5], 1);
      expect(query.last, 1); // class IN
    });
  });

  group('NetBIOS parsing', () {
    test('reads the machine name', () {
      final b = BytesBuilder()
        ..add(Uint8List(56)) // header, encoded name, type, class, ttl, rdlength
        ..addByte(1) // one name follows
        ..add('DESKTOP-ALI    '.codeUnits) // 15 chars, space padded
        ..addByte(0x00); // suffix
      expect(parseNetbiosName(b.toBytes()), 'DESKTOP-ALI');
    });

    test('returns null when no names are listed', () {
      expect(parseNetbiosName(Uint8List(80)), isNull);
    });
  });

  group('device kind', () {
    test('the gateway is the router', () {
      const device = LanDevice(ip: '192.168.0.1', isGateway: true);
      expect(device.kind, DeviceKind.router);
    });

    test('this machine is a computer', () {
      const device = LanDevice(ip: '192.168.0.104', isSelf: true);
      expect(device.kind, DeviceKind.computer);
    });

    test('a printing port marks a printer', () {
      const device = LanDevice(ip: '192.168.0.20', openPorts: [80, 9100]);
      expect(device.kind, DeviceKind.printer);
    });

    test('the announced name outweighs the open ports', () {
      // A printer that also serves a web page would otherwise read as a PC.
      const device = LanDevice(
        ip: '192.168.0.20',
        name: 'HP-LaserJet-Pro',
        openPorts: [80, 445],
      );
      expect(device.kind, DeviceKind.printer);
    });

    test('recognises a phone by name', () {
      const device = LanDevice(ip: '192.168.0.33', name: 'Alis-iPhone');
      expect(device.kind, DeviceKind.phone);
    });

    test('falls back to unknown when nothing is known', () {
      const device = LanDevice(ip: '192.168.0.77');
      expect(device.kind, DeviceKind.unknown);
    });
  });
}
