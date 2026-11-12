import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Asks one DNS server for one name, straight over UDP — the system's own
/// lookup would answer from its cache and say nothing about the server.
/// Returns the time to the answer in ms, or null if none came in time.
Future<double?> timeLookup(String server, String name, {Duration timeout = const Duration(seconds: 2)}) async {
  RawDatagramSocket? socket;
  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final id = Random().nextInt(0xffff);
    final answered = Completer<double?>();
    final sw = Stopwatch();
    socket.listen((event) {
      if (event != RawSocketEvent.read || answered.isCompleted) return;
      final datagram = socket!.receive();
      if (datagram == null || datagram.data.length < 12) return;
      final data = datagram.data;
      // Our question's answer, and not an error ("no such name" still
      // counts: the server did its job).
      if ((data[0] << 8 | data[1]) != id) return;
      final rcode = data[3] & 0x0f;
      answered.complete(rcode == 0 || rcode == 3 ? sw.elapsedMicroseconds / 1000.0 : null);
    });
    sw.start();
    socket.send(buildQuery(id, name), InternetAddress(server), 53);
    return await answered.future.timeout(timeout, onTimeout: () => null);
  } catch (_) {
    return null;
  } finally {
    socket?.close();
  }
}

/// A standard query for [name]'s IPv4 address, recursion wanted.
Uint8List buildQuery(int id, String name) {
  final bytes = BytesBuilder()
    ..add([id >> 8, id & 0xff, 0x01, 0x00, 0, 1, 0, 0, 0, 0, 0, 0]);
  for (final label in name.split('.')) {
    bytes
      ..addByte(label.length)
      ..add(label.codeUnits);
  }
  bytes.add([0, 0, 1, 0, 1]); // end of name, type A, class IN
  return bytes.toBytes();
}

/// The DNS servers the system uses now, IPv4 only: macOS from scutil,
/// Linux from resolv.conf, Windows from PowerShell, Android from the
/// network's link properties (MainActivity.kt).
Future<List<String>> systemDnsServers() async {
  final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
  List<String> clean(Iterable<String> found) =>
      found.map((s) => s.trim()).where(ipv4.hasMatch).toSet().toList();
  try {
    if (Platform.isMacOS) {
      final out = await Process.run('/usr/sbin/scutil', ['--dns']);
      return clean(RegExp(r'nameserver\[\d+\]\s*:\s*(\S+)')
          .allMatches('${out.stdout}')
          .map((m) => m[1]!)).take(2).toList();
    }
    if (Platform.isLinux) {
      final lines = await File('/etc/resolv.conf').readAsLines();
      return clean(lines.where((l) => l.startsWith('nameserver')).map((l) => l.split(RegExp(r'\s+')).last));
    }
    if (Platform.isWindows) {
      final out = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '(Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object {\$_.ServerAddresses} | '
            'Select-Object -ExpandProperty ServerAddresses) -join "`n"',
      ]);
      return clean('${out.stdout}'.split('\n')).take(2).toList();
    }
    if (Platform.isAndroid) {
      final servers = await const MethodChannel('net_pulse/network').invokeListMethod<String>('dnsServers');
      return clean(servers ?? const []);
    }
  } catch (_) {}
  return const [];
}
