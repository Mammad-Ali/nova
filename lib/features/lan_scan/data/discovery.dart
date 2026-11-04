import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Ways to find devices that the port sweep misses: phones, smart speakers
/// and many TVs quietly drop connection attempts, so they never answer on a
/// port. They do answer other questions.
///
///  * **Ping.** Most of them still answer an echo request.
///  * **The ARP table.** To send anything to an address, the system first
///    asks the network who has it, and keeps the answers. After the sweep
///    has knocked on every address, the table lists every device that is
///    switched on — with its hardware (MAC) address, which names the maker.
///    Windows, Linux and older macOS show it to apps; macOS 27 shows it only
///    to Apple's own tools, and Android to no one.
///  * **SSDP.** A search sent to the UPnP multicast address, answered by TVs,
///    speakers, consoles, routers and media servers, often with a product
///    name in the reply.
///  * **mDNS.** A question for every Bonjour service on the network, answered
///    by Apple devices, printers, Chromecasts and smart-home gear — with the
///    kinds of service they offer, which say what they are.
///
/// Each one is best effort: a failure just means no extra devices from it.
class Discovery {
  /// Whether pinging is worth it here: on Windows and Linux the ARP table
  /// already lists the silent devices.
  static bool get canPing => Platform.isMacOS || Platform.isAndroid;

  /// True when [ip] answers one echo request within a second. Uses the
  /// system's ping tool: Dart has no ICMP sockets. (macOS: -t caps the whole
  /// run; -W alone still lets an unanswered ping take nearly two seconds.)
  static Future<bool> ping(String ip) async {
    try {
      final result = Platform.isMacOS
          ? await Process.run('/sbin/ping', ['-c', '1', '-t', '1', '-q', ip])
          : await Process.run('/system/bin/ping', ['-c', '1', '-W', '1', '-q', ip]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Address → hardware address ("b4:b0:24:64:df:b9") for every device the
  /// system has heard from on [prefix] (e.g. "192.168.0.").
  static Future<Map<String, String>> arpTable(String prefix) async {
    String table;
    try {
      if (Platform.isMacOS) {
        table = '${(await Process.run('/usr/sbin/arp', ['-an'])).stdout}';
      } else if (Platform.isWindows) {
        table = '${(await Process.run('arp', ['-a'])).stdout}';
      } else if (Platform.isLinux) {
        table = await File('/proc/net/arp').readAsString();
      } else {
        return {};
      }
    } catch (_) {
      return {}; // no table to read: the sweep's results stand alone
    }
    return parseArpTable(table)
      ..removeWhere((ip, mac) => !ip.startsWith(prefix) || ip.endsWith('.255'));
  }

  /// Reads `arp -an` (macOS), `arp -a` (Windows) and /proc/net/arp (Linux)
  /// alike: each line with an address and, later on it, a hardware address.
  /// Lines still waiting for an answer ("incomplete", all zeros) and
  /// broadcast or multicast entries are left out.
  static Map<String, String> parseArpTable(String table) {
    final line = RegExp(
      r'(\d{1,3}(?:\.\d{1,3}){3})\)?[^\n]*?\b([0-9a-fA-F]{1,2}(?:[:-][0-9a-fA-F]{1,2}){5})\b',
    );
    final found = <String, String>{};
    for (final m in line.allMatches(table)) {
      final mac = _normalise(m[2]!.split(RegExp('[:-]')));
      if (mac == 'ff:ff:ff:ff:ff:ff' ||
          mac == '00:00:00:00:00:00' ||
          mac.startsWith('01:00:5e')) {
        continue;
      }
      found[m[1]!] = mac;
    }
    return found;
  }

  /// "1:0:5e:0:0:fb" → "01:00:5e:00:00:fb".
  static String _normalise(List<String> octets) =>
      octets.map((o) => o.toLowerCase().padLeft(2, '0')).join(':');

  /// Address → what it said about itself ("server: Samsung TV …"), for every
  /// device answering an SSDP search within [listen].
  static Future<Map<String, Set<String>>> ssdp(
    String self, {
    Duration listen = const Duration(milliseconds: 2500),
  }) {
    const search = 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: 239.255.255.250:1900\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 2\r\n'
        'ST: ssdp:all\r\n\r\n';
    return _ask(self, InternetAddress('239.255.255.250'), 1900,
        utf8.encode(search), listen, (reply) {
      final text = latin1.decode(reply, allowInvalid: true);
      final hints = <String>{};
      for (final header in ['server', 'st', 'nt', 'usn', 'location']) {
        final m = RegExp('^$header:\\s*(.+)\$', multiLine: true, caseSensitive: false).firstMatch(text);
        if (m == null) continue;
        final value = m[1]!.trim();
        // The description's address keeps its case: paths are case-sensitive.
        hints.add(header == 'location' ? '$locationHint$value' : 'ssdp:${value.toLowerCase()}');
      }
      return hints;
    });
  }

  /// Marks the hint holding the address of a device's UPnP description.
  static const locationHint = 'location:';

  /// The name a UPnP device gives itself in its description — "[TV] Samsung
  /// 7 Series (55)", "Living Room" — fetched from [location], which must be
  /// plain HTTP on the device's own address [ip]: an answer can't send Nova
  /// anywhere else.
  static Future<String?> upnpName(String ip, String location) async {
    final url = Uri.tryParse(location);
    if (url == null || url.scheme != 'http' || url.host != ip) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      final request = await client.getUrl(url);
      final response = await request.close().timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return null;
      // A description is a few kilobytes; stop reading at 64.
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 2))) {
        bytes.addAll(chunk);
        if (bytes.length > 64 * 1024) break;
      }
      final xml = utf8.decode(bytes, allowMalformed: true);
      final name = RegExp(r'<friendlyName>([^<]{1,80})</friendlyName>').firstMatch(xml)?[1]?.trim();
      return name == null || name.isEmpty ? null : _unescape(name);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static String _unescape(String text) => text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  /// Address → the Bonjour service types it offers ("_airplay", "_ipp"…),
  /// for every device answering within [listen].
  static Future<Map<String, Set<String>>> mdns(
    String self, {
    Duration listen = const Duration(milliseconds: 2500),
  }) {
    return _ask(self, InternetAddress('224.0.0.251'), 5353, _servicesQuery(),
        listen, (reply) {
      final text = latin1.decode(reply, allowInvalid: true);
      return {
        for (final m in RegExp(r'_[a-z0-9][a-z0-9-]{1,30}').allMatches(text.toLowerCase()))
          if (!const {'_tcp', '_udp', '_services', '_dns-sd', '_sub'}.contains(m[0]))
            'mdns:${m[0]}',
      };
    });
  }

  /// A DNS query for "_services._dns-sd._udp.local" PTR — "which services
  /// are there?" — with the unicast-response bit set, so answers come
  /// straight back to this socket instead of to port 5353, which the
  /// system's own mDNS responder holds.
  static Uint8List _servicesQuery() {
    final name = <int>[];
    for (final label in ['_services', '_dns-sd', '_udp', 'local']) {
      name
        ..add(label.length)
        ..addAll(ascii.encode(label));
    }
    name.add(0);
    return Uint8List.fromList([
      0, 0, 0, 0, // id, flags
      0, 1, 0, 0, 0, 0, 0, 0, // one question
      ...name,
      0, 12, // PTR
      0x80, 1, // class IN, unicast response wanted
    ]);
  }

  /// Sends [query] twice to a multicast group from this machine's own
  /// address — which picks the right network interface — and gathers what
  /// comes back for [listen], by sender.
  static Future<Map<String, Set<String>>> _ask(
    String self,
    InternetAddress group,
    int port,
    List<int> query,
    Duration listen,
    Set<String> Function(Uint8List reply) read,
  ) async {
    final found = <String, Set<String>>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress(self), 0);
      socket.multicastHops = 2;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket?.receive();
        if (datagram == null) return;
        found.putIfAbsent(datagram.address.address, () => <String>{}).addAll(read(datagram.data));
      });
      socket.send(query, group, port);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      socket.send(query, group, port); // multicast gets lost now and then
      await Future<void>.delayed(listen);
    } catch (_) {
      // No multicast here: nothing extra to find.
    } finally {
      socket?.close();
    }
    return found;
  }
}
