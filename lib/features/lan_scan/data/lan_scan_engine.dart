import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../domain/lan_device.dart';
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

  /// Emits progressively: devices appear as they answer, then fill in with
  /// names and open ports.
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

/// "Connection refused" means something is there and actively said no, which
/// is just as good a sign of life as an open port.
/// 61 = macOS/BSD, 111 = Linux/Android, 10061 = Windows.
const _refusedCodes = {61, 111, 10061};

Future<void> _entry(SendPort toMain) async {
  final self = await _localAddress();
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
  var scanned = 0;
  var next = 0;

  void emit({bool done = false}) {
    final devices = [...found]..sort(_order);
    toMain.send(LanScanUpdate(
      devices: devices,
      scanned: scanned,
      total: targets.length,
      subnet: '${prefix}x',
      done: done,
    ));
  }

  Future<void> sweep() async {
    while (true) {
      final index = next++;
      if (index >= targets.length) return;
      final ip = targets[index];
      final alive = ip == self || await _isAlive(ip);
      scanned++;
      if (alive) {
        found.add(LanDevice(
          ip: ip,
          isSelf: ip == self,
          isGateway: ip != self && _looksLikeGateway(ip),
        ));
        emit();
      } else if (scanned % 16 == 0) {
        emit(); // keep the progress bar moving through empty stretches
      }
    }
  }

  await Future.wait([for (var i = 0; i < _concurrency; i++) sweep()]);
  emit();

  // Second pass: ask the live hosts who they are. Runs in parallel — there
  // are only a handful of them, and each query waits on a timeout.
  await Future.wait([
    for (var i = 0; i < found.length; i++)
      _describe(found[i]).then((device) {
        found[i] = device;
        emit();
      }),
  ]);

  emit(done: true);
}

Future<LanDevice> _describe(LanDevice device) async {
  final results = await Future.wait([
    lookupDeviceName(device.ip),
    _openPorts(device.ip),
  ]);
  return device.copyWith(
    name: results[0] as String?,
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
          settle(alive: code != null && _refusedCodes.contains(code));
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
Future<String?> _localAddress() async {
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
