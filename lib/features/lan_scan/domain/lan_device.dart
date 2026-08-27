/// A device answering on the local network.
class LanDevice {
  const LanDevice({
    required this.ip,
    this.name,
    this.openPorts = const [],
    this.isSelf = false,
    this.isGateway = false,
  });

  final String ip;

  /// Name the device announces about itself, without the `.local` suffix.
  /// Null when it answers neither mDNS nor NetBIOS — phones in particular
  /// often stay anonymous.
  final String? name;

  final List<int> openPorts;

  /// This machine, the one running Nova.
  final bool isSelf;

  /// The router. Guessed from the address rather than read from the routing
  /// table, which no platform exposes to Dart.
  final bool isGateway;

  /// Last octet, used for ordering.
  int get hostNumber => int.tryParse(ip.split('.').last) ?? 0;

  DeviceKind get kind {
    if (isGateway) return DeviceKind.router;
    if (isSelf) return DeviceKind.computer;

    // The announced name is the better clue, so it wins over open ports.
    final byName = _kindFromName(name);
    if (byName != null) return byName;
    return _kindFromPorts(openPorts);
  }

  LanDevice copyWith({String? name, List<int>? openPorts}) => LanDevice(
        ip: ip,
        name: name ?? this.name,
        openPorts: openPorts ?? this.openPorts,
        isSelf: isSelf,
        isGateway: isGateway,
      );
}

enum DeviceKind { router, computer, phone, tv, printer, nas, unknown }

/// Ports that identify a device once something answers on them.
const kPortHints = <int, DeviceKind>{
  9100: DeviceKind.printer, // raw printing
  631: DeviceKind.printer, // IPP
  515: DeviceKind.printer, // LPD
  62078: DeviceKind.phone, // iPhone / iPad sync service
  5555: DeviceKind.phone, // Android debug bridge
  8009: DeviceKind.tv, // Chromecast
  7000: DeviceKind.tv, // AirPlay
  3689: DeviceKind.tv, // AirPlay audio
  32400: DeviceKind.nas, // Plex
  548: DeviceKind.nas, // AFP
  3389: DeviceKind.computer, // RDP
  445: DeviceKind.computer, // SMB
  139: DeviceKind.computer,
};

DeviceKind _kindFromPorts(List<int> ports) {
  for (final entry in kPortHints.entries) {
    if (ports.contains(entry.key)) return entry.value;
  }
  return DeviceKind.unknown;
}

/// Words devices habitually put in their own names.
const _nameHints = <String, DeviceKind>{
  'iphone': DeviceKind.phone,
  'ipad': DeviceKind.phone,
  'android': DeviceKind.phone,
  'galaxy': DeviceKind.phone,
  'pixel': DeviceKind.phone,
  'xiaomi': DeviceKind.phone,
  'redmi': DeviceKind.phone,
  'huawei': DeviceKind.phone,
  'macbook': DeviceKind.computer,
  'imac': DeviceKind.computer,
  'mac-mini': DeviceKind.computer,
  'desktop': DeviceKind.computer,
  'laptop': DeviceKind.computer,
  'appletv': DeviceKind.tv,
  'apple-tv': DeviceKind.tv,
  'chromecast': DeviceKind.tv,
  'roku': DeviceKind.tv,
  'firetv': DeviceKind.tv,
  'bravia': DeviceKind.tv,
  'samsung': DeviceKind.tv,
  'lg-tv': DeviceKind.tv,
  'printer': DeviceKind.printer,
  'epson': DeviceKind.printer,
  'canon': DeviceKind.printer,
  'brother': DeviceKind.printer,
  'deskjet': DeviceKind.printer,
  'laserjet': DeviceKind.printer,
  'synology': DeviceKind.nas,
  'qnap': DeviceKind.nas,
  'nas': DeviceKind.nas,
  'router': DeviceKind.router,
  'keenetic': DeviceKind.router,
  'mikrotik': DeviceKind.router,
  'tp-link': DeviceKind.router,
};

DeviceKind? _kindFromName(String? name) {
  if (name == null) return null;
  final lower = name.toLowerCase();
  for (final entry in _nameHints.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return null;
}

/// Progress of a scan. Devices arrive as they are found, so the list grows
/// while [scanned] climbs towards [total].
class LanScanUpdate {
  const LanScanUpdate({
    required this.devices,
    required this.scanned,
    required this.total,
    this.subnet,
    this.done = false,
    this.failure,
  });

  final List<LanDevice> devices;
  final int scanned;
  final int total;

  /// Subnet being scanned, e.g. `192.168.0.x`.
  final String? subnet;

  final bool done;
  final LanScanFailure? failure;

  double get fraction => total == 0 ? 0 : scanned / total;
}

enum LanScanFailure {
  /// No usable private IPv4 address — no Wi-Fi or cable, or only a VPN.
  noNetwork,
}
