import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'cloud_config.dart';
import 'google_identity_types.dart';

/// Native platforms finish signing in within one call; nothing waits in the
/// address bar.
void captureGoogleRedirect() {}

Future<String?> takeRedirectedGoogleIdToken() async => null;

/// Signs in with Google and returns an ID token. [doneText] is shown in the
/// browser tab once a desktop sign-in has finished.
Future<String> obtainGoogleIdToken({required String doneText}) =>
    Platform.isAndroid ? _android() : _desktop(doneText);

/// Lets the next sign-in offer the account chooser again.
Future<void> forgetGoogleAccount() async {
  if (Platform.isAndroid && _androidReady) {
    await GoogleSignIn.instance.signOut();
  }
}

// ───────────────────────────── Android ─────────────────────────────

var _androidReady = false;

Future<String> _android() async {
  final google = GoogleSignIn.instance;
  if (!_androidReady) {
    // The web client is named as the token's audience: that is the client
    // Firebase checks the token against.
    await google.initialize(serverClientId: CloudConfig.webClientId);
    _androidReady = true;
  }
  try {
    final account = await google.authenticate();
    final token = account.authentication.idToken;
    if (token == null) throw const GoogleSignInFailed('no ID token returned');
    return token;
  } on GoogleSignInException catch (e) {
    throw GoogleSignInFailed(
      e.description ?? e.code.name,
      cancelled: e.code == GoogleSignInExceptionCode.canceled,
    );
  }
}

// ───────────────────────────── desktop ─────────────────────────────

/// The OAuth loopback flow for installed apps
/// (https://developers.google.com/identity/protocols/oauth2/native-app):
/// open Google's page in the default browser, receive the authorisation
/// code on 127.0.0.1, then trade it for tokens. PKCE ties the code to this
/// app instance, so an intercepted code is useless to anyone else.
Future<String> _desktop(String doneText) async {
  if (CloudConfig.desktopClientId.isEmpty) {
    throw const GoogleSignInFailed('desktop sign-in is not configured');
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  try {
    final redirectUri = 'http://127.0.0.1:${server.port}';
    final verifier = randomUrlToken(48);
    final challenge = pkceChallenge(verifier);
    final state = randomUrlToken(16);

    final consent = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': CloudConfig.desktopClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
      'prompt': 'select_account',
    });
    if (!await launchUrl(consent, mode: LaunchMode.externalApplication)) {
      throw const GoogleSignInFailed('could not open the browser');
    }

    final reply = await _awaitRedirect(server, doneText).timeout(
      const Duration(minutes: 5),
      onTimeout: () => throw const GoogleSignInFailed('timed out', cancelled: true),
    );
    if (reply['state'] != state) {
      throw const GoogleSignInFailed('the reply did not match the request');
    }
    final error = reply['error'];
    if (error != null) {
      throw GoogleSignInFailed(error, cancelled: error == 'access_denied');
    }
    final code = reply['code'];
    if (code == null) throw const GoogleSignInFailed('no authorisation code');

    final resp = await http.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      body: {
        'code': code,
        'client_id': CloudConfig.desktopClientId,
        'client_secret': CloudConfig.desktopClientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': verifier,
      },
    ).timeout(const Duration(seconds: 20));
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final idToken = json['id_token'] as String?;
    if (resp.statusCode != 200 || idToken == null) {
      throw GoogleSignInFailed('token exchange failed: ${json['error'] ?? resp.statusCode}');
    }
    return idToken;
  } finally {
    await server.close(force: true);
  }
}

/// Waits for Google's redirect and answers it with a page that tells the
/// person to go back to Nova. Other requests — the browser's favicon probe —
/// get a 404 and are ignored.
Future<Map<String, String>> _awaitRedirect(HttpServer server, String doneText) async {
  await for (final request in server) {
    final query = request.uri.queryParameters;
    if (!query.containsKey('code') && !query.containsKey('error')) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(_donePage(doneText));
    await request.response.close();
    return query;
  }
  throw const GoogleSignInFailed('the sign-in page closed', cancelled: true);
}

String _donePage(String text) => '''<!doctype html>
<html><head><meta charset="utf-8"><title>Nova</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  html, body { margin: 0; height: 100%; background: #000; color: #f5f6fa;
    font: 17px -apple-system, "Segoe UI", Roboto, sans-serif; }
  main { height: 100%; display: flex; flex-direction: column;
    align-items: center; justify-content: center; gap: 12px; padding: 24px;
    box-sizing: border-box; text-align: center; }
  h1 { margin: 0; color: #ffc61a; font-size: 34px; }
</style></head>
<body><main><h1>Nova</h1><p>${const HtmlEscape().convert(text)}</p></main></body></html>''';
