import 'dart:async';

import 'package:web/web.dart' as web;

import 'cloud_config.dart';
import 'google_identity_types.dart';

const _stateKey = 'nova_oauth_state';
const _nonceKey = 'nova_oauth_nonce';

/// What Google appended to the address when it sent the visitor back.
Map<String, String>? _redirect;

/// Takes Google's reply out of the address bar before the app starts.
///
/// Called first thing in main(): Flutter would otherwise read the fragment
/// as a route, and the token must not linger in the address or the history.
void captureGoogleRedirect() {
  final hash = web.window.location.hash;
  if (hash.length < 2) return;
  final params = Uri.splitQueryString(hash.substring(1));
  if (!params.containsKey('id_token') && !params.containsKey('error')) return;
  _redirect = params;
  final clean = web.window.location.pathname + web.window.location.search;
  web.window.history.replaceState(null, '', clean);
}

/// The ID token Google sent back, checked against the state and nonce saved
/// before leaving. Null when this page load is not a sign-in return.
Future<String?> takeRedirectedGoogleIdToken() async {
  final params = _redirect;
  _redirect = null;
  if (params == null) return null;

  final storage = web.window.localStorage;
  final state = storage.getItem(_stateKey);
  final nonce = storage.getItem(_nonceKey);
  storage.removeItem(_stateKey);
  storage.removeItem(_nonceKey);

  final error = params['error'];
  if (error != null) {
    throw GoogleSignInFailed(error, cancelled: error == 'access_denied');
  }
  if (state == null || params['state'] != state) {
    throw const GoogleSignInFailed('the reply did not match the request');
  }
  final token = params['id_token']!;
  if (nonce == null || jwtPayload(token)['nonce'] != nonce) {
    throw const GoogleSignInFailed('the token was not issued for this request');
  }
  return token;
}

/// Leaves for Google's sign-in page. The returned future never completes:
/// the page unloads, and the sign-in finishes on the next load through
/// [takeRedirectedGoogleIdToken].
Future<String> obtainGoogleIdToken({required String doneText}) async {
  if (CloudConfig.webClientId.isEmpty) {
    throw const GoogleSignInFailed('web sign-in is not configured');
  }
  final state = randomUrlToken(16);
  final nonce = randomUrlToken(16);
  web.window.localStorage
    ..setItem(_stateKey, state)
    ..setItem(_nonceKey, nonce);

  final here = web.window.location;
  final consent = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': CloudConfig.webClientId,
    'redirect_uri': '${here.origin}${here.pathname}',
    'response_type': 'id_token',
    'scope': 'openid email profile',
    'nonce': nonce,
    'state': state,
    'prompt': 'select_account',
  });
  web.window.location.assign(consent.toString());
  return Completer<String>().future;
}

Future<void> forgetGoogleAccount() async {}
