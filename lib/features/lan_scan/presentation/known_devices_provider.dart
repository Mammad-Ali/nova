import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/known_device.dart';
import '../domain/lan_device.dart';

/// Every device Nova has seen on the network, by [deviceId], with the
/// names the user gave them. Each finished scan updates it.
final knownDevicesProvider =
    NotifierProvider<KnownDevicesNotifier, Map<String, KnownDevice>>(KnownDevicesNotifier.new);

class KnownDevicesNotifier extends Notifier<Map<String, KnownDevice>> {
  static const _key = 'lan_devices_v1';

  /// Devices not seen for this long are forgotten, unless named.
  static const _forgetAfter = Duration(days: 60);

  late final Future<void> _loaded = _load();

  @override
  Map<String, KnownDevice> build() {
    _loaded.ignore();
    return const {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      state = {
        for (final MapEntry(key: id, value: json) in decoded.entries)
          id: KnownDevice.fromJson(id, json as Map<String, dynamic>),
      };
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode({for (final d in state.values) d.id: d.toJson()}));
    } catch (_) {}
  }

  /// Notes everyone a finished scan found. On the very first scan nobody
  /// counts as new: they were all there before Nova was.
  Future<void> recordScan(List<LanDevice> devices, {DateTime? now}) async {
    await _loaded;
    final at = now ?? DateTime.now();
    final firstEver = state.isEmpty;
    final next = {...state};
    for (final device in devices) {
      final id = deviceId(device);
      final before = next[id];
      next[id] = before == null
          ? KnownDevice(
              id: id,
              firstSeen: firstEver || device.isSelf ? DateTime.fromMillisecondsSinceEpoch(0) : at,
              lastSeen: at,
              lastIp: device.ip,
              seenName: device.name,
              vendor: device.vendor,
              seenKind: device.kind,
            )
          : before.copyWith(
              lastSeen: at,
              lastIp: device.ip,
              seenName: device.name,
              vendor: device.vendor,
              seenKind: device.kind,
            );
    }
    next.removeWhere((_, d) => d.name == null && at.difference(d.lastSeen) > _forgetAfter);
    state = next;
    await _save();
  }

  /// Gives [device] the user's [name] and [kind]; empty or null clears them.
  Future<void> rename(LanDevice device, String? name, DeviceKind? kind) async {
    await _loaded;
    final id = deviceId(device);
    final now = DateTime.now();
    final before = state[id] ??
        KnownDevice(
          id: id,
          firstSeen: DateTime.fromMillisecondsSinceEpoch(0),
          lastSeen: now,
          lastIp: device.ip,
          seenName: device.name,
          vendor: device.vendor,
          seenKind: device.kind,
        );
    state = {...state, id: before.named(name, kind)};
    await _save();
  }
}
