import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cloud_config.dart';

/// A signed-in Firebase user, as far as Nova needs to know one.
class FirebaseSession {
  const FirebaseSession({
    required this.uid,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    this.email,
  });

  /// Firebase's stable id for the person — the key of their data.
  final String uid;

  /// Short-lived (one hour) proof of identity, sent with every request.
  final String idToken;

  /// Long-lived, used only to get a fresh [idToken].
  final String refreshToken;
  final DateTime expiresAt;

  /// Shown to the signed-in person only, never to anyone else.
  final String? email;

  /// Renew a little early, so a request never carries a token that expires
  /// on the way.
  bool get needsRefresh =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 3)));

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'idToken': idToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        'email': email,
      };

  factory FirebaseSession.fromJson(Map<String, dynamic> json) => FirebaseSession(
        uid: json['uid'] as String,
        idToken: json['idToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        email: json['email'] as String?,
      );
}

/// Why a cloud call failed. [signedOut] means the session itself is gone —
/// revoked, the account disabled — and only a new sign-in helps.
class CloudException implements Exception {
  const CloudException(this.message, {this.signedOut = false});

  final String message;
  final bool signedOut;

  @override
  String toString() => 'CloudException: $message';
}

/// Firebase Authentication over its REST API — what the Firebase SDKs do
/// underneath, without needing them on platforms where they cannot run.
class FirebaseAuthApi {
  const FirebaseAuthApi();

  /// Exchanges a Google ID token for a Firebase session. The first exchange
  /// for a Google account creates the Firebase user — signing in and signing
  /// up are the same step.
  Future<FirebaseSession> signInWithGoogle(String googleIdToken) async {
    final resp = await http
        .post(
          Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:signInWithIdp',
              {'key': CloudConfig.apiKey}),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'postBody': 'id_token=$googleIdToken&providerId=google.com',
            // Required by the API, unused for an ID-token exchange.
            'requestUri': 'http://localhost',
            'returnSecureToken': true,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final json = _decode(resp);
    return FirebaseSession(
      uid: json['localId'] as String,
      idToken: json['idToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: _expiry(json['expiresIn']),
      email: json['email'] as String?,
    );
  }

  /// A fresh ID token for [session].
  Future<FirebaseSession> refresh(FirebaseSession session) async {
    final resp = await http.post(
      Uri.https('securetoken.googleapis.com', '/v1/token', {'key': CloudConfig.apiKey}),
      body: {'grant_type': 'refresh_token', 'refresh_token': session.refreshToken},
    ).timeout(const Duration(seconds: 20));
    final json = _decode(resp);
    return FirebaseSession(
      uid: json['user_id'] as String? ?? session.uid,
      idToken: json['id_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? session.refreshToken,
      expiresAt: _expiry(json['expires_in']),
      email: session.email,
    );
  }

  static DateTime _expiry(Object? seconds) =>
      DateTime.now().add(Duration(seconds: int.tryParse('$seconds') ?? 3600));

  static Map<String, dynamic> _decode(http.Response resp) {
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200) return json;
    final message = (json['error'] as Map<String, dynamic>?)?['message'] as String? ??
        'HTTP ${resp.statusCode}';
    // These mean the session is over, not that the network hiccupped.
    const gone = {'TOKEN_EXPIRED', 'USER_DISABLED', 'USER_NOT_FOUND', 'INVALID_REFRESH_TOKEN'};
    throw CloudException(message, signedOut: gone.any(message.startsWith));
  }
}
