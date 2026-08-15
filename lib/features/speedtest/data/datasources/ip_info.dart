import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
Future<IpInfo> fetchIpInfo() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client.getUrl(Uri.parse('https://ipwho.is/'));
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
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
  } finally {
    client.close(force: true);
  }
}

/// Resolved once when the tab opens; the result is cached.
final ipInfoProvider = FutureProvider<IpInfo>((ref) => fetchIpInfo());
