import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/features/traffic_monitor/data/datasources/app_traffic_source.dart';
import 'package:net_pulse/features/traffic_monitor/data/repositories/app_usage_repository.dart';
import 'package:net_pulse/features/traffic_monitor/domain/entities/app_traffic.dart';
import 'package:net_pulse/features/traffic_monitor/presentation/providers/app_usage_tracker.dart';

void main() {
  test('app keys survive the round trip, colons in names included', () {
    const app = AppTraffic(name: 'Foo: Bar', bytesIn: 0, bytesOut: 0);
    expect(app.key, 'app:Foo: Bar');
    final back = appFromKey(app.key, bytesIn: 5);
    expect(back.name, 'Foo: Bar');
    expect(back.kind, AppTrafficKind.app);
    expect(back.bytesIn, 5);
    expect(appFromKey('system:').kind, AppTrafficKind.system);
  });

  test('history keeps five weeks and each day\'s busiest apps', () {
    final byDay = {
      for (var d = 1; d <= 40; d++)
        dayKey(DateTime(2026, 10, d)): {
          for (var a = 0; a < 100; a++) 'app:A$a': (a * 10, a),
        },
    };
    final back = AppUsageRepository.decode(AppUsageRepository.encode(byDay));
    expect(back.length, AppUsageRepository.maxDays);
    expect(back.keys.first, dayKey(DateTime(2026, 10, 6)));
    final day = back.values.first;
    expect(day.length, AppUsageRepository.maxAppsPerDay);
    expect(day['app:A99'], (990, 99));
    expect(day.containsKey('app:A0'), isFalse);
  });

  test('totals over a week, and one app day by day', () {
    final now = DateTime(2026, 11, 12, 15);
    final usage = MacAppUsage(
      byDay: {
        '2026-11-12': {'app:Telegram': (100, 10), 'system:': (5, 5)},
        '2026-11-10': {'app:Telegram': (50, 0)},
        '2026-11-01': {'app:Telegram': (999, 0)}, // older than a week
      },
      icons: {'app:Telegram': '/Applications/Telegram.app'},
      loaded: true,
    );
    final week = usage.over(7, now: now);
    expect(week.first.name, 'Telegram');
    expect(week.first.total, 160);
    expect(week.first.iconSource, '/Applications/Telegram.app');
    expect(usage.over(1, now: now).first.total, 110);
    expect(usage.daily('app:Telegram', 7, now: now), [0, 0, 0, 0, 50, 0, 110]);
  });

  test('an app is drawn with its outermost bundle', () {
    expect(
      MacAppTrafficSource.bundleFromPath('/Applications/Google Chrome.app/Contents/Frameworks/'
          'Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper'),
      '/Applications/Google Chrome.app',
    );
    expect(MacAppTrafficSource.bundleFromPath('/usr/sbin/mDNSResponder'), isNull);
    expect(MacAppTrafficSource.bundleFromPath('/opt/homebrew/bin/node'), isNull);
  });
}
