import 'package:flutter_test/flutter_test.dart';

import 'package:net_pulse/core/cloud/firestore_client.dart';
import 'package:net_pulse/core/cloud/google_identity_types.dart';
import 'package:net_pulse/features/leaderboard/data/firebase_backend.dart';
import 'package:net_pulse/features/speedtest/domain/entities/speedtest_record.dart';
import 'package:net_pulse/features/speedtest/domain/history_merge.dart';

SpeedTestRecord run(int millis, {double down = 50}) => SpeedTestRecord(
      timestamp: DateTime.fromMillisecondsSinceEpoch(millis),
      downloadMbps: down,
      uploadMbps: 10,
      pingMs: 20,
      jitterMs: 2,
    );

void main() {
  group('Firestore values', () {
    test('every kind of value survives a round trip', () {
      final when = DateTime.utc(2026, 10, 31, 12, 30, 15, 250);
      final data = <String, Object?>{
        'text': 'Aztelekom LLC',
        'whole': 42,
        'fraction': 89.6,
        'flag': true,
        'when': when,
        'nothing': null,
      };
      final back = decodeFields(
        Map<String, dynamic>.from(encodeFields(data)),
      );
      expect(back, data);
    });

    test('integers travel as strings, the way the API expects', () {
      expect(encodeValue(7), {'integerValue': '7'});
    });

    test('a speed stored as a whole number still reads as a double', () {
      expect(asDouble(decodeValue({'integerValue': '100'})), 100.0);
      expect(asDouble(null), 0);
    });
  });

  group('history merge', () {
    test('combines both sides, each test once, oldest first', () {
      final result = mergeHistory(
        [run(3000), run(1000)], // this device
        [run(2000), run(1000)], // the account: 1000 is the same test
      );
      expect(result.merged.map(historyKey), [1000, 2000, 3000]);
    });

    test('uploads only what the account does not have yet', () {
      final result = mergeHistory([run(1000), run(3000)], [run(1000)]);
      expect(result.toUpload.map(historyKey), [3000]);
    });

    test('a fresh device takes the whole account history', () {
      final result = mergeHistory(const [], [run(1000), run(2000)]);
      expect(result.merged, hasLength(2));
      expect(result.toUpload, isEmpty);
    });

    test('the same moment in UTC and local time is the same test', () {
      final local = run(1000);
      final fromCloud = SpeedTestRecord(
        timestamp: local.timestamp.toUtc(),
        downloadMbps: 50,
        uploadMbps: 10,
        pingMs: 20,
        jitterMs: 2,
      );
      expect(mergeHistory([local], [fromCloud]).merged, hasLength(1));
    });
  });

  group('sign-in safeguards', () {
    test('PKCE matches the example in RFC 7636', () {
      expect(
        pkceChallenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('reads the nonce out of an ID token', () {
      // header.payload.signature, payload = {"nonce":"abc","sub":"1"}
      const token = 'eyJhbGciOiJub25lIn0.eyJub25jZSI6ImFiYyIsInN1YiI6IjEifQ.sig';
      expect(jwtPayload(token)['nonce'], 'abc');
    });

    test('a malformed token yields no claims instead of crashing', () {
      expect(jwtPayload('not-a-token'), isEmpty);
      expect(jwtPayload('a.%%%.c'), isEmpty);
    });

    test('random tokens are URL-safe and unpadded', () {
      final token = randomUrlToken(32);
      expect(token, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      expect(token.length, 43);
      expect(randomUrlToken(), isNot(token));
    });
  });

  group('leaderboard and profile', () {
    test('a default nickname reveals nothing about the person', () {
      expect(defaultNickname('aB3xY9zQ'), 'Nova-AB3X');
    });

    test('long names are cut to what the database accepts', () {
      expect(clip('x' * 200, 120), hasLength(120));
      expect(clip('short', 120), 'short');
    });

    test('a leaderboard document becomes an entry, marked when it is mine', () {
      final doc = FirestoreDoc('uid-1', {
        'nickname': 'kaspi',
        'country': 'Azerbaijan',
        'provider': 'Aztelekom LLC',
        'd': 118.9,
        'u': 94,
        'p': 26.1,
        't': DateTime.utc(2026, 10, 31),
      });
      final entry = entryFromDoc(doc, me: 'uid-1');
      expect(entry.isMe, isTrue);
      expect(entry.uploadMbps, 94.0);
      expect(entryFromDoc(doc, me: 'someone-else').isMe, isFalse);
    });
  });
}
