import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_config.dart';
import '../../../core/cloud/cloud_session.dart';
import '../../../core/cloud/google_identity.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'leaderboard_providers.dart';

/// Opens sign-in, or the account panel when somebody is already signed in.
void showSignInSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _SignInSheet(),
  );
}

class _SignInSheet extends ConsumerStatefulWidget {
  const _SignInSheet();

  @override
  ConsumerState<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends ConsumerState<_SignInSheet> {
  late final TextEditingController _nickname = TextEditingController(
    text: ref.read(accountProvider)?.nickname ?? '',
  );
  var _busy = false;

  /// Shown under the button: "finish in your browser" while a desktop
  /// sign-in waits, or why it failed.
  String? _message;
  var _messageIsError = false;

  /// Desktop sign-in happens in the system browser, which the person has to
  /// be told about; Android shows its own sheet and the web leaves the page.
  static bool get _signsInViaBrowser =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final t = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _message = _signsInViaBrowser ? t.signInWaiting : null;
      _messageIsError = false;
    });
    String? failure;
    try {
      await ref.read(accountProvider.notifier).signIn();
    } on GoogleSignInFailed catch (e) {
      // Closing Google's page is a choice, not an error to report.
      if (!e.cancelled) failure = t.signInFailed;
    } catch (_) {
      failure = t.signInFailed;
    }
    if (!mounted) return;
    _nickname.text = ref.read(accountProvider)?.nickname ?? '';
    setState(() {
      _busy = false;
      _message = failure;
      _messageIsError = failure != null;
    });
  }

  Future<void> _save() async {
    await ref.read(accountProvider.notifier).setNickname(_nickname.text);
    // The board shows nicknames, so it has to be rebuilt after a rename.
    await ref.read(leaderboardProvider.notifier).refresh();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _signOut() async {
    await ref.read(accountProvider.notifier).signOut();
    await ref.read(leaderboardProvider.notifier).refresh();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final account = ref.watch(accountProvider);
    final email = ref.watch(cloudSessionProvider)?.email;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.onGlass.withValues(alpha: 0.12)),
        ),
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
                    color: AppColors.onGlass.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.lbSignInTitle,
                      style: TextStyle(
                        color: AppColors.onGlass,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.lbSignInHint,
                      style: TextStyle(color: AppColors.textLo, fontSize: 12.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (account == null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _GoogleButton(
                      label: t.lbSignInGoogle,
                      busy: _busy,
                      onTap: _busy ? null : _signIn,
                    ),
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _messageIsError ? AppColors.amber : AppColors.textMid,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ] else ...[
                  if (email != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: Text(
                        // Shown to the account's owner only — never published.
                        AppStrings.fill(t.accountGoogle, [email]),
                        style: TextStyle(color: AppColors.textMid, fontSize: 12.5),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _nickname,
                      maxLength: 20,
                      style: TextStyle(color: AppColors.onGlass, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: t.lbNickname,
                        labelStyle: TextStyle(color: AppColors.textLo),
                        helperText: t.lbNicknameHint,
                        helperMaxLines: 2,
                        helperStyle: TextStyle(
                          color: AppColors.textLo,
                          fontSize: 11,
                        ),
                        counterText: '',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.onGlass.withValues(alpha: 0.15),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.sun),
                        ),
                      ),
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FlatButton(
                            label: t.lbSave,
                            filled: true,
                            onTap: _save,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FlatButton(
                            label: t.lbSignOut,
                            filled: false,
                            onTap: _signOut,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (!cloudConfigured)
                  Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.lbDemoNotice,
                          style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.label, required this.busy, this.onTap});
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Google's own mark is a trademarked asset, so the button
                    // carries a neutral icon instead of a copied logo.
                    const Icon(
                      Icons.account_circle_outlined,
                      size: 20,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FlatButton extends StatelessWidget {
  const _FlatButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: filled ? Colors.white : null,
          borderRadius: BorderRadius.circular(13),
          border: filled
              ? null
              : Border.all(color: AppColors.onGlass.withValues(alpha: 0.22)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: filled ? Colors.black : AppColors.onGlass,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
