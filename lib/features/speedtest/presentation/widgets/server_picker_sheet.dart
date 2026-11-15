import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/azerbaijan_servers.dart';
import '../../data/datasources/ip_info.dart';
import '../../data/datasources/provider_ping.dart';
import '../../data/datasources/speedtest_servers.dart';

/// Picks the server the speed test runs against: "Automatic" (Cloudflare's
/// nearest data centre) or one of the providers' servers in Azerbaijan,
/// each timed as the sheet opens. Apps only: these servers don't let web
/// pages in.
void showServerPicker(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ServerPicker(),
  );
}

/// Round trips to every provider server, by id: a time in ms, or null when
/// it didn't answer. A server appears once it is done.
final _serverPingsProvider =
    NotifierProvider.autoDispose<_ServerPings, Map<int, double?>>(_ServerPings.new);

class _ServerPings extends Notifier<Map<int, double?>> {
  /// Requests in flight at once: enough to finish in a couple of seconds.
  static const _parallel = 16;

  @override
  Map<int, double?> build() {
    Future.microtask(_run);
    return const {};
  }

  Future<void> _run() async {
    final queue = [...kAzerbaijanServers];
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final server = queue.removeLast();
        final ms = await _time(server);
        if (!ref.mounted) return;
        state = {...state, server.id!: ms};
      }
    }

    await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
  }

  /// The best of three round trips over one connection, after a first one
  /// that warms it up — with the PING the speed test itself uses.
  static Future<double?> _time(SpeedTestServer server) async {
    final pinger = await ProviderPinger.connect(server.pingHost!);
    if (pinger == null) return null;
    try {
      double? best;
      for (var i = 0; i < 4; i++) {
        final ms = await pinger.once();
        if (ms == null) return null;
        if (i > 0 && (best == null || ms < best)) best = ms;
      }
      return best;
    } finally {
      pinger.close();
    }
  }
}

/// Whether [server] belongs to the provider the user is online through,
/// judged from the provider's name ("Aztelekom LLC" → Aztelekom).
bool isOwnProvider(SpeedTestServer server, String? isp) {
  if (isp == null) return false;
  final own = isp.toLowerCase();
  final sponsor = server.name.toLowerCase();
  // Nar's company is registered as Azerfon.
  if (sponsor == 'nar') return own.contains('azerfon') || RegExp(r'\bnar\b').hasMatch(own);
  final word = sponsor.split(RegExp(r'[^a-z0-9]+')).firstWhere((w) => w.length >= 4, orElse: () => sponsor);
  return own.contains(word);
}

class _ServerPicker extends ConsumerWidget {
  const _ServerPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final locale = ref.watch(localeProvider);
    final pings = ref.watch(_serverPingsProvider);
    final chosen = ref.watch(appSettingsProvider).serverId;
    final isp = ref.watch(ipInfoProvider).asData?.value.isp;
    final done = pings.length == kAzerbaijanServers.length;

    final answering = [
      for (final server in kAzerbaijanServers)
        if (pings[server.id] != null) server,
    ]..sort((a, b) {
        // Your own provider's first, then the quickest.
        final own = (isOwnProvider(b, isp) ? 1 : 0) - (isOwnProvider(a, isp) ? 1 : 0);
        return own != 0 ? own : pings[a.id]!.compareTo(pings[b.id]!);
      });
    final silent = pings.values.where((ms) => ms == null).length;

    void pick(int? id) {
      ref.read(appSettingsProvider.notifier).setServer(id);
      Navigator.of(context).pop();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.fromBorderSide(BorderSide(color: AppColors.onGlass.withValues(alpha: 0.12))),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.onGlass.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(
                    t.serverTitle,
                    style: TextStyle(color: AppColors.onGlass, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(t.serverIntro, style: TextStyle(color: AppColors.textLo, fontSize: 12.5, height: 1.4)),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      _Row(
                        title: t.serverAuto,
                        subtitle: t.serverAutoHint,
                        selected: chosen == null,
                        onTap: () => pick(null),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.serverSection,
                                style: TextStyle(color: AppColors.textMid, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (!done)
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textLo),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final server in answering)
                        _Row(
                          title: server.name,
                          subtitle: cityName(server.city!, locale),
                          ms: pings[server.id],
                          own: isOwnProvider(server, isp),
                          ownLabel: t.serverYours,
                          selected: chosen == server.id,
                          onTap: () => pick(server.id),
                        ),
                      if (done && silent > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                          child: Text(
                            AppStrings.fill(t.serverSilent, ['$silent']),
                            style: TextStyle(color: AppColors.textLo, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.ms,
    this.own = false,
    this.ownLabel,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final double? ms;
  final bool own;
  final String? ownLabel;

  @override
  Widget build(BuildContext context) {
    final color = ms == null
        ? AppColors.textMid
        : ms! < 30
            ? AppColors.green
            : ms! < 80
                ? AppColors.accentAlt
                : AppColors.amber;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: glassCard(radius: 16, glow: selected ? AppColors.sun : null),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? AppColors.sun : AppColors.textLo,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.onGlass, fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (own && ownLabel != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ownLabel!,
                              style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: AppColors.textLo, fontSize: 12)),
                  ],
                ),
              ),
              if (ms != null)
                Text(
                  '${ms!.round()} ms',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
