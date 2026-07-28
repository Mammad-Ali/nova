import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'app_strings.dart';
import 'locale_provider.dart';

/// Иконка-глобус в заголовке: открывает выбор языка.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return IconButton(
      onPressed: () => _showPicker(context, ref),
      icon: Icon(Icons.language_rounded, color: AppColors.textMid),
      tooltip: t.language,
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(localeProvider);
    final t = ref.read(stringsProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.bg1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.onGlass.withValues(alpha: 0.12), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          // Material даёт ListTile поверхность для чернил/фона, иначе Flutter
          // ругается, что они «невидимы» на цветном Container поверх.
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.language,
                    style: TextStyle(
                      color: AppColors.onGlass,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              for (final l in AppLocale.values)
                _LanguageTile(
                  locale: l,
                  selected: l == current,
                  onTap: () {
                    ref.read(localeProvider.notifier).set(l);
                    Navigator.of(context).pop();
                  },
                ),
              const SizedBox(height: 12),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final AppLocale locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        locale.nativeName,
        style: TextStyle(
          color: selected ? AppColors.accentDown : AppColors.onGlass,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: AppColors.accentDown)
          : null,
    );
  }
}
