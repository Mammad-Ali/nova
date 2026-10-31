import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cloud_config.dart';
import 'firebase_auth_api.dart';

/// One document: its id (the last part of its path) and its fields.
class FirestoreDoc {
  const FirestoreDoc(this.id, this.data);

  final String id;
  final Map<String, Object?> data;
}

/// Cloud Firestore over its REST API, signed with the user's Firebase token
/// so the database's security rules see who is asking.
class FirestoreClient {
  FirestoreClient(this._idToken);

  /// Supplies a valid Firebase ID token, refreshing it when needed — or null
  /// when nobody is signed in, for reads the rules leave public.
  final Future<String?> Function() _idToken;

  static String get _database =>
      'projects/${CloudConfig.projectId}/databases/(default)';
  static String get _documents => '$_database/documents';

  /// Full resource name of a document, as batch writes need it.
  static String documentName(String path) => '$_documents/$path';

  Uri _url(String suffix, [Map<String, String>? query]) => Uri.parse(
      'https://firestore.googleapis.com/v1/$suffix')
      .replace(queryParameters: query);

  Future<Map<String, String>> _headers() async {
    final token = await _idToken();
    return {
      'Authorization': ?(token == null ? null : 'Bearer $token'),
      'Content-Type': 'application/json',
    };
  }

  /// The document at [path], or null if it does not exist.
  Future<FirestoreDoc?> get(String path) async {
    final resp = await http.get(_url('$_documents/$path'), headers: await _headers())
        .timeout(_timeout);
    if (resp.statusCode == 404) return null;
    return _doc(_decode(resp));
  }

  /// Creates or replaces the document at [path].
  Future<void> set(String path, Map<String, Object?> data) async {
    final resp = await http
        .patch(_url('$_documents/$path'),
            headers: await _headers(), body: jsonEncode({'fields': encodeFields(data)}))
        .timeout(_timeout);
    _decode(resp);
  }

  /// Every document of a collection, up to [limit], ordered by [orderBy]
  /// (a field name, optionally followed by " desc").
  Future<List<FirestoreDoc>> list(String collection,
      {String? orderBy, int limit = 300}) async {
    final docs = <FirestoreDoc>[];
    String? pageToken;
    do {
      final resp = await http
          .get(
            _url('$_documents/$collection', {
              'pageSize': '${limit - docs.length < 300 ? limit - docs.length : 300}',
              'orderBy': ?orderBy,
              'pageToken': ?pageToken,
            }),
            headers: await _headers(),
          )
          .timeout(_timeout);
      final json = _decode(resp);
      for (final d in (json['documents'] as List<dynamic>? ?? const [])) {
        docs.add(_doc(d as Map<String, dynamic>));
      }
      pageToken = json['nextPageToken'] as String?;
    } while (pageToken != null && docs.length < limit);
    return docs;
  }

  /// A query on one top-level collection: optionally filtered by one field
  /// being equal to a value, optionally ordered by one field.
  ///
  /// Filtering and ordering on different fields would need a composite index
  /// created by hand in the console, so callers filter here and sort
  /// themselves, or order without filtering.
  Future<List<FirestoreDoc>> query(
    String collection, {
    String? whereField,
    Object? equals,
    String? orderBy,
    bool descending = false,
    int limit = 100,
  }) async {
    final body = {
      'structuredQuery': {
        'from': [
          {'collectionId': collection},
        ],
        if (whereField != null)
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': whereField},
              'op': 'EQUAL',
              'value': encodeValue(equals),
            },
          },
        if (orderBy != null)
          'orderBy': [
            {
              'field': {'fieldPath': orderBy},
              'direction': descending ? 'DESCENDING' : 'ASCENDING',
            },
          ],
        'limit': limit,
      },
    };
    final resp = await http
        .post(_url('$_documents:runQuery'), headers: await _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    if (resp.statusCode != 200) _decode(resp);
    final rows = jsonDecode(resp.body) as List<dynamic>;
    return [
      for (final row in rows)
        if ((row as Map<String, dynamic>)['document'] != null)
          _doc(row['document'] as Map<String, dynamic>),
    ];
  }

  /// Applies several writes atomically — up to 500 in one call. Each write is
  /// either `{'delete': name}` or `{'update': {'name': name, 'fields': ...}}`.
  Future<void> commit(List<Map<String, Object?>> writes) async {
    for (var i = 0; i < writes.length; i += 500) {
      final chunk = writes.sublist(i, i + 500 > writes.length ? writes.length : i + 500);
      final resp = await http
          .post(_url('$_documents:commit'),
              headers: await _headers(), body: jsonEncode({'writes': chunk}))
          .timeout(_timeout);
      _decode(resp);
    }
  }

  static const _timeout = Duration(seconds: 20);

  static FirestoreDoc _doc(Map<String, dynamic> json) {
    final name = json['name'] as String;
    return FirestoreDoc(
      name.substring(name.lastIndexOf('/') + 1),
      decodeFields(json['fields'] as Map<String, dynamic>? ?? const {}),
    );
  }

  static Map<String, dynamic> _decode(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.body.isEmpty ? const {} : jsonDecode(resp.body) as Map<String, dynamic>;
    }
    String message = 'HTTP ${resp.statusCode}';
    try {
      final error = (jsonDecode(resp.body) as Map<String, dynamic>)['error'];
      if (error is Map<String, dynamic>) message = '${error['status']}: ${error['message']}';
    } catch (_) {}
    throw CloudException(message, signedOut: resp.statusCode == 401);
  }
}

// ───────────────────────────── value codec ─────────────────────────────

/// Plain Dart values → Firestore's typed JSON (`{"doubleValue": 1.5}`, …).
Map<String, Object?> encodeFields(Map<String, Object?> data) =>
    {for (final e in data.entries) e.key: encodeValue(e.value)};

Map<String, Object?> encodeValue(Object? value) => switch (value) {
      null => {'nullValue': null},
      bool b => {'booleanValue': b},
      int i => {'integerValue': '$i'},
      double d => {'doubleValue': d},
      DateTime t => {'timestampValue': t.toUtc().toIso8601String()},
      String s => {'stringValue': s},
      _ => throw ArgumentError('cannot store ${value.runtimeType} in Firestore'),
    };

/// Firestore's typed JSON → plain Dart values. Numbers come back as the type
/// they were stored with; [asDouble] smooths over the int/double split.
Map<String, Object?> decodeFields(Map<String, dynamic> fields) =>
    {for (final e in fields.entries) e.key: decodeValue(e.value as Map<String, dynamic>)};

Object? decodeValue(Map<String, dynamic> value) {
  final MapEntry(:key, value: raw) = value.entries.first;
  return switch (key) {
    'nullValue' => null,
    'booleanValue' => raw as bool,
    'integerValue' => int.parse('$raw'),
    'doubleValue' => (raw as num).toDouble(),
    'timestampValue' => DateTime.parse(raw as String),
    'stringValue' => raw as String,
    _ => null, // maps, arrays and references are not used by Nova
  };
}

double asDouble(Object? value) => value is num ? value.toDouble() : 0;
