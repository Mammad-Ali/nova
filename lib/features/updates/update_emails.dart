import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_session.dart';
import '../../core/cloud/firestore_client.dart';
import '../../core/l10n/locale_provider.dart';

/// Whether the signed-in person gets an email when a new version is out;
/// null when nobody is signed in.
///
/// Opting in leaves a document at subscribers/{uid} with the account's
/// address and the app's language. The release workflow reads them with its
/// own credentials (tool/send_update_emails.py); the security rules accept
/// only the signed-in account's own address, so nobody can sign up anyone
/// else. Opting out deletes the document.
final updateEmailsProvider =
    AsyncNotifierProvider<UpdateEmailsNotifier, bool?>(UpdateEmailsNotifier.new);

class UpdateEmailsNotifier extends AsyncNotifier<bool?> {
  @override
  Future<bool?> build() async {
    // The uid, not the whole session: tokens refresh every hour.
    final uid = ref.watch(cloudSessionProvider.select((s) => s?.uid));
    if (uid == null) return null;

    // Emails go out in the language the app is set to.
    ref.listen(localeProvider, (_, _) {
      if (state.value == true) _write(uid);
    });

    return await ref.read(firestoreProvider).get(_path(uid)) != null;
  }

  /// Turns the emails on or off. Throws when the change couldn't be saved;
  /// the switch then goes back to where it was.
  Future<void> setEnabled(bool on) async {
    final uid = ref.read(cloudSessionProvider)?.uid;
    if (uid == null) return;
    final before = state;
    state = AsyncData(on); // the switch moves at once
    try {
      if (on) {
        await _write(uid);
      } else {
        await ref.read(firestoreProvider).commit([
          {'delete': FirestoreClient.documentName(_path(uid))},
        ]);
      }
    } catch (_) {
      state = before;
      rethrow;
    }
  }

  Future<void> _write(String uid) async {
    final email = ref.read(cloudSessionProvider)?.email;
    if (email == null) return;
    await ref.read(firestoreProvider).set(_path(uid), {
      'email': email,
      'lang': ref.read(localeProvider).name,
      'since': DateTime.now(),
    });
  }

  static String _path(String uid) => 'subscribers/$uid';
}
