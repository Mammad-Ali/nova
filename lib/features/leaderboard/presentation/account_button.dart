import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'leaderboard_providers.dart';
import 'sign_in_sheet.dart';

/// The header's way into an account: a "Sign in" button while nobody is
/// signed in, the nickname with its initial once somebody is. Both open the
/// sign-in sheet, which doubles as the account panel.
///
/// [compact] keeps it to an icon's width, for a phone's header where the
/// other icons already take most of the row.
class AccountButton extends ConsumerWidget {
  const AccountButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final account = ref.watch(accountProvider);
    void open() => showSignInSheet(context);

    if (account == null) {
      if (compact) {
        return IconButton(
          onPressed: open,
          icon: Icon(Icons.account_circle_outlined, color: AppColors.onGlass),
          tooltip: t.signIn,
        );
      }
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: FilledButton.icon(
          onPressed: open,
          icon: const Icon(Icons.login_rounded, size: 18),
          label: Text(t.signIn),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            shape: const StadiumBorder(),
          ),
        ),
      );
    }

    final avatar = _Initial(nickname: account.nickname);
    if (compact) {
      return IconButton(onPressed: open, icon: avatar, tooltip: account.nickname);
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: OutlinedButton(
        onPressed: open,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onGlass,
          side: BorderSide(color: AppColors.onGlass.withValues(alpha: 0.22)),
          padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar,
            const SizedBox(width: 10),
            // Nicknames run to 20 characters; the header must not grow with
            // them.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                account.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.nickname});
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final letter = nickname.trim().isEmpty
        ? '?'
        : nickname.trim().characters.first.toUpperCase();
    return CircleAvatar(
      radius: 15,
      backgroundColor: AppColors.sun,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
