/// Getting a Google ID token — the proof of who someone is that Firebase
/// accepts — in the way each platform allows:
///
///  * macOS and Windows: the system browser shows Google's sign-in page, and
///    the answer comes back to a short-lived server on 127.0.0.1 (the OAuth
///    "loopback" flow, with PKCE). Google's native SDKs for desktop need a
///    paid Apple developer account on macOS and do not exist for Windows.
///  * Android: Google's own sign-in sheet, through google_sign_in.
///  * Web: a redirect to Google and back, with the token in the URL fragment.
library;

export 'google_identity_io.dart'
    if (dart.library.js_interop) 'google_identity_web.dart';
export 'google_identity_types.dart';
