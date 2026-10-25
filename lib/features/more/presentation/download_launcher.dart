/// Starting an installer download.
///
/// The app hands the link to the system browser. A web page must not use
/// `window.open` for this: with the `noopener` feature, which url_launcher
/// always passes, Safari ignores a `_self` target, tries to open a new
/// window, and its pop-up blocker silently drops it. Navigating the current
/// tab never counts as a pop-up, and since the server sends the installer as
/// an attachment, the browser downloads it and the page stays where it is.
library;

export 'download_launcher_io.dart'
    if (dart.library.js_interop) 'download_launcher_web.dart';
