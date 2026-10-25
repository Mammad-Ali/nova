import 'package:url_launcher/url_launcher.dart';

/// The system browser downloads the file.
Future<void> openDownload(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
