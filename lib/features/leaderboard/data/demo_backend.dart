import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/leaderboard_models.dart';
import 'leaderboard_repository.dart';

/// Local stand-in for the real backend.
///
/// It keeps the account on this machine and serves a fixed cast of sample
/// people, so the screens can be built and judged before any cloud project
/// exists. Everything it returns is marked as demo data in the UI — no part
/// of this file talks to a network.
class DemoAuthRepository implements AuthRepository {
  static const _kId = 'nova_account_id';
  static const _kNick = 'nova_account_nickname';
  static const _kCountry = 'nova_account_country';
  static const _kProvider = 'nova_account_provider';

  @override
  Future<NovaAccount?> restore() async {
    final prefs = await _prefs();
    final id = prefs?.getString(_kId);
    if (id == null) return null;
    return NovaAccount(
      id: id,
      nickname: prefs?.getString(_kNick) ?? 'Nova',
      country: prefs?.getString(_kCountry),
      provider: prefs?.getString(_kProvider),
      demo: true,
    );
  }

  @override
  Future<NovaAccount> signIn() async {
    // A real sign-in hands back a stable user id from Google; here a random
    // one stands in for it.
    final id = 'demo-${Random().nextInt(0xFFFFFF).toRadixString(16)}';
    final account = NovaAccount(id: id, nickname: 'Nova', demo: true);
    final prefs = await _prefs();
    await prefs?.setString(_kId, id);
    await prefs?.setString(_kNick, account.nickname);
    return account;
  }

  @override
  Future<void> signOut() async {
    final prefs = await _prefs();
    for (final key in [_kId, _kNick, _kCountry, _kProvider]) {
      await prefs?.remove(key);
    }
  }

  @override
  Future<NovaAccount> updateNickname(NovaAccount account, String nickname) async {
    final prefs = await _prefs();
    await prefs?.setString(_kNick, nickname);
    return account.copyWith(nickname: nickname);
  }

  @override
  Future<NovaAccount> updateOrigin(NovaAccount account, {String? country, String? provider}) async {
    final prefs = await _prefs();
    if (country != null) await prefs?.setString(_kCountry, country);
    if (provider != null) await prefs?.setString(_kProvider, provider);
    return account.copyWith(country: country, provider: provider);
  }

  /// Preferences are wrapped because a missing plugin registration must not
  /// take the app down — the same guard the rest of the app uses.
  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }
}

/// Serves sample rankings and remembers the user's own published result.
class DemoLeaderboardRepository implements LeaderboardRepository {
  static const _kMine = 'nova_leaderboard_mine';

  LeaderboardEntry? _mine;

  @override
  Future<List<LeaderboardEntry>> top({
    required LeaderboardScope scope,
    required LeaderboardMetric metric,
    String? country,
    String? provider,
  }) async {
    _mine ??= await _loadMine();

    final all = <LeaderboardEntry>[..._sample, if (_mine != null) _mine!.copyWith(isMe: true)];

    final filtered = all.where((e) {
      return switch (scope) {
        LeaderboardScope.world => true,
        LeaderboardScope.country =>
          country != null && e.country.toLowerCase() == country.toLowerCase(),
        LeaderboardScope.provider =>
          provider != null && e.provider.toLowerCase() == provider.toLowerCase(),
      };
    }).toList();

    // Lower is better for ping; higher is better for the two speeds.
    filtered.sort(
      (a, b) => metric == LeaderboardMetric.ping
          ? a.valueFor(metric).compareTo(b.valueFor(metric))
          : b.valueFor(metric).compareTo(a.valueFor(metric)),
    );
    return filtered;
  }

  @override
  Future<void> submit(LeaderboardEntry entry) async {
    _mine = entry;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kMine,
        jsonEncode({
          'id': entry.id,
          'nickname': entry.nickname,
          'country': entry.country,
          'provider': entry.provider,
          'd': entry.downloadMbps,
          'u': entry.uploadMbps,
          'p': entry.pingMs,
          't': entry.measuredAt.toIso8601String(),
        }),
      );
    } catch (_) {
      // Staying in memory for this session is good enough for the stand-in.
    }
  }

  Future<LeaderboardEntry?> _loadMine() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kMine);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return LeaderboardEntry(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        country: json['country'] as String,
        provider: json['provider'] as String,
        downloadMbps: (json['d'] as num).toDouble(),
        uploadMbps: (json['u'] as num).toDouble(),
        pingMs: (json['p'] as num).toDouble(),
        measuredAt: DateTime.parse(json['t'] as String),
        isMe: true,
      );
    } catch (_) {
      return null;
    }
  }
}

DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days, hours: days * 3 % 20));

/// Sample people. Speeds follow what these markets actually deliver, so the
/// table looks believable while the real backend is still missing.
final List<LeaderboardEntry> _sample = [
  LeaderboardEntry(
    id: 's1',
    nickname: 'hikari',
    country: 'Japan',
    provider: 'NTT Communications',
    downloadMbps: 921.4,
    uploadMbps: 880.2,
    pingMs: 4.8,
    measuredAt: _daysAgo(1),
  ),
  LeaderboardEntry(
    id: 's2',
    nickname: 'fiberfox',
    country: 'Japan',
    provider: 'KDDI',
    downloadMbps: 742.0,
    uploadMbps: 690.5,
    pingMs: 6.1,
    measuredAt: _daysAgo(2),
  ),
  LeaderboardEntry(
    id: 's3',
    nickname: 'berlinbyte',
    country: 'Germany',
    provider: 'Deutsche Telekom',
    downloadMbps: 612.7,
    uploadMbps: 210.4,
    pingMs: 9.3,
    measuredAt: _daysAgo(1),
  ),
  LeaderboardEntry(
    id: 's4',
    nickname: 'rheinstream',
    country: 'Germany',
    provider: 'Vodafone DE',
    downloadMbps: 486.9,
    uploadMbps: 48.7,
    pingMs: 14.2,
    measuredAt: _daysAgo(4),
  ),
  LeaderboardEntry(
    id: 's5',
    nickname: 'quietrouter',
    country: 'United States',
    provider: 'Verizon Fios',
    downloadMbps: 588.3,
    uploadMbps: 512.9,
    pingMs: 11.0,
    measuredAt: _daysAgo(3),
  ),
  LeaderboardEntry(
    id: 's6',
    nickname: 'coax_kid',
    country: 'United States',
    provider: 'Comcast',
    downloadMbps: 402.1,
    uploadMbps: 22.6,
    pingMs: 18.7,
    measuredAt: _daysAgo(5),
  ),
  LeaderboardEntry(
    id: 's7',
    nickname: 'bosphorus',
    country: 'Turkey',
    provider: 'Türk Telekom',
    downloadMbps: 198.4,
    uploadMbps: 38.2,
    pingMs: 21.5,
    measuredAt: _daysAgo(2),
  ),
  LeaderboardEntry(
    id: 's8',
    nickname: 'kadikoy',
    country: 'Turkey',
    provider: 'Turkcell',
    downloadMbps: 154.6,
    uploadMbps: 30.9,
    pingMs: 24.8,
    measuredAt: _daysAgo(6),
  ),
  LeaderboardEntry(
    id: 's9',
    nickname: 'nevaline',
    country: 'Russia',
    provider: 'Rostelecom',
    downloadMbps: 287.2,
    uploadMbps: 96.4,
    pingMs: 16.4,
    measuredAt: _daysAgo(3),
  ),
  LeaderboardEntry(
    id: 's10',
    nickname: 'uraltech',
    country: 'Russia',
    provider: 'MTS',
    downloadMbps: 176.8,
    uploadMbps: 74.1,
    pingMs: 22.9,
    measuredAt: _daysAgo(7),
  ),
  LeaderboardEntry(
    id: 's11',
    nickname: 'kaspi',
    country: 'Azerbaijan',
    provider: 'Aztelekom LLC',
    downloadMbps: 118.9,
    uploadMbps: 94.3,
    pingMs: 26.1,
    measuredAt: _daysAgo(1),
  ),
  LeaderboardEntry(
    id: 's12',
    nickname: 'icherisheher',
    country: 'Azerbaijan',
    provider: 'Aztelekom LLC',
    downloadMbps: 87.5,
    uploadMbps: 71.2,
    pingMs: 29.4,
    measuredAt: _daysAgo(2),
  ),
  LeaderboardEntry(
    id: 's13',
    nickname: 'khazar',
    country: 'Azerbaijan',
    provider: 'Bakcell',
    downloadMbps: 64.2,
    uploadMbps: 41.8,
    pingMs: 34.7,
    measuredAt: _daysAgo(4),
  ),
  LeaderboardEntry(
    id: 's14',
    nickname: 'nizami',
    country: 'Azerbaijan',
    provider: 'Azerfon (Nar)',
    downloadMbps: 52.7,
    uploadMbps: 28.3,
    pingMs: 41.2,
    measuredAt: _daysAgo(8),
  ),
  LeaderboardEntry(
    id: 's15',
    nickname: 'gunesh',
    country: 'Azerbaijan',
    provider: 'Delta Telecom',
    downloadMbps: 96.1,
    uploadMbps: 63.5,
    pingMs: 27.8,
    measuredAt: _daysAgo(5),
  ),
  LeaderboardEntry(
    id: 's16',
    nickname: 'mtatsminda',
    country: 'Georgia',
    provider: 'Magticom',
    downloadMbps: 143.5,
    uploadMbps: 88.9,
    pingMs: 19.6,
    measuredAt: _daysAgo(3),
  ),
  LeaderboardEntry(
    id: 's17',
    nickname: 'silkroad',
    country: 'Georgia',
    provider: 'Silknet',
    downloadMbps: 108.7,
    uploadMbps: 52.4,
    pingMs: 23.1,
    measuredAt: _daysAgo(9),
  ),
  LeaderboardEntry(
    id: 's18',
    nickname: 'dunes',
    country: 'UAE',
    provider: 'Etisalat',
    downloadMbps: 331.9,
    uploadMbps: 128.6,
    pingMs: 13.5,
    measuredAt: _daysAgo(2),
  ),
  LeaderboardEntry(
    id: 's19',
    nickname: 'marina',
    country: 'UAE',
    provider: 'du',
    downloadMbps: 254.3,
    uploadMbps: 102.7,
    pingMs: 15.9,
    measuredAt: _daysAgo(6),
  ),
  LeaderboardEntry(
    id: 's20',
    nickname: 'thamesflow',
    country: 'United Kingdom',
    provider: 'BT',
    downloadMbps: 372.8,
    uploadMbps: 74.9,
    pingMs: 12.4,
    measuredAt: _daysAgo(4),
  ),
  LeaderboardEntry(
    id: 's21',
    nickname: 'seine',
    country: 'France',
    provider: 'Orange',
    downloadMbps: 519.6,
    uploadMbps: 428.1,
    pingMs: 8.7,
    measuredAt: _daysAgo(1),
  ),
  LeaderboardEntry(
    id: 's22',
    nickname: 'tundra',
    country: 'Sweden',
    provider: 'Telia',
    downloadMbps: 664.2,
    uploadMbps: 601.3,
    pingMs: 7.2,
    measuredAt: _daysAgo(5),
  ),
];
