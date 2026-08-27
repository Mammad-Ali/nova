import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Asks a device what it calls itself.
///
/// Two questions are asked, because no single one covers a home network:
///
///  * **Unicast mDNS** — a reverse lookup sent straight to `<ip>:5353`.
///    Responders answer these "legacy unicast" queries, so we get Bonjour
///    names (Apple devices, printers, TVs) without touching multicast at all.
///    That matters: multicast needs port 5353, which the system mDNS daemon
///    already owns, and an explicit outgoing interface, which differs per
///    platform.
///  * **NetBIOS** — a node status request on UDP 137, which is what Windows
///    machines and NAS boxes answer to.
///
/// Returns null when the device stays silent, which is normal: phones usually
/// answer nothing at all.
Future<String?> lookupDeviceName(String ip, {Duration? timeout}) async {
  final wait = timeout ?? const Duration(milliseconds: 900);
  final mdns = await _ask(ip, 5353, buildReverseQuery(ip), wait, parseDnsName);
  if (mdns != null && mdns.isNotEmpty) return _trimLocal(mdns);

  final netbios =
      await _ask(ip, 137, buildNetbiosQuery(), wait, parseNetbiosName);
  return (netbios == null || netbios.isEmpty) ? null : netbios;
}

String _trimLocal(String name) =>
    name.endsWith('.local') ? name.substring(0, name.length - 6) : name;

Future<String?> _ask(
  String ip,
  int port,
  Uint8List packet,
  Duration timeout,
  String? Function(Uint8List) parse,
) async {
  RawDatagramSocket? socket;
  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final answer = Completer<String?>();
    socket.listen((event) {
      if (event != RawSocketEvent.read || answer.isCompleted) return;
      final datagram = socket!.receive();
      if (datagram == null) return;
      answer.complete(parse(datagram.data));
    });
    socket.send(packet, InternetAddress(ip), port);
    return await answer.future.timeout(timeout, onTimeout: () => null);
  } catch (_) {
    // A blocked socket or an unreachable host simply leaves the name empty.
    return null;
  } finally {
    socket?.close();
  }
}

// ───────────────────────────── mDNS ─────────────────────────────

/// A PTR question for `<reversed ip>.in-addr.arpa` — "who is 192.168.0.104?".
Uint8List buildReverseQuery(String ip) {
  final labels = [...ip.split('.').reversed, 'in-addr', 'arpa'];
  return _buildQuery(labels, type: 12); // 12 = PTR
}

Uint8List _buildQuery(List<String> labels, {required int type}) {
  final b = BytesBuilder()
    ..add([0x12, 0x34]) // transaction id
    ..add([0x00, 0x00]) // standard query
    ..add([0x00, 0x01]) // one question
    ..add([0x00, 0x00, 0x00, 0x00, 0x00, 0x00]); // no other sections
  for (final label in labels) {
    b
      ..addByte(label.length)
      ..add(label.codeUnits);
  }
  b
    ..addByte(0) // end of name
    ..add([0x00, type & 0xff])
    ..add([0x00, 0x01]); // class IN
  return b.toBytes();
}

/// Reads the name out of the first answer record of a DNS reply.
String? parseDnsName(Uint8List data) {
  if (data.length < 12) return null;
  final answers = (data[6] << 8) | data[7];
  if (answers == 0) return null;

  var offset = 12;
  final questions = (data[4] << 8) | data[5];
  for (var i = 0; i < questions; i++) {
    offset = _skipName(data, offset) + 4; // + type and class
  }
  offset = _skipName(data, offset) + 8; // + type, class, ttl
  if (offset + 2 > data.length) return null;
  offset += 2; // rdlength
  final name = _readName(data, offset);
  return name.isEmpty ? null : name;
}

int _skipName(Uint8List d, int offset) {
  while (offset < d.length) {
    final len = d[offset];
    if (len == 0) return offset + 1;
    if (len & 0xC0 == 0xC0) return offset + 2; // compression pointer
    offset += len + 1;
  }
  return offset;
}

/// Reads a domain name, following compression pointers back into the packet.
String _readName(Uint8List d, int offset) {
  final labels = <String>[];
  // Bounded so a packet pointing at itself cannot spin forever.
  for (var hops = 0; hops < 64 && offset < d.length; hops++) {
    final len = d[offset];
    if (len == 0) break;
    if (len & 0xC0 == 0xC0) {
      if (offset + 1 >= d.length) break;
      offset = ((len & 0x3F) << 8) | d[offset + 1];
      continue;
    }
    if (offset + 1 + len > d.length) break;
    labels.add(String.fromCharCodes(d, offset + 1, offset + 1 + len));
    offset += len + 1;
  }
  return labels.join('.');
}

// ──────────────────────────── NetBIOS ────────────────────────────

/// Node status request for the wildcard name — "tell me your names".
Uint8List buildNetbiosQuery() {
  final b = BytesBuilder()
    ..add([0xA2, 0x48]) // transaction id
    ..add([0x00, 0x00]) // flags
    ..add([0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    ..addByte(0x20) // length of the encoded name
    ..add('CKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'.codeUnits) // encoded "*"
    ..addByte(0x00)
    ..add([0x00, 0x21]) // type NBSTAT
    ..add([0x00, 0x01]); // class IN
  return b.toBytes();
}

/// Pulls the machine name out of a NetBIOS node status reply.
String? parseNetbiosName(Uint8List d) {
  // 12 header + 34 encoded name + 2 type + 2 class + 4 ttl + 2 rdlength = 56,
  // then a name count followed by 16-byte entries (15 chars + a suffix byte).
  const namesAt = 57;
  if (d.length < namesAt + 16 || d[56] == 0) return null;
  final name = String.fromCharCodes(d, namesAt, namesAt + 15).trim();
  return name.isEmpty ? null : name;
}
