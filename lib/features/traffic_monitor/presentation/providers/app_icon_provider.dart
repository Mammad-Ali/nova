import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An app's own icon as PNG, from the system: macOS draws it from the app
/// bundle (MainFlutterWindow.swift), Android from the package
/// (AppTraffic.kt). Null when there is none to have. Kept for the whole run:
/// icons don't change, and the list asks again every few seconds.
final appIconProvider = FutureProvider.family<Uint8List?, String>((ref, source) async {
  if (kIsWeb) return null;
  final channel = switch (defaultTargetPlatform) {
    TargetPlatform.macOS => const MethodChannel('net_pulse/appicons'),
    TargetPlatform.android => const MethodChannel('net_pulse/apps'),
    _ => null,
  };
  if (channel == null) return null;
  try {
    return await channel.invokeMethod<Uint8List>('icon', source);
  } catch (_) {
    return null;
  }
});
