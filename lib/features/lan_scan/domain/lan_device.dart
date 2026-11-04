/// A device answering on the local network.
class LanDevice {
  const LanDevice({
    required this.ip,
    this.name,
    this.openPorts = const [],
    this.isSelf = false,
    this.isGateway = false,
    this.mac,
    this.vendor,
    this.hints = const {},
  });

  final String ip;

  /// Name the device announces about itself, without the `.local` suffix.
  /// Null when it answers neither mDNS, NetBIOS nor UPnP — phones in
  /// particular often stay anonymous.
  final String? name;

  final List<int> openPorts;

  /// This machine, the one running Nova.
  final bool isSelf;

  /// The router. Guessed from the address rather than read from the routing
  /// table, which no platform exposes to Dart.
  final bool isGateway;

  /// Hardware address, "b4:b0:24:64:df:b9", from the system's ARP table.
  /// Desktop only: Android keeps the table from apps.
  final String? mac;

  /// Maker, looked up from the first half of [mac]: "TP-Link", "Samsung".
  final String? vendor;

  /// What the device said about itself when asked over the network:
  /// "mdns:_airplay", "ssdp:urn:dial-multiscreen-org:service:dial:1"…
  final Set<String> hints;

  /// Last octet, used for ordering.
  int get hostNumber => int.tryParse(ip.split('.').last) ?? 0;

  /// A made-up hardware address: phones and, lately, laptops use a random
  /// one per network ("private Wi-Fi address"), so it names no maker. Such
  /// an address has the "locally administered" bit set in its first byte.
  bool get privateMac {
    final first = mac == null ? null : int.tryParse(mac!.substring(0, 2), radix: 16);
    return first != null && first & 0x02 != 0;
  }

  /// The first half of [mac], "B4B024", which says who made the device;
  /// null when there is none or it is made up.
  String? get macPrefix => mac == null || privateMac
      ? null
      : mac!.replaceAll(':', '').substring(0, 6).toUpperCase();

  DeviceKind get kind {
    if (isGateway) return DeviceKind.router;
    if (isSelf) return DeviceKind.computer;

    // From the surest clue to the vaguest: what the device calls itself,
    // the services it offers, who made it, the ports it has open.
    return _kindFromName(name) ??
        _kindFromHints(hints) ??
        _kindFromVendor(vendor) ??
        _kindFromPorts(openPorts) ??
        // A private address and nothing else to go on is, nearly always,
        // a phone or a tablet.
        (privateMac ? DeviceKind.phone : DeviceKind.unknown);
  }

  LanDevice copyWith({
    String? name,
    List<int>? openPorts,
    String? mac,
    String? vendor,
    Set<String>? hints,
  }) =>
      LanDevice(
        ip: ip,
        name: name ?? this.name,
        openPorts: openPorts ?? this.openPorts,
        isSelf: isSelf,
        isGateway: isGateway,
        mac: mac ?? this.mac,
        vendor: vendor ?? this.vendor,
        hints: hints ?? this.hints,
      );
}

enum DeviceKind { router, computer, phone, tv, printer, nas, smartHome, console, unknown }

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

DeviceKind? _kindFromPorts(List<int> ports) {
  for (final entry in kPortHints.entries) {
    if (ports.contains(entry.key)) return entry.value;
  }
  return null;
}

/// Pieces of what devices announce over Bonjour (mDNS) and UPnP (SSDP),
/// checked in this order: a Mac offers AirPlay too, but screen sharing says
/// "computer" first.
const _hintKinds = <String, DeviceKind>{
  'mdns:_ipp': DeviceKind.printer, // and _ipps
  'mdns:_printer': DeviceKind.printer,
  'mdns:_pdl-datastream': DeviceKind.printer,
  'mdns:_uscan': DeviceKind.printer,
  'device:printer': DeviceKind.printer,
  'mdns:_hap': DeviceKind.smartHome, // HomeKit accessory
  'mdns:_matter': DeviceKind.smartHome,
  'mdns:_hue': DeviceKind.smartHome,
  'ipbridge': DeviceKind.smartHome, // Philips Hue bridge
  'mdns:_miio': DeviceKind.smartHome, // Xiaomi
  'mdns:_shelly': DeviceKind.smartHome,
  'mdns:_esphomelib': DeviceKind.smartHome,
  'mdns:_ewelink': DeviceKind.smartHome,
  'mdns:_wled': DeviceKind.smartHome,
  'xbox': DeviceKind.console,
  'playstation': DeviceKind.console,
  'nintendo': DeviceKind.console,
  'mdns:_rfb': DeviceKind.computer, // screen sharing
  'mdns:_ssh': DeviceKind.computer,
  'mdns:_sftp-ssh': DeviceKind.computer,
  'mdns:_workstation': DeviceKind.computer,
  'microsoft-windows': DeviceKind.computer,
  'mdns:_apple-mobdev2': DeviceKind.phone, // iPhone and iPad sync
  'mdns:_googlecast': DeviceKind.tv,
  'mdns:_airplay': DeviceKind.tv,
  'mdns:_raop': DeviceKind.tv, // AirPlay speakers
  'mdns:_spotify-connect': DeviceKind.tv,
  'mdns:_sonos': DeviceKind.tv,
  'dial-multiscreen': DeviceKind.tv, // smart TVs' "cast to TV"
  'device:mediarenderer': DeviceKind.tv,
  'roku': DeviceKind.tv,
  'device:mediaserver': DeviceKind.nas,
  'mdns:_adisk': DeviceKind.nas, // Time Machine disk
  'internetgatewaydevice': DeviceKind.router, // mesh points, extenders
};

DeviceKind? _kindFromHints(Set<String> hints) {
  if (hints.isEmpty) return null;
  for (final entry in _hintKinds.entries) {
    if (hints.any((h) => h.contains(entry.key))) return entry.value;
  }
  return null;
}

/// Makers whose name alone says what a device is. Most (Apple, Samsung,
/// TP-Link…) make too many kinds of things to guess from.
const _vendorKinds = <String, DeviceKind>{
  'Sony PlayStation': DeviceKind.console,
  'Nintendo': DeviceKind.console,
  'OPPO': DeviceKind.phone,
  'vivo': DeviceKind.phone,
  'OnePlus': DeviceKind.phone,
  'realme': DeviceKind.phone,
  'Honor': DeviceKind.phone,
  'Motorola': DeviceKind.phone,
  'Roku': DeviceKind.tv,
  'Sonos': DeviceKind.tv,
  'Philips Hue': DeviceKind.smartHome,
  'Espressif': DeviceKind.smartHome, // the chip in most smart plugs and bulbs
  'Tuya': DeviceKind.smartHome,
  'Hikvision': DeviceKind.smartHome, // cameras
  'Dahua': DeviceKind.smartHome,
  'Synology': DeviceKind.nas,
  'QNAP': DeviceKind.nas,
  'Canon': DeviceKind.printer,
  'Epson': DeviceKind.printer,
  'Brother': DeviceKind.printer,
  'Raspberry Pi': DeviceKind.computer,
  'Intel': DeviceKind.computer,
  'Dell': DeviceKind.computer,
  'Lenovo': DeviceKind.computer,
  'Acer': DeviceKind.computer,
};

DeviceKind? _kindFromVendor(String? vendor) =>
    vendor == null ? null : _vendorKinds[vendor];

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
  'homepod': DeviceKind.tv,
  'sonos': DeviceKind.tv,
  'echo': DeviceKind.smartHome,
  'alexa': DeviceKind.smartHome,
  'nest': DeviceKind.smartHome,
  'philips-hue': DeviceKind.smartHome,
  'camera': DeviceKind.smartHome,
  'playstation': DeviceKind.console,
  'ps5': DeviceKind.console,
  'ps4': DeviceKind.console,
  'xbox': DeviceKind.console,
  'nintendo': DeviceKind.console,
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
