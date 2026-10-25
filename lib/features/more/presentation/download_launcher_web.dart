import 'package:web/web.dart' as web;

/// Same-tab navigation to the installer: the response is an attachment, so
/// the browser saves it and the page does not change.
Future<void> openDownload(String url) async => web.window.location.assign(url);
