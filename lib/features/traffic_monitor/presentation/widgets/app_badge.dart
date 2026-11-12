import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/app_traffic.dart';
import '../providers/app_icon_provider.dart';

/// What to call [app] in the list: its own name, or a name for the system
/// and Android's special rows.
String appDisplayName(AppTraffic app, AppStrings strings, {required bool mac}) =>
    switch (app.kind) {
      AppTrafficKind.app => app.name,
      AppTrafficKind.system => mac ? strings.appsSystemMac : strings.appsSystemAndroid,
      AppTrafficKind.removed => strings.appsRemoved,
      AppTrafficKind.hotspot => strings.appsHotspot,
    };

/// The app's own icon; until it arrives, or where there is none, a letter
/// in a colored square — and a symbol for the system's rows.
class AppBadge extends ConsumerWidget {
  const AppBadge({super.key, required this.app, required this.name, required this.color, this.size = 32});
  final AppTraffic app;
  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = app.iconSource;
    final png = source == null ? null : ref.watch(appIconProvider(source)).value;
    if (png != null) {
      // macOS icons carry their own shape and margin; Android's adaptive
      // icons fill the square, so they get rounded corners like the rest.
      return ClipRRect(
        borderRadius: BorderRadius.circular(defaultTargetPlatform == TargetPlatform.android ? size * 0.28 : 0),
        child: Image.memory(png, width: size, height: size, filterQuality: FilterQuality.medium, gaplessPlayback: true),
      );
    }
    final icon = switch (app.kind) {
      AppTrafficKind.app => null,
      AppTrafficKind.system => Icons.settings_rounded,
      AppTrafficKind.removed => Icons.delete_outline_rounded,
      AppTrafficKind.hotspot => Icons.wifi_tethering_rounded,
    };
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.53, color: color)
          : Text(
              letter,
              style: TextStyle(color: color, fontSize: size * 0.47, fontWeight: FontWeight.w800),
            ),
    );
  }
}

/// The same color for an app every time: picked from its name.
Color appColor(AppTraffic app) {
  if (app.kind != AppTrafficKind.app) return AppColors.textMid;
  const palette = [
    AppColors.accentDown,
    AppColors.accentUp,
    AppColors.accentAlt,
    AppColors.green,
    AppColors.amber,
    AppColors.red,
    AppColors.sun,
    AppColors.nebulaViolet,
  ];
  var hash = 0;
  for (final unit in app.name.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}
