import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../shell/tray_service.dart' show isDesktop;
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
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.fromBorderSide(BorderSide(color: AppColors.onGlass.withValues(alpha: 0.12))),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: SingleChildScrollView(
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
                      color: AppColors.onGlass.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        t.settings,
                        style: TextStyle(
                          color: AppColors.onGlass,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Alerts need the app running in the background and system
                  // notifications — neither exists for a web page.
                  if (!kIsWeb) ...[
                    SwitchListTile(
                      value: s.alertsEnabled,
                      onChanged: notifier.setAlertsEnabled,
                      activeThumbColor: AppColors.nebulaViolet,
                      title: Text(
                        t.alertsEnable,
                        style: TextStyle(color: AppColors.onGlass, fontSize: 14),
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
                  ] else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Text(
                        t.settingsWebNote,
                        style: TextStyle(color: AppColors.textLo, fontSize: 13, height: 1.4),
                      ),
                    ),
                  // The icon and its title exist only in the desktop apps.
                  if (isDesktop) ...[
                    Divider(color: AppColors.onGlass.withValues(alpha: 0.12), height: 28),
                    _MenuBarSettings(settings: s),
                  ],
                  if (!kIsWeb) ...[
                    Divider(color: AppColors.onGlass.withValues(alpha: 0.12), height: 28),
                    _AutoTestSettings(settings: s),
                  ],
                  Divider(color: AppColors.onGlass.withValues(alpha: 0.12), height: 28),
                  ListTile(
                    leading: Icon(Icons.table_view_rounded,
                        color: AppColors.nebulaViolet),
                    title: Text(
                      t.exportCsv,
                      style: TextStyle(color: AppColors.onGlass, fontSize: 14),
                    ),
                    onTap: () => _exportCsv(context, ref),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
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

/// A numeric threshold field; an empty string disables the alert.
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
              style: TextStyle(color: AppColors.onGlass),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle:
                    TextStyle(color: AppColors.textLo, fontSize: 12),
                isDense: true,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.onGlass.withValues(alpha: 0.24)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.nebulaViolet),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.textMid,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

/// A row of choices, one of them picked.
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(label(value)),
            selected: value == selected,
            onSelected: (_) => onSelected(value),
            showCheckmark: false,
            labelStyle: TextStyle(
              color: value == selected ? Colors.black : AppColors.onGlass,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: Colors.white,
            backgroundColor: AppColors.onGlass.withValues(alpha: 0.06),
            side: BorderSide(color: AppColors.onGlass.withValues(alpha: 0.14)),
          ),
      ],
    );
  }
}

/// Settings → Menu bar (macOS) or Tray (Windows): the icon on or off and,
/// on the Mac, what its title shows.
class _MenuBarSettings extends ConsumerWidget {
  const _MenuBarSettings({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    // Only the Mac menu bar shows text beside the icon.
    final hasTitle = defaultTargetPlatform == TargetPlatform.macOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(hasTitle ? t.settingsMenuBar : t.settingsTray),
        SwitchListTile(
          value: settings.menuBarEnabled,
          onChanged: notifier.setMenuBarEnabled,
          activeThumbColor: AppColors.nebulaViolet,
          title: Text(
            hasTitle ? t.menuBarShow : t.trayShow,
            style: TextStyle(color: AppColors.onGlass, fontSize: 14),
          ),
          subtitle: settings.menuBarEnabled
              ? null
              : Text(t.menuBarOffHint, style: TextStyle(color: AppColors.amber, fontSize: 12)),
        ),
        if (hasTitle && settings.menuBarEnabled) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Text(t.menuBarShows, style: TextStyle(color: AppColors.textLo, fontSize: 12.5)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Choices<MenuBarContent>(
              values: MenuBarContent.values,
              selected: settings.menuBarContent,
              label: (c) => _contentLabel(t, c),
              onSelected: notifier.setMenuBarContent,
            ),
          ),
          if (settings.menuBarContent != MenuBarContent.iconOnly &&
              settings.menuBarContent != MenuBarContent.today)
            SwitchListTile(
              value: settings.menuBarBits,
              onChanged: notifier.setMenuBarBits,
              activeThumbColor: AppColors.nebulaViolet,
              title: Text(t.menuBarBits, style: TextStyle(color: AppColors.onGlass, fontSize: 14)),
            ),
        ],
      ],
    );
  }

  static String _contentLabel(AppStrings t, MenuBarContent c) => switch (c) {
        MenuBarContent.speedAndHour => t.menuBarSpeedHour,
        MenuBarContent.speed => t.menuBarSpeed,
        MenuBarContent.downUp => t.menuBarDownUp,
        MenuBarContent.today => t.menuBarToday,
        MenuBarContent.iconOnly => t.menuBarIcon,
      };
}

/// Settings → Automatic tests: off until switched on, then every 1, 3 or 6
/// hours (auto_test_provider.dart does the running).
class _AutoTestSettings extends ConsumerWidget {
  const _AutoTestSettings({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(t.autoTestTitle),
        SwitchListTile(
          value: settings.autoTestEnabled,
          onChanged: notifier.setAutoTestEnabled,
          activeThumbColor: AppColors.nebulaViolet,
          title: Text(t.autoTestEnable, style: TextStyle(color: AppColors.onGlass, fontSize: 14)),
          subtitle: Text(
            t.autoTestHint,
            style: TextStyle(color: AppColors.textLo, fontSize: 12, height: 1.4),
          ),
        ),
        if (settings.autoTestEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
            child: Row(
              children: [
                Text(t.autoTestEvery, style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                const SizedBox(width: 12),
                _Choices<int>(
                  values: autoTestIntervals,
                  selected: settings.autoTestHours,
                  label: (h) => AppStrings.fill(t.autoTestHours, ['$h']),
                  onSelected: notifier.setAutoTestHours,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
