import 'lan_device.dart';

/// A device Nova has seen on this network before, with what the user calls
/// it. Remembered across scans, so names stick and newcomers stand out.
class KnownDevice {
  const KnownDevice({
    required this.id,
    required this.firstSeen,
    required this.lastSeen,
    required this.lastIp,
    this.name,
    this.kind,
    this.seenName,
    this.vendor,
    this.seenKind,
  });

  /// See [deviceId].
  final String id;

  /// When Nova first found it; the epoch for devices already there on the
  /// very first scan, which are nobody's news.
  final DateTime firstSeen;
  final DateTime lastSeen;
  final String lastIp;

  /// What the user named it ("Mom's iPhone") and what they say it is.
  final String? name;
  final DeviceKind? kind;

  /// What the scan found out about it last time, for when it isn't there.
  final String? seenName;
  final String? vendor;
  final DeviceKind? seenKind;

  /// Found in the last day — and not on the first scan ever.
  bool isNew(DateTime now) => now.difference(firstSeen) < const Duration(days: 1);

  KnownDevice copyWith({
    DateTime? lastSeen,
    String? lastIp,
    String? seenName,
    String? vendor,
    DeviceKind? seenKind,
  }) =>
      KnownDevice(
        id: id,
        firstSeen: firstSeen,
        lastSeen: lastSeen ?? this.lastSeen,
        lastIp: lastIp ?? this.lastIp,
        name: name,
        kind: kind,
        seenName: seenName ?? this.seenName,
        vendor: vendor ?? this.vendor,
        seenKind: seenKind ?? this.seenKind,
      );

  /// The same device with the user's [name] and [kind]; null clears them.
  KnownDevice named(String? name, DeviceKind? kind) => KnownDevice(
        id: id,
        firstSeen: firstSeen,
        lastSeen: lastSeen,
        lastIp: lastIp,
        name: name == null || name.trim().isEmpty ? null : name.trim(),
        kind: kind,
        seenName: seenName,
        vendor: vendor,
        seenKind: seenKind,
      );

  Map<String, Object?> toJson() => {
        'first': firstSeen.millisecondsSinceEpoch,
        'last': lastSeen.millisecondsSinceEpoch,
        'ip': lastIp,
        if (name != null) 'name': name,
        if (kind != null) 'kind': kind!.name,
        if (seenName != null) 'seen': seenName,
        if (vendor != null) 'vendor': vendor,
        if (seenKind != null) 'seenKind': seenKind!.name,
      };

  static KnownDevice fromJson(String id, Map<String, dynamic> json) {
    DeviceKind? kindOf(Object? name) => DeviceKind.values.where((k) => k.name == name).firstOrNull;
    return KnownDevice(
      id: id,
      firstSeen: DateTime.fromMillisecondsSinceEpoch((json['first'] as num).toInt()),
      lastSeen: DateTime.fromMillisecondsSinceEpoch((json['last'] as num).toInt()),
      lastIp: '${json['ip']}',
      name: json['name'] as String?,
      kind: kindOf(json['kind']),
      seenName: json['seen'] as String?,
      vendor: json['vendor'] as String?,
      seenKind: kindOf(json['seenKind']),
    );
  }
}

/// What identifies a device from scan to scan: its hardware address where
/// the system shows one (Windows, Linux), else its network address — macOS
/// 27 and Android keep hardware addresses from apps, and routers mostly
/// give a device the same address every time. This machine has a fixed id.
String deviceId(LanDevice device) {
  if (device.isSelf) return 'self';
  if (device.mac != null) return 'mac:${device.mac}';
  return 'ip:${device.ip}';
}
