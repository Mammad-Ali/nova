import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_auth_api.dart';
import 'firestore_client.dart';
import 'google_identity.dart';

/// The signed-in Firebase session, or null. Everything that talks to the
/// cloud goes through here for its token.
final cloudSessionProvider =
    NotifierProvider<CloudSessionNotifier, FirebaseSession?>(CloudSessionNotifier.new);

/// A Firestore client that signs every request as the current user, and
/// sends unsigned ones — public reads — when nobody is signed in.
final firestoreProvider = Provider<FirestoreClient>((ref) => FirestoreClient(() async {
      final session = ref.read(cloudSessionProvider.notifier);
      return ref.read(cloudSessionProvider) == null ? null : session.idToken();
    }));

class CloudSessionNotifier extends Notifier<FirebaseSession?> {
  static const _key = 'nova_cloud_session';
  final _api = const FirebaseAuthApi();

  Future<FirebaseSession?>? _restoring;
  Future<FirebaseSession>? _refreshing;

  @override
  FirebaseSession? build() => null;

  /// Brings back the session saved on this device, or finishes a sign-in the
  /// website left for. Runs once; later calls get the same result.
  Future<FirebaseSession?> restore() => _restoring ??= _restore();

  Future<FirebaseSession?> _restore() async {
    try {
      final redirected = await takeRedirectedGoogleIdToken();
      if (redirected != null) return await _finish(redirected);
    } catch (_) {
      // A failed or cancelled return from Google: carry on signed out.
    }

    final saved = await _load();
    if (saved == null) return null;
    state = saved;
    try {
      await idToken(); // renew now if it went stale while the app was closed
    } on CloudException catch (e) {
      if (e.signedOut) await signOut();
    } catch (_) {
      // Offline: keep the session, the next request will try again.
    }
    return state;
  }

  /// Signs in with Google — or signs up: the first sign-in creates the
  /// Firebase user. [doneText] is what the browser tab shows afterwards on
  /// desktop.
  Future<FirebaseSession> signIn({required String doneText}) async {
    final google = await obtainGoogleIdToken(doneText: doneText);
    return _finish(google);
  }

  Future<FirebaseSession> _finish(String googleIdToken) async {
    final session = await _api.signInWithGoogle(googleIdToken);
    state = session;
    await _save(session);
    return session;
  }

  Future<void> signOut() async {
    state = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
    try {
      await forgetGoogleAccount();
    } catch (_) {}
  }

  /// A valid ID token for the current user, renewed when about to expire.
  /// Concurrent callers share one renewal.
  Future<String> idToken() async {
    final session = state;
    if (session == null) throw const CloudException('not signed in', signedOut: true);
    if (!session.needsRefresh) return session.idToken;
    try {
      final fresh = await (_refreshing ??= _api.refresh(session));
      state = fresh;
      await _save(fresh);
      return fresh.idToken;
    } on CloudException catch (e) {
      if (e.signedOut) await signOut();
      rethrow;
    } finally {
      _refreshing = null;
    }
  }

  /// Kept in the app's private preferences: the macOS sandbox container,
  /// Android's app storage, the browser's storage for this site. The
  /// system keychain would need entitlements an ad-hoc signed Mac app
  /// cannot carry.
  Future<void> _save(FirebaseSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(session.toJson()));
    } catch (_) {}
  }

  Future<FirebaseSession?> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return FirebaseSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
