<div align="center">

<img src="assets/icon/nova_icon.png" width="128" alt="Nova">

# Nova

**Know exactly what your internet connection is doing.**

A cross-platform network companion: an accurate speed test and a live
system-wide traffic monitor, in one app.

[![Build](https://github.com/Mammad-Ali/pulsar/actions/workflows/build.yml/badge.svg)](https://github.com/Mammad-Ali/pulsar/actions/workflows/build.yml)
![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20Windows%20%7C%20macOS-black)
![Flutter](https://img.shields.io/badge/Flutter-stable-black)
![License](https://img.shields.io/badge/license-MIT-black)

</div>

---

## Why another speed test?

Most speed tests answer one question: *how many megabits do I get?* That number
alone rarely explains why a call stutters or why a game lags. Nova measures the
things that actually decide how the connection **feels**:

- **Latency under load (bufferbloat).** Ping is measured *while* the link is
  saturated, not only when idle. This is the single best predictor of laggy
  games and choppy calls, and it is missing from most speed tests.
- **Real-world verdicts.** Results are translated into plain answers: is this
  enough for 4K, for gaming, for streaming?
- **What happens between tests.** A passive monitor keeps watching the link, so
  brief outages and slow hours don't go unnoticed.

## Features

### Speed test

| | |
|---|---|
| **Download / upload / ping / jitter** | Measured over four parallel connections against public CDNs |
| **Latency under load** | Bufferbloat rating A–D, the metric that predicts lag |
| **Automatic server failover** | Cloudflare → Cachefly → Hetzner; a rate-limited source never breaks a run |
| **Connection grade** | A single A+…E score, plus a plain-language tier |
| **Comfort scale** | Whether the speed suits 4K, gaming, calls, streaming and large downloads |
| **ISP throttling detector** | Compares a neutral CDN against Netflix's CDN to spot video throttling |
| **Latency to services** | Round-trip times to YouTube, Discord, Steam, Cloudflare and more |
| **History** | Every completed run, with a trend chart, personal best and a comparison to the previous run |
| **Sharing** | Copy results as text, save them as an image, export the history to CSV |

### Traffic monitor

| | |
|---|---|
| **Live throughput** | System-wide Rx/Tx, sampled once per second |
| **Usage totals** | Hour, day and month, with a projection for the end of the month |
| **Connection stability** | A rolling latency chart with packet loss and outage detection |
| **Wi-Fi context** | Signal strength and link rate, so "slow" can be traced to the router |

### Desktop integration

- Live speed in the **menu bar** (macOS) or **tray** (Windows)
- Click the icon for a **compact panel** — full readings without opening the app
- Closing the window keeps monitoring in the background
- Notifications when speed drops below a threshold or a daily limit is reached
- Animations pause automatically when the window is hidden, to spare the battery

### Everywhere

- Three interface languages: **English, Azerbaijani, Russian**
- A single dark theme built for readability against the animated backdrop

## Install

Ready-to-run builds are attached to every successful CI run under
[**Actions → Build**](https://github.com/Mammad-Ali/pulsar/actions/workflows/build.yml)
(open the newest green run and scroll to *Artifacts*).

| Platform | Artifact | How to run |
|---|---|---|
| **Android** | `nova-apk` | Install `app-arm64-v8a-release.apk`. Play Protect will warn about an unknown developer — choose *More details → Install anyway*. |
| **Windows** | `nova-windows-setup` | Run `Nova-Setup.exe`. No admin rights needed. SmartScreen will warn — choose *More info → Run anyway*. |
| **macOS** | build from source | `./tool/install_macos.sh` builds it, installs to `/Applications` and clears the quarantine flag so it opens with a double click. |

> Both warnings are expected: the builds are signed with a self-issued key
> rather than a paid Microsoft/Apple certificate. Neither affects how the app
> runs.

## Architecture

Clean Architecture, organised feature-first. Dependencies point inward —
`presentation → domain ← data` — so the UI never touches a network client and
the engine never imports a widget.

```
lib/
├─ app/          shell, navigation, animated backdrop
├─ core/         theme, localisation, settings, notifications, shared utils
├─ features/
│  ├─ speedtest/         engine, history, grading, comfort scale, sharing
│  ├─ traffic_monitor/   live counters, usage stats, stability probe
│  ├─ throttling/        neutral CDN vs. video CDN comparison
│  ├─ services_ping/     latency to popular services
│  ├─ wifi/              signal strength and link rate
│  ├─ alerts/            threshold notifications
│  └─ settings/
└─ shell/        tray icon, compact panel, window management
```

**The speed test runs in its own isolate.** At high line rates, counting bytes
and churning buffers costs real CPU — exactly while the user is watching an
animated gauge. Keeping it off the UI isolate is what keeps the needle smooth.
Progress is streamed back through a `SendPort`; a control port carries the
cancel signal.

**System traffic is read natively** through the `net_pulse/traffic`
`MethodChannel`. The method `getCounters` returns `[totalRx, totalTx]` —
cumulative bytes since boot — and Dart converts those into per-second deltas:

| Platform | Source |
|---|---|
| macOS | `getifaddrs` (Swift) |
| Android | `TrafficStats` (Kotlin) |
| Windows | `GetIfTable2` (C++) |

Two details worth knowing: the macOS counters are 32-bit and wrap at 4 GiB, so
the repository corrects for the rollover; and virtual adapters such as VPN
tunnels are filtered out on every platform to avoid double counting.

## Build from source

Requires the Flutter SDK (stable channel).

```bash
flutter pub get
flutter run -d macos     # or -d windows, or an attached Android device
```

Release builds:

```bash
flutter build apk --release        # Android
flutter build windows --release    # Windows
flutter build macos --release      # macOS
```

Android release signing expects `android/key.properties` and a keystore in
`android/keys/`; neither is committed. Without them the build falls back to the
debug signature, so `flutter run` keeps working out of the box.

## Tests

```bash
flutter test
```

The suite covers the pure logic (monthly totals, forecasting, throttling
verdicts) and drives the real engine end to end — a full run against live CDNs,
plus repeat-run and crash-regression checks.

## Tech stack

Flutter · Riverpod · fl_chart · `dart:io` `HttpClient` (no HTTP package needed)
· platform channels in Swift, Kotlin and C++ · Inno Setup for the Windows
installer · GitHub Actions for CI.

## License

[MIT](LICENSE)
