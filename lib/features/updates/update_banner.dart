import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/theme/app_theme.dart';
import '../more/presentation/more_links.dart';
import 'update_provider.dart';

/// "Nova 1.3.1 is available" with a download button, at the top of the
/// speed test screen. Takes no room at all while there is nothing new.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider);
    if (update == null) return const SizedBox.shrink();

    final t = ref.watch(stringsProvider);
    final current = ref.watch(appVersionProvider).asData?.value;
    // The installer for this system; the release page where there is none.
    final target = visitorDownload();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 6, 12),
        decoration: glassCard(radius: 18, glow: AppColors.sun).copyWith(
          border: Border.all(color: AppColors.sun.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.system_update_alt_rounded, color: AppColors.sun, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.fill(t.updateAvailable, [update.version]),
                    style: TextStyle(
                      color: AppColors.onGlass,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (current != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.fill(t.updateYouHave, [current]),
                      style: TextStyle(color: AppColors.textMid, fontSize: 12.5, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () => target != null
                            ? startDownload(target)
                            : openLink(update.pageUrl),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(t.updateDownload),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          shape: const StadiumBorder(),
                        ),
                      ),
                      TextButton(
                        onPressed: () => openLink(update.pageUrl),
                        style: TextButton.styleFrom(foregroundColor: AppColors.accentAlt),
                        child: Text(t.updateWhatsNew),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: ref.read(updateProvider.notifier).dismiss,
              icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textLo),
              tooltip: t.updateLater,
            ),
          ],
        ),
      ),
    );
  }
}
