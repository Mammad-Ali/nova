import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dns_probe.dart';
import '../domain/dns_test.dart';

class DnsTestState {
  const DnsTestState({this.resolvers = const [], this.results = const {}, this.running = false});

  /// The system's own first, then the public ones.
  final List<DnsResolver> resolvers;

  /// By address, as each finishes.
  final Map<String, DnsResult> results;
  final bool running;

  DnsResolver? get current => resolvers.where((r) => r.current).firstOrNull;

  /// The fastest public server that works.
  DnsResolver? get bestPublic {
    DnsResolver? best;
    for (final r in resolvers.where((r) => !r.current)) {
      final result = results[r.address];
      if (result == null || !result.works) continue;
      if (best == null || result.medianMs! < results[best.address]!.medianMs!) best = r;
    }
    return best;
  }
}

final dnsTestProvider = NotifierProvider.autoDispose<DnsTestNotifier, DnsTestState>(DnsTestNotifier.new);

class DnsTestNotifier extends Notifier<DnsTestState> {
  /// Each name twice: the first may make the server look it up, the second
  /// comes from its cache — the two cases a browser meets.
  static const _rounds = 2;

  @override
  DnsTestState build() => const DnsTestState();

  Future<void> run() async {
    if (state.running) return;
    state = const DnsTestState(running: true);
    final system = await systemDnsServers();
    final resolvers = [
      for (final address in system) DnsResolver('', address, current: true),
      for (final r in publicResolvers)
        if (!system.contains(r.address)) r,
    ];
    if (!ref.mounted) return;
    state = DnsTestState(resolvers: resolvers, running: true);
    await Future.wait([for (final r in resolvers) _measure(r)]);
    if (ref.mounted) state = DnsTestState(resolvers: state.resolvers, results: state.results);
  }

  Future<void> _measure(DnsResolver resolver) async {
    final times = <double?>[];
    for (var round = 0; round < _rounds; round++) {
      for (final name in testNames) {
        times.add(await timeLookup(resolver.address, name));
      }
    }
    if (!ref.mounted) return;
    state = DnsTestState(
      resolvers: state.resolvers,
      results: {...state.results, resolver.address: DnsResult.from(times)},
      running: true,
    );
  }
}
