/// Which slice of the leaderboard is being shown.
enum LeaderboardScope {
  /// Everyone, everywhere.
  world,

  /// Only people whose IP resolves to the same country.
  country,

  /// Only people on the same ISP — the fairest comparison there is, since
  /// it removes the country and the technology from the equation.
  provider,
}

/// Which column the table is ranked by.
enum LeaderboardMetric { download, upload, ping }

/// One row: somebody's best result.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.id,
    required this.nickname,
    required this.country,
    required this.provider,
    required this.downloadMbps,
    required this.uploadMbps,
    required this.pingMs,
    required this.measuredAt,
    this.isMe = false,
  });

  final String id;
  final String nickname;
  final String country;
  final String provider;
  final double downloadMbps;
  final double uploadMbps;
  final double pingMs;
  final DateTime measuredAt;

  /// Marks the signed-in user's own row, so it can be highlighted.
  final bool isMe;

  double valueFor(LeaderboardMetric metric) => switch (metric) {
        LeaderboardMetric.download => downloadMbps,
        LeaderboardMetric.upload => uploadMbps,
        LeaderboardMetric.ping => pingMs,
      };

  LeaderboardEntry copyWith({bool? isMe}) => LeaderboardEntry(
        id: id,
        nickname: nickname,
        country: country,
        provider: provider,
        downloadMbps: downloadMbps,
        uploadMbps: uploadMbps,
        pingMs: pingMs,
        measuredAt: measuredAt,
        isMe: isMe ?? this.isMe,
      );
}

/// The signed-in user.
///
/// The nickname is what other people see; the real name and the e-mail from
/// the Google account are deliberately never part of this object, so they
/// cannot leak into the leaderboard by accident.
class NovaAccount {
  const NovaAccount({
    required this.id,
    required this.nickname,
    this.country,
    this.provider,
    this.demo = false,
  });

  final String id;
  final String nickname;

  /// Filled in from the IP lookup once a test has run.
  final String? country;
  final String? provider;

  /// True while the app runs against the local stand-in backend rather than
  /// a real signed-in Google account.
  final bool demo;

  NovaAccount copyWith({String? nickname, String? country, String? provider}) =>
      NovaAccount(
        id: id,
        nickname: nickname ?? this.nickname,
        country: country ?? this.country,
        provider: provider ?? this.provider,
        demo: demo,
      );
}
