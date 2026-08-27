import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/lan_device.dart';
import 'lan_scan_provider.dart';

/// Opens the "who's on my network" sheet.
void showLanScanSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _LanScanSheet(),
  );
}

class _LanScanSheet extends ConsumerWidget {
  const _LanScanSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(lanScanProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.onGlass.withValues(alpha: 0.12), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.onGlass.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.lanTitle,
                        style: TextStyle(
                          color: AppColors.onGlass,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (s.running)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentAlt,
                        ),
                      )
                    else
                      IconButton(
                        onPressed: ref.read(lanScanProvider.notifier).run,
                        icon: Icon(Icons.refresh_rounded,
                            color: AppColors.textMid),
                        tooltip: t.lanRefresh,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    s.running
                        ? '${t.lanScanning}  ${s.subnet ?? ''}'
                        : t.lanHint,
                    style: TextStyle(color: AppColors.textLo, fontSize: 12),
                  ),
                ),
              ),
              if (s.running) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: s.progress == 0 ? null : s.progress,
                      minHeight: 3,
                      backgroundColor: AppColors.onGlass.withValues(alpha: 0.06),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.accentAlt),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Flexible(child: _Body(state: s, strings: t)),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.strings});
  final LanScanState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    if (state.failure == LanScanFailure.noNetwork) {
      return _Message(text: strings.lanNoNetwork);
    }
    if (state.devices.isEmpty) {
      return _Message(
        text: state.running ? strings.lanScanning : strings.lanNothingFound,
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: state.devices.length,
      itemBuilder: (_, i) =>
          _DeviceRow(device: state.devices[i], strings: strings),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textLo, fontSize: 13),
        ),
      );
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.strings});
  final LanDevice device;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final accent = device.isGateway
        ? AppColors.sun
        : device.isSelf
            ? AppColors.accentAlt
            : AppColors.onGlass;
    final title = device.name ?? _kindLabel(device.kind, strings);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: glassCard(radius: 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_kindIcon(device.kind), size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.onGlass,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  device.ip,
                  style: TextStyle(
                    color: AppColors.textLo,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (device.isGateway)
            _Tag(text: strings.lanRouter, color: AppColors.sun)
          else if (device.isSelf)
            _Tag(text: strings.lanThisDevice, color: AppColors.accentAlt),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

IconData _kindIcon(DeviceKind kind) => switch (kind) {
      DeviceKind.router => Icons.router_rounded,
      DeviceKind.computer => Icons.computer_rounded,
      DeviceKind.phone => Icons.smartphone_rounded,
      DeviceKind.tv => Icons.tv_rounded,
      DeviceKind.printer => Icons.print_rounded,
      DeviceKind.nas => Icons.storage_rounded,
      DeviceKind.unknown => Icons.devices_other_rounded,
    };

String _kindLabel(DeviceKind kind, AppStrings s) => switch (kind) {
      DeviceKind.router => s.lanRouter,
      DeviceKind.computer => s.lanKindComputer,
      DeviceKind.phone => s.lanKindPhone,
      DeviceKind.tv => s.lanKindTv,
      DeviceKind.printer => s.lanKindPrinter,
      DeviceKind.nas => s.lanKindNas,
      DeviceKind.unknown => s.lanDeviceGeneric,
    };
