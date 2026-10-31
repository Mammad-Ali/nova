import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Thrown when signing in did not produce a token.
class GoogleSignInFailed implements Exception {
  const GoogleSignInFailed(this.reason, {this.cancelled = false});

  final String reason;

  /// The person closed the sign-in page or chose not to continue — not an
  /// error worth showing.
  final bool cancelled;

  @override
  String toString() => 'Google sign-in failed: $reason';
}

/// The claims inside a JWT, unverified. Used only to check the nonce we sent
/// ourselves; the signature is verified by Firebase when the token is used.
Map<String, dynamic> jwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return const {};
  try {
    final json = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    return jsonDecode(json) as Map<String, dynamic>;
  } catch (_) {
    return const {};
  }
}

/// A random, URL-safe string from a cryptographically secure source.
String randomUrlToken([int bytes = 32]) {
  final rnd = Random.secure();
  final data = List<int>.generate(bytes, (_) => rnd.nextInt(256));
  return base64Url.encode(data).replaceAll('=', '');
}

/// The PKCE code challenge for [verifier] (RFC 7636, method S256): Google
/// later checks that whoever redeems the code knows the verifier.
String pkceChallenge(String verifier) =>
    base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
