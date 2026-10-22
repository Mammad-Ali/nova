<div align="center">

<img src="assets/icon/nova_icon.png" width="128" alt="Nova">

# Nova

**Know exactly what your internet connection is doing.**

A cross-platform network companion: an accurate speed test and a live
system-wide traffic monitor, in one app.

[![Build](https://github.com/Mammad-Ali/nova/actions/workflows/build.yml/badge.svg)](https://github.com/Mammad-Ali/nova/actions/workflows/build.yml)
![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20Windows%20%7C%20macOS-black)
![Flutter](https://img.shields.io/badge/Flutter-stable-black)
![License](https://img.shields.io/badge/license-MIT-black)

**[Open in the browser](https://mammad-ali.github.io/nova/)** ·
**[Download for Windows, macOS or Android](#install)**

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
| **Leaderboard** | Best results ranked worldwide, by country or by ISP; sign-in is optional and only a nickname is shown. Runs on sample data until the cloud backend is connected |

### Traffic monitor

| | |
|---|---|
| **Live throughput** | System-wide Rx/Tx, sampled once per second |
| **Usage totals** | Hour, day and month, with a projection for the end of the month |
| **Connection stability** | A rolling latency chart with packet loss and outage detection |
| **Wi-Fi context** | Signal strength and link rate, so "slow" can be traced to the router |
| **Who's on my network** | Sweeps the local subnet and lists every device that answers, with the name it announces and a guess at what it is |

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

### In the browser — nothing to install

**[mammad-ali.github.io/nova](https://mammad-ali.github.io/nova/)** runs the
speed test right in the page. A browser cannot read system traffic counters,
scan the local network or see Wi-Fi details, so those parts live in the app.

### The app

These links always point at the newest release:

| Platform | Download | How |
|---|---|---|
| **Windows** | [Nova-Windows-Setup.exe](https://github.com/Mammad-Ali/nova/releases/latest/download/Nova-Windows-Setup.exe) | Run it. No administrator rights needed. |
| **macOS** | [Nova-macOS.dmg](https://github.com/Mammad-Ali/nova/releases/latest/download/Nova-macOS.dmg) | Open it and drag **Nova** onto **Applications**. |
| **Android** | [Nova-Android.apk](https://github.com/Mammad-Ali/nova/releases/latest/download/Nova-Android.apk) | Open it on the phone and tap **Install**. On an older or unusual device use the [universal APK](https://github.com/Mammad-Ali/nova/releases/latest/download/Nova-Android-universal.apk). |

All releases: [github.com/Mammad-Ali/nova/releases](https://github.com/Mammad-Ali/nova/releases).

#### The first launch warns about an unknown developer

That is expected: Nova is signed with its own key rather than a paid Apple or
Microsoft certificate. The warning appears once and does not affect the app.

- **Windows** — SmartScreen: *More info* → *Run anyway*.
- **macOS** — "Apple could not verify Nova": open **System Settings → Privacy &
  Security**, scroll down and click **Open Anyway**. (On recent macOS versions
  right-click → *Open* no longer offers this.)
- **Android** — Play Protect: *More details* → *Install anyway*.

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
│  ├─ lan_scan/          local subnet sweep, device names and kinds
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

**Finding neighbours needs no native code either.** Two properties make a
pure-Dart sweep work. A connection that is *refused* proves a host is there
just as well as one that succeeds, so devices with every port closed are still
counted. And names are asked for over **unicast** mDNS — an ordinary UDP
question sent straight to `<ip>:5353` — which responders answer happily. That
avoids multicast altogether: no contest for port 5353 with the system mDNS
daemon, which already holds it, and no per-platform option for choosing the
outgoing interface. Windows machines and NAS boxes, which ignore mDNS, are
asked over NetBIOS on UDP 137 instead. The sweep runs in an isolate and covers
254 addresses in about 90 ms.

## Build from source

Requires the Flutter SDK (stable channel).

```bash
flutter pub get
flutter run -d macos     # or -d windows, -d chrome, or an attached Android device
```

Release builds:

```bash
flutter build apk --release        # Android
flutter build windows --release    # Windows
flutter build macos --release      # macOS
flutter build web --release        # browser
```

On a Mac, `./tool/install_macos.sh` builds the app, installs it into
`/Applications` with its sandbox entitlements intact, and clears the
quarantine flag so it opens with a double click.

Android release signing expects `android/key.properties` and a keystore in
`android/keys/`; neither is committed. Without them the build falls back to the
debug signature, so `flutter run` keeps working out of the box.

### Publishing a release

Bump `version:` in `pubspec.yaml`, then push a matching tag:

```bash
git tag v1.2.0
git push origin v1.2.0
```

CI builds every platform and publishes a GitHub Release with the installers
under fixed names, so the download links above switch to the new version on
their own. Every push to `main` also republishes the browser version.

## Tests

```bash
flutter test                         # everything, including live network runs
flutter test --exclude-tags network  # offline only — what CI runs
```

The suite covers the pure logic (monthly totals, forecasting, throttling
verdicts, the network scan's packet parsing, the odometer's carry) and drives
the real engine end to end. Tests tagged `network` move real traffic to
Cloudflare and Netflix's CDN; CI skips them so a CDN hiccup cannot fail a
build.

## Tech stack

Flutter · Riverpod · fl_chart · `dart:io` sockets for the native speed test and
network scan, `XMLHttpRequest` in the browser · platform channels in Swift,
Kotlin and C++ · Inno Setup for the Windows installer · GitHub Actions for CI,
releases and the GitHub Pages site.

## License

[MIT](LICENSE)
