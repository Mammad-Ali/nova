import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../speedtest/data/datasources/ip_info.dart';
import '../../speedtest/domain/entities/speedtest_record.dart';
import '../../speedtest/presentation/providers/speedtest_history_provider.dart';
import '../data/demo_backend.dart';
import '../data/leaderboard_repository.dart';
import '../domain/leaderboard_models.dart';

/// Swapping these two lines for a Firebase-backed pair is the whole
/// migration: nothing above this file knows which backend is in use.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => DemoAuthRepository(),
);
final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (ref) => DemoLeaderboardRepository(),
);

/// The signed-in account, or null when nobody is signed in.
final accountProvider = NotifierProvider<AccountNotifier, NovaAccount?>(
  AccountNotifier.new,
);

class AccountNotifier extends Notifier<NovaAccount?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  NovaAccount? build() {
    Future.microtask(_restore);
    return null;
  }

  Future<void> _restore() async => state = await _repo.restore();

  Future<void> signIn() async => state = await _repo.signIn();

  Future<void> signOut() async {
    await _repo.signOut();
    state = null;
  }

  Future<void> setNickname(String nickname) async {
    final account = state;
    final trimmed = nickname.trim();
    if (account == null || trimmed.isEmpty) return;
    state = await _repo.updateNickname(account, trimmed);
  }

  /// Stores where this account measures from, so the country and provider
  /// filters have something to match on.
  Future<void> noteOrigin({String? country, String? provider}) async {
    final account = state;
    if (account == null) return;
    if (country == null && provider == null) return;
    if (account.country == country && account.provider == provider) return;
    state = await _repo.updateOrigin(
      account,
      country: country,
      provider: provider,
    );
  }
}

/// What the leaderboard sheet renders.
class LeaderboardState {
  const LeaderboardState({
    this.entries = const [],
    this.loading = true,
    this.scope = LeaderboardScope.world,
    this.metric = LeaderboardMetric.download,
  });

  final List<LeaderboardEntry> entries;
  final bool loading;
  final LeaderboardScope scope;
  final LeaderboardMetric metric;

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    bool? loading,
    LeaderboardScope? scope,
    LeaderboardMetric? metric,
  }) => LeaderboardState(
    entries: entries ?? this.entries,
    loading: loading ?? this.loading,
    scope: scope ?? this.scope,
    metric: metric ?? this.metric,
  );
}

final leaderboardProvider =
    NotifierProvider<LeaderboardNotifier, LeaderboardState>(
      LeaderboardNotifier.new,
    );

class LeaderboardNotifier extends Notifier<LeaderboardState> {
  LeaderboardRepository get _repo => ref.read(leaderboardRepositoryProvider);

  @override
  LeaderboardState build() {
    Future.microtask(refresh);
    return const LeaderboardState();
  }

  void setScope(LeaderboardScope scope) {
    if (scope == state.scope) return;
    state = state.copyWith(scope: scope, loading: true);
    refresh();
  }

  void setMetric(LeaderboardMetric metric) {
    if (metric == state.metric) return;
    state = state.copyWith(metric: metric, loading: true);
    refresh();
  }

  Future<void> refresh() async {
    // A signed-in user's own best result goes up first, so their row is in
    // the table they are about to look at.
    await _publishBest();

    // Where "my country" and "my provider" point is taken from the IP
    // lookup, so both filters work before the first test is published —
    // and for guests, who have no account to store them on.
    final account = ref.read(accountProvider);
    final info = await ref.read(ipInfoProvider.future);
    final entries = await _repo.top(
      scope: state.scope,
      metric: state.metric,
      country: info.country ?? account?.country,
      provider: info.isp ?? account?.provider,
    );
    state = state.copyWith(entries: entries, loading: false);
  }

  /// Sends the best stored test to the backend, tagged with the country and
  /// ISP from the IP lookup. Does nothing until somebody is signed in.
  Future<void> _publishBest() async {
    final account = ref.read(accountProvider);
    if (account == null) return;

    final history = ref.read(speedTestHistoryProvider);
    if (history.isEmpty) return;
    final best = history.reduce(
      (a, b) => b.downloadMbps > a.downloadMbps ? b : a,
    );

    final info = await ref.read(ipInfoProvider.future);
    final country = info.country ?? account.country;
    final provider = info.isp ?? account.provider;
    if (country == null || provider == null) return;

    await ref
        .read(accountProvider.notifier)
        .noteOrigin(country: country, provider: provider);

    await _repo.submit(_entryFor(account, best, country, provider));
  }

  LeaderboardEntry _entryFor(
    NovaAccount account,
    SpeedTestRecord best,
    String country,
    String provider,
  ) => LeaderboardEntry(
    id: account.id,
    nickname: account.nickname,
    country: country,
    provider: provider,
    downloadMbps: best.downloadMbps,
    uploadMbps: best.uploadMbps,
    pingMs: best.pingMs,
    measuredAt: best.timestamp,
    isMe: true,
  );
}
