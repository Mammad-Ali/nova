import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'browser_connection.dart';

/// Reads navigator.connection, or null where the browser has none.
BrowserConnection? readBrowserConnection() {
  try {
    final navigator = web.window.navigator as JSObject;
    if (!navigator.has('connection')) return null;
    final connection = navigator.getProperty<JSObject?>('connection'.toJS);
    if (connection == null) return null;
    String? text(String key) => connection.has(key) ? connection.getProperty<JSString?>(key.toJS)?.toDart : null;
    num? number(String key) => connection.has(key) ? connection.getProperty<JSNumber?>(key.toJS)?.toDartDouble : null;
    return BrowserConnection(
      type: text('type'),
      effectiveType: text('effectiveType'),
      downlinkMbps: number('downlink')?.toDouble(),
      rttMs: number('rtt')?.round(),
      saveData: connection.has('saveData') && (connection.getProperty<JSBoolean?>('saveData'.toJS)?.toDart ?? false),
    );
  } catch (_) {
    return null;
  }
}
