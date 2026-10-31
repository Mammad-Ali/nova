/// Where Nova's cloud lives: one Firebase project, reached over its REST APIs.
///
/// None of these values is in the repository. They come from a JSON file
/// passed at build time — `flutter run --dart-define-from-file=nova_cloud.json`
/// locally, a repository secret in CI — for two reasons: GitHub blocks
/// pushes that contain Google keys, and a fork should build without anyone's
/// project. A build without them simply keeps the local demo account and
/// sample leaderboard.
class CloudConfig {
  const CloudConfig._();

  static const apiKey = String.fromEnvironment('NOVA_FIREBASE_API_KEY');
  static const projectId = String.fromEnvironment('NOVA_FIREBASE_PROJECT_ID');

  /// The "Web client" Firebase creates for Google sign-in. The website signs
  /// in with it, and Android names it as the audience of its ID tokens.
  static const webClientId = String.fromEnvironment('NOVA_GOOGLE_WEB_CLIENT_ID');

  /// A "Desktop app" OAuth client, for the browser-based sign-in on macOS and
  /// Windows. Google treats an installed app's secret as not confidential —
  /// it ships inside every copy — but it stays out of the repository all the
  /// same.
  static const desktopClientId =
      String.fromEnvironment('NOVA_GOOGLE_DESKTOP_CLIENT_ID');
  static const desktopClientSecret =
      String.fromEnvironment('NOVA_GOOGLE_DESKTOP_CLIENT_SECRET');
}

/// True when this build was given a Firebase project to talk to.
const bool cloudConfigured =
    CloudConfig.apiKey != '' && CloudConfig.projectId != '';
