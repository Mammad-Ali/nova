import '../domain/leaderboard_models.dart';

/// Signing in and out.
///
/// The interface exists so the screens never learn where accounts come from:
/// today a local stand-in, later Google sign-in backed by Firebase. Swapping
/// the implementation is meant to touch this folder only.
abstract class AuthRepository {
  /// The account restored at startup, if any.
  Future<NovaAccount?> restore();

  /// Starts the sign-in flow and returns the resulting account.
  Future<NovaAccount> signIn();

  Future<void> signOut();

  /// Changes the public nickname.
  Future<NovaAccount> updateNickname(NovaAccount account, String nickname);

  /// Records where the account measures from, learned from the IP lookup.
  Future<NovaAccount> updateOrigin(
    NovaAccount account, {
    String? country,
    String? provider,
  });
}

/// Reading the rankings and publishing your own result.
abstract class LeaderboardRepository {
  /// Best results for one slice, already ranked by [metric].
  ///
  /// [country] and [provider] describe the current user and are what the
  /// country and provider scopes filter on.
  Future<List<LeaderboardEntry>> top({
    required LeaderboardScope scope,
    required LeaderboardMetric metric,
    String? country,
    String? provider,
  });

  /// Publishes the user's personal best. Called after a completed test.
  Future<void> submit(LeaderboardEntry entry);
}
