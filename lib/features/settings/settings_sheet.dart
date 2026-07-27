import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_provider.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../speedtest/data/export_service.dart';
import '../speedtest/presentation/providers/speedtest_history_provider.dart';

void showSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.fromBorderSide(BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.settings,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SwitchListTile(
                  value: s.alertsEnabled,
                  onChanged: notifier.setAlertsEnabled,
                  activeThumbColor: AppColors.auroraTeal,
                  title: Text(
                    t.alertsEnable,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                _NumberField(
                  label: t.alertMinSpeed,
                  hint: t.notSet,
                  value: s.minSpeedMbps,
                  enabled: s.alertsEnabled,
                  onChanged: notifier.setMinSpeed,
                ),
                _NumberField(
                  label: t.alertDailyLimit,
                  hint: t.notSet,
                  value: s.dailyLimitGb,
                  enabled: s.alertsEnabled,
                  onChanged: notifier.setDailyLimit,
                ),
                const Divider(color: Colors.white12, height: 28),
                ListTile(
                  leading: const Icon(Icons.table_view_rounded,
                      color: AppColors.auroraTeal),
                  title: Text(
                    t.exportCsv,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () => _exportCsv(context, ref),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final t = ref.read(stringsProvider);
    final records = ref.read(speedTestHistoryProvider);
    final path = await const ExportService().saveHistoryCsv(records);
    if (path == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${t.savedTo}: $path'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
      ));
  }
}

/// Поле для числового порога; пустая строка = выключено.
class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.hint,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final double? value;
  final bool enabled;
  final ValueChanged<double?> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.value?.toStringAsFixed(0) ?? '');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.enabled ? Colors.white : AppColors.textLo,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: TextField(
              controller: _c,
              enabled: widget.enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle:
                    const TextStyle(color: AppColors.textLo, fontSize: 12),
                isDense: true,
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.auroraTeal),
                ),
              ),
              onSubmitted: _apply,
              onTapOutside: (_) => _apply(_c.text),
            ),
          ),
        ],
      ),
    );
  }

  void _apply(String text) {
    final v = double.tryParse(text.trim().replaceAll(',', '.'));
    widget.onChanged(v != null && v > 0 ? v : null);
  }
}
