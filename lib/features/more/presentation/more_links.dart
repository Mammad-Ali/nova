import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const kRepoUrl = 'https://github.com/Mammad-Ali/nova';
const kIssuesUrl = '$kRepoUrl/issues';
const kReleasesUrl = '$kRepoUrl/releases/latest';

/// Installers published with every release, under fixed names, so
/// `releases/latest/download/<file>` always serves the newest one.
enum DownloadTarget {
  windows('Windows', 'Nova-Windows-Setup.exe', Icons.desktop_windows_rounded),
  macos('macOS', 'Nova-macOS.dmg', Icons.laptop_mac_rounded),
  android('Android', 'Nova-Android.apk', Icons.android_rounded);

  const DownloadTarget(this.label, this.file, this.icon);

  final String label;
  final String file;
  final IconData icon;

  String get url => '$kRepoUrl/releases/latest/download/$file';
}

/// The installer for the system this page is viewed on, or null when Nova
/// has no build for it (iOS, Linux). On the web Flutter derives the platform
/// from the browser, so a visitor on a Mac gets the Mac download first.
DownloadTarget? visitorDownload() => switch (defaultTargetPlatform) {
      TargetPlatform.windows => DownloadTarget.windows,
      TargetPlatform.macOS => DownloadTarget.macos,
      TargetPlatform.android => DownloadTarget.android,
      _ => null,
    };

/// Opens a page in the browser — a new tab on the web.
Future<void> openLink(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Starts a download. On the web it stays in the same tab: the file is served
/// as an attachment, so the page itself does not change.
Future<void> startDownload(DownloadTarget target) => launchUrl(
      Uri.parse(target.url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    );

/// The running version, e.g. "1.2.0" — read from the build, so it can never
/// disagree with pubspec.yaml.
final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);
