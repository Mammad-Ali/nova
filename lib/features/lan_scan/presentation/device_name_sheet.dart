import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/known_device.dart';
import '../domain/lan_device.dart';
import 'known_devices_provider.dart';
import 'lan_scan_sheet.dart';

/// Lets the user name a device and say what it is: "Mom's iPhone", a
/// phone. Shown by tapping a device in the list.
void showDeviceNameSheet(BuildContext context, {required LanDevice device, KnownDevice? known}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _DeviceNameSheet(device: device, known: known),
  );
}

class _DeviceNameSheet extends ConsumerStatefulWidget {
  const _DeviceNameSheet({required this.device, required this.known});
  final LanDevice device;
  final KnownDevice? known;

  @override
  ConsumerState<_DeviceNameSheet> createState() => _DeviceNameSheetState();
}

class _DeviceNameSheetState extends ConsumerState<_DeviceNameSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.known?.name ?? '');
  late DeviceKind _kind = widget.known?.kind ?? widget.device.kind;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // A kind left as the scan guessed it isn't an override.
    final kind = _kind == widget.device.kind ? null : _kind;
    await ref.read(knownDevicesProvider.notifier).rename(widget.device, _name.text, kind);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final device = widget.device;
    final found = device.name ?? deviceKindLabel(device.kind, t);

    return Padding(
      // Keep the field above the on-screen keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bg1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.fromBorderSide(BorderSide(color: AppColors.onGlass.withValues(alpha: 0.12))),
        ),
        child: SafeArea(
          top: false,
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.onGlass.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.lanNameTitle,
                    style: TextStyle(color: AppColors.onGlass, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [device.ip, if (device.vendor != null) device.vendor!].join('  ·  '),
                    style: TextStyle(color: AppColors.textLo, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 40,
                    style: TextStyle(color: AppColors.onGlass),
                    decoration: InputDecoration(labelText: t.lanNameField, hintText: found, counterText: ''),
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 16),
                  Text(t.lanKindField, style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final kind in DeviceKind.values)
                        if (kind != DeviceKind.router || device.isGateway)
                          ChoiceChip(
                            avatar: Icon(deviceKindIcon(kind), size: 16,
                                color: kind == _kind ? Colors.black : AppColors.textMid),
                            label: Text(deviceKindLabel(kind, t)),
                            selected: kind == _kind,
                            onSelected: (_) => setState(() => _kind = kind),
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              color: kind == _kind ? Colors.black : AppColors.onGlass,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            selectedColor: Colors.white,
                            backgroundColor: AppColors.onGlass.withValues(alpha: 0.06),
                            side: BorderSide(color: AppColors.onGlass.withValues(alpha: 0.14)),
                          ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(t.lanNameNote, style: TextStyle(color: AppColors.textLo, fontSize: 12)),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: _save, child: Text(t.lanSave)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
