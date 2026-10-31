import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/cloud/cloud_session.dart';
import '../../../core/cloud/firebase_auth_api.dart';
import '../../../core/cloud/firestore_client.dart';
import '../../../core/l10n/locale_provider.dart';
import '../domain/leaderboard_models.dart';
import 'leaderboard_repository.dart';

/// Accounts backed by Google sign-in and Firebase.
///
/// The public profile — nickname, country, provider — lives in Firestore at
/// `users/{uid}`, readable only by its owner; the leaderboard copies what it
/// needs. The Google name and e-mail are never written anywhere.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._ref);

  final Ref _ref;
  static const _cacheKey = 'nova_cloud_profile';

  CloudSessionNotifier get _session => _ref.read(cloudSessionProvider.notifier);
  FirestoreClient get _db => _ref.read(firestoreProvider);

  @override
  Future<NovaAccount?> restore() async {
    final session = await _session.restore();
    if (session == null) return null;
    return _profile(session.uid);
  }

  @override
  Future<NovaAccount> signIn() async {
    final session = await _session.signIn(
      doneText: _ref.read(stringsProvider).signInBrowserDone,
    );
    return _profile(session.uid);
  }

  @override
  Future<void> signOut() async {
    await _session.signOut();
    await _clearCache();
  }

  @override
  Future<NovaAccount> updateNickname(NovaAccount account, String nickname) =>
      _save(account.copyWith(nickname: nickname));

  @override
  Future<NovaAccount> updateOrigin(
    NovaAccount account, {
    String? country,
    String? provider,
  }) =>
      _save(account.copyWith(country: country, provider: provider));

  /// The profile stored for [uid] — created on first sign-in with a neutral
  /// nickname, so nothing personal is public until the person picks one.
  /// Offline, the copy cached on this device stands in.
  Future<NovaAccount> _profile(String uid) async {
    try {
      final doc = await _db.get('users/$uid');
      if (doc == null) {
        return await _save(NovaAccount(id: uid, nickname: defaultNickname(uid)));
      }
      final account = NovaAccount(
        id: uid,
        nickname: doc.data['nickname'] as String? ?? defaultNickname(uid),
        country: _blankToNull(doc.data['country']),
        provider: _blankToNull(doc.data['provider']),
      );
      await _cache(account);
      return account;
    } on CloudException catch (e) {
      if (e.signedOut) rethrow;
      return await _cached(uid) ?? NovaAccount(id: uid, nickname: defaultNickname(uid));
    } catch (_) {
      return await _cached(uid) ?? NovaAccount(id: uid, nickname: defaultNickname(uid));
    }
  }

  Future<NovaAccount> _save(NovaAccount account) async {
    await _db.set('users/${account.id}', {
      'nickname': clip(account.nickname, 20),
      'country': clip(account.country ?? '', 80),
      'provider': clip(account.provider ?? '', 120),
      'updated': DateTime.now(),
    });
    await _cache(account);
    return account;
  }

  Future<void> _cache(NovaAccount a) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode({
        'id': a.id,
        'nickname': a.nickname,
        'country': a.country,
        'provider': a.provider,
      }));
    } catch (_) {}
  }

  Future<NovaAccount?> _cached(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['id'] != uid) return null;
      return NovaAccount(
        id: uid,
        nickname: json['nickname'] as String,
        country: json['country'] as String?,
        provider: json['provider'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }

  static String? _blankToNull(Object? v) => v is String && v.isNotEmpty ? v : null;
}

/// Cuts [text] to [max] characters — the lengths the database rules accept.
/// A provider's name from the IP lookup can be long; it is better shortened
/// than rejected.
String clip(String text, int max) => text.length <= max ? text : text.substring(0, max);

/// "Nova-7F3K": stable for the account, and says nothing about the person.
String defaultNickname(String uid) {
  final letters = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  return 'Nova-${letters.length >= 4 ? letters.substring(0, 4) : letters}';
}

/// The public leaderboard in Firestore: one document per person, at
/// `leaderboard/{uid}`, holding their best result. Anyone may read it; only
/// the owner may write their own entry, and the rules check every value.
class FirestoreLeaderboardRepository implements LeaderboardRepository {
  FirestoreLeaderboardRepository(this._ref);

  final Ref _ref;
  FirestoreClient get _db => _ref.read(firestoreProvider);

  static String _field(LeaderboardMetric m) => switch (m) {
        LeaderboardMetric.download => 'd',
        LeaderboardMetric.upload => 'u',
        LeaderboardMetric.ping => 'p',
      };

  @override
  Future<List<LeaderboardEntry>> top({
    required LeaderboardScope scope,
    required LeaderboardMetric metric,
    String? country,
    String? provider,
  }) async {
    final me = _ref.read(cloudSessionProvider)?.uid;
    final List<FirestoreDoc> docs;
    try {
      docs = switch (scope) {
        // Ordering on one field needs no hand-made index.
        LeaderboardScope.world => await _db.query('leaderboard',
            orderBy: _field(metric),
            descending: metric != LeaderboardMetric.ping,
            limit: 100),
        // Filtering and ordering on two fields would; filter here, sort below.
        LeaderboardScope.country => country == null
            ? const []
            : await _db.query('leaderboard', whereField: 'country', equals: country, limit: 500),
        LeaderboardScope.provider => provider == null
            ? const []
            : await _db.query('leaderboard', whereField: 'provider', equals: provider, limit: 500),
      };
    } catch (_) {
      return const [];
    }

    final entries = [for (final d in docs) entryFromDoc(d, me: me)];
    entries.sort((a, b) => metric == LeaderboardMetric.ping
        ? a.valueFor(metric).compareTo(b.valueFor(metric))
        : b.valueFor(metric).compareTo(a.valueFor(metric)));
    return entries;
  }

  /// Publishes [entry] unless the board already holds a faster result for
  /// this person — a history trimmed on one device must not lower the record
  /// set on another. Nickname, country and provider always follow the latest.
  @override
  Future<void> submit(LeaderboardEntry entry) async {
    final path = 'leaderboard/${entry.id}';
    final existing = await _db.get(path);
    final keepOld = existing != null && asDouble(existing.data['d']) > entry.downloadMbps;
    await _db.set(path, {
      'nickname': clip(entry.nickname, 20),
      'country': clip(entry.country, 80),
      'provider': clip(entry.provider, 120),
      'd': keepOld ? asDouble(existing.data['d']) : entry.downloadMbps,
      'u': keepOld ? asDouble(existing.data['u']) : entry.uploadMbps,
      'p': keepOld ? asDouble(existing.data['p']) : entry.pingMs,
      't': keepOld ? existing.data['t'] as DateTime : entry.measuredAt,
    });
  }
}

LeaderboardEntry entryFromDoc(FirestoreDoc doc, {String? me}) => LeaderboardEntry(
      id: doc.id,
      nickname: doc.data['nickname'] as String? ?? '?',
      country: doc.data['country'] as String? ?? '',
      provider: doc.data['provider'] as String? ?? '',
      downloadMbps: asDouble(doc.data['d']),
      uploadMbps: asDouble(doc.data['u']),
      pingMs: asDouble(doc.data['p']),
      measuredAt: doc.data['t'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0),
      isMe: doc.id == me,
    );
