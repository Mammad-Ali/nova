import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Connection details: the ISP and the location derived from the IP.
class IpInfo {
  const IpInfo({this.isp, this.city, this.country, this.ip});

  final String? isp;
  final String? city;
  final String? country;
  final String? ip;

  bool get hasIsp => isp != null && isp!.trim().isNotEmpty;

  /// "Baku, Azerbaijan" — skips empty parts.
  String get location =>
      [city, country].where((e) => e != null && e.isNotEmpty).join(', ');
}

/// A single request to the free HTTPS service ipwho.is (no API key needed).
///
/// Goes through `package:http` rather than `dart:io`, because the web build
/// needs the same call and a browser has no `HttpClient`. ipwho.is sends
/// `Access-Control-Allow-Origin`, so the browser is allowed to read it.
Future<IpInfo> fetchIpInfo() async {
  try {
    final resp = await http
        .get(Uri.parse('https://ipwho.is/'))
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) return const IpInfo();

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (json['success'] == false) return const IpInfo();

    final conn = json['connection'] as Map<String, dynamic>?;
    return IpInfo(
      isp: (conn?['isp'] ?? conn?['org']) as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      ip: json['ip'] as String?,
    );
  } catch (_) {
    return const IpInfo();
  }
}

/// Resolved once when the tab opens; the result is cached.
final ipInfoProvider = FutureProvider<IpInfo>((ref) => fetchIpInfo());
