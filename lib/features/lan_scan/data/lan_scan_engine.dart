import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../domain/lan_device.dart';
import 'discovery.dart';
import 'name_lookup.dart';

/// Finds the devices sharing this network.
///
/// Runs in its own isolate: a sweep opens a few hundred sockets, and doing
/// that on the UI isolate stutters the animated backdrop.
class LanScanEngine {
  Isolate? _isolate;
  ReceivePort? _port;
  StreamController<LanScanUpdate>? _updates;
  var _cancelled = false;

  /// Emits progressively: devices appear as they answer, then the ones the
  /// sweep missed (see [Discovery]), then all fill in with names and ports.
  Stream<LanScanUpdate> run() {
    final updates = _updates = StreamController<LanScanUpdate>();
    final port = _port = ReceivePort();

    port.listen((message) {
      if (message is! LanScanUpdate || updates.isClosed) return;
      updates.add(message);
      if (message.done) _dispose();
    });

    Isolate.spawn(_entry, port.sendPort).then((isolate) {
      if (_cancelled) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        _isolate = isolate;
      }
    });

    return updates.stream;
  }

  void cancel() {
    _cancelled = true;
    _dispose();
  }

  void _dispose() {
    _port?.close();
    _port = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _updates?.close();
    _updates = null;
  }
}

// ─────────────────────────── isolate side ───────────────────────────

/// Ports probed to decide whether anything is at an address. Chosen because
/// between them they cover routers, computers, phones and media boxes.
const _probePorts = [80, 443, 22, 445, 62078, 8080, 7000, 8009];

/// Probed only on hosts that already answered, to guess what they are.
const _detailPorts = [
  80, 443, 22, 445, 139, 3389, 5000, 8080, 62078,
  7000, 8009, 3689, 32400, 9100, 631, 515, 548, 5555,
];

const _connectTimeout = Duration(milliseconds: 500);

/// Addresses probed at once. Each one opens [_probePorts] sockets, so this is
/// really 256 in flight — comfortably under every platform's descriptor limit.
const _concurrency = 32;

/// Pings in flight at once. Each is a short-lived process, not a socket
/// held open, so more of them fit than probes: 254 addresses at up to a
/// second each take about as long as the port sweep.
const _pingConcurrency = 64;

/// "Connection refused" means something is there and actively said no, which
/// is just as good a sign of life as an open port.
/// 61 = macOS/BSD, 111 = Linux/Android, 10061 = Windows.
const kConnectionRefusedCodes = {61, 111, 10061};

Future<void> _entry(SendPort toMain) async {
  final self = await localNetworkAddress();
  if (self == null) {
    toMain.send(const LanScanUpdate(
      devices: [],
      scanned: 0,
      total: 0,
      done: true,
      failure: LanScanFailure.noNetwork,
    ));
    return;
  }

  // Assume a /24 — the mask itself is not exposed to Dart, and home networks
  // are practically always /24.
  final prefix = self.substring(0, self.lastIndexOf('.') + 1);
  final targets = [for (var i = 1; i <= 254; i++) '$prefix$i'];
  final found = <LanDevice>[];
  final known = <String>{};
  // Each address gets a port probe and, where it helps, a ping; it counts
  // as scanned once both are done.
  final pinging = Discovery.canPing;
  var probed = 0;
  var pinged = 0;
  int scanned() => pinging ? (probed + pinged) ~/ 2 : probed;

  void emit({bool done = false}) {
    final devices = [...found]..sort(_order);
    toMain.send(LanScanUpdate(
      devices: devices,
      scanned: scanned(),
      total: targets.length,
      subnet: '${prefix}x',
      done: done,
    ));
  }

  LanDevice device(String ip) => LanDevice(
        ip: ip,
        isSelf: ip == self,
        isGateway: ip != self && _looksLikeGateway(ip),
      );

  void add(String ip) {
    if (!known.add(ip)) return;
    found.add(device(ip));
    emit();
  }

  var nextProbe = 0;
  Future<void> sweep() async {
    while (true) {
      final index = nextProbe++;
      if (index >= targets.length) return;
      final ip = targets[index];
      final alive = ip == self || await _isAlive(ip);
      probed++;
      if (alive) {
        add(ip);
      } else if (probed % 16 == 0) {
        emit(); // keep the progress bar moving through empty stretches
      }
    }
  }

  var nextPing = 0;
  Future<void> pingSweep() async {
    while (true) {
      final index = nextPing++;
      if (index >= targets.length) return;
      final ip = targets[index];
      final alive = !known.contains(ip) && ip != self && await Discovery.ping(ip);
      pinged++;
      if (alive) {
        add(ip);
      } else if (pinged % 16 == 0) {
        emit();
      }
    }
  }

  // The multicast questions take a couple of seconds of listening, so they
  // run alongside the sweep.
  final ssdp = Discovery.ssdp(self);
  final mdns = Discovery.mdns(self);
  await Future.wait([
    for (var i = 0; i < _concurrency; i++) sweep(),
    if (pinging)
      for (var i = 0; i < _pingConcurrency; i++) pingSweep(),
  ]);

  // The sweep has made the system look up every address, so its ARP table
  // now lists whoever is switched on — including devices that ignored
  // every port.
  final macs = await Discovery.arpTable(prefix);
  final answers = <String, Set<String>>{};
  for (final heard in [await ssdp, await mdns]) {
    heard.forEach((ip, hints) => answers.putIfAbsent(ip, () => {}).addAll(hints));
  }
  final inRange = targets.toSet();
  for (final ip in {...macs.keys, ...answers.keys}) {
    if (inRange.contains(ip) && known.add(ip)) found.add(device(ip));
  }

  final locations = <String, String>{};
  for (var i = 0; i < found.length; i++) {
    final ip = found[i].ip;
    final hints = {...?answers[ip]};
    final location = hints.where((h) => h.startsWith(Discovery.locationHint)).firstOrNull;
    if (location != null) locations[ip] = location.substring(Discovery.locationHint.length);
    hints.removeWhere((h) => h.startsWith(Discovery.locationHint));
    found[i] = found[i].copyWith(mac: macs[ip], hints: hints);
  }
  emit();

  // Second pass: ask the live hosts who they are. Runs in parallel — there
  // are only a handful of them, and each query waits on a timeout.
  await Future.wait([
    for (var i = 0; i < found.length; i++)
      _describe(found[i], locations[found[i].ip]).then((device) {
        found[i] = device;
        emit();
      }),
  ]);

  emit(done: true);
}

Future<LanDevice> _describe(LanDevice device, String? location) async {
  final results = await Future.wait([
    lookupDeviceName(device.ip),
    _openPorts(device.ip),
    if (location != null) Discovery.upnpName(device.ip, location),
  ]);
  // Bonjour and NetBIOS names are the ones people chose; a UPnP name is
  // the next best thing — TVs and speakers put their model or room there.
  final name = results[0] as String? ?? (location != null ? results[2] as String? : null);
  return device.copyWith(
    name: name,
    openPorts: results[1] as List<int>,
  );
}

/// Routers, then this machine, then everyone else by address.
int _order(LanDevice a, LanDevice b) {
  int rank(LanDevice d) => d.isGateway ? 0 : (d.isSelf ? 1 : 2);
  final byRank = rank(a).compareTo(rank(b));
  return byRank != 0 ? byRank : a.hostNumber.compareTo(b.hostNumber);
}

/// Home routers sit at .1 or .254 nearly without exception. Dart cannot read
/// the routing table, so the address is the only clue available.
bool _looksLikeGateway(String ip) {
  final last = int.tryParse(ip.split('.').last);
  return last == 1 || last == 254;
}

/// True when anything answers at [ip] — an open port or a refusal.
Future<bool> _isAlive(String ip) async {
  final answered = Completer<bool>();
  final attempts = <ConnectionTask<Socket>>[];
  var pending = _probePorts.length;

  void settle({required bool alive}) {
    if (answered.isCompleted) return;
    if (alive) {
      answered.complete(true);
    } else if (--pending == 0) {
      answered.complete(false);
    }
  }

  for (final port in _probePorts) {
    try {
      final task = await Socket.startConnect(ip, port);
      attempts.add(task);
      unawaited(task.socket.then(
        (socket) {
          socket.destroy();
          settle(alive: true);
        },
        onError: (Object e) {
          final code = e is SocketException ? e.osError?.errorCode : null;
          settle(alive: code != null && kConnectionRefusedCodes.contains(code));
        },
      ));
    } catch (_) {
      settle(alive: false);
    }
  }

  final alive =
      await answered.future.timeout(_connectTimeout, onTimeout: () => false);
  for (final task in attempts) {
    task.cancel(); // stop the probes still waiting on a dead address
  }
  return alive;
}

Future<List<int>> _openPorts(String ip) async {
  final open = <int>[];
  await Future.wait([
    for (final port in _detailPorts)
      Socket.connect(ip, port, timeout: _connectTimeout).then(
        (socket) {
          socket.destroy();
          open.add(port);
        },
        onError: (Object _) {},
      ),
  ]);
  return open..sort();
}

/// This machine's address on the network the user means by "my network":
/// a private IPv4 on a real interface, not a VPN tunnel or a virtual bridge.
Future<String?> localNetworkAddress() async {
  const skip = ['utun', 'tun', 'tap', 'bridge', 'awdl', 'llw', 'ipsec', 'vmnet'];
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );

  String? best;
  for (final interface in interfaces) {
    if (skip.any(interface.name.toLowerCase().startsWith)) continue;
    for (final address in interface.addresses) {
      if (!_isPrivate(address.address)) continue;
      // 192.168.* wins: it is the home range, while 10.* is often corporate.
      if (best == null || address.address.startsWith('192.168.')) {
        best = address.address;
      }
    }
  }
  return best;
}

bool _isPrivate(String ip) {
  final parts = ip.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.any((p) => p == null)) return false;
  final [a!, b!, _, _] = parts;
  if (a == 10) return true;
  if (a == 192 && b == 168) return true;
  return a == 172 && b >= 16 && b <= 31;
}
