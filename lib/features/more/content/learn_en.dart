import 'learn_content.dart';

/// English text of the Learn, About and Help pages.
const learnEn = LearnContent(
  glossary: [
    Article(
      'Download',
      'How fast data reaches you: web pages, video, files. Measured in megabits per second (Mbps).',
    ),
    Article(
      'Upload',
      'How fast you send data out: video calls, cloud backups, posting photos and files.',
    ),
    Article(
      'Ping',
      'The time a tiny message needs to reach the server and come back, in milliseconds. Lower is better: it decides how responsive games and calls feel.',
    ),
    Article(
      'Jitter',
      'How much ping changes from moment to moment. High jitter makes calls choppy even when the average ping is fine.',
    ),
    Article(
      'Latency under load',
      'How much ping rises while the connection is busy. A large rise — "bufferbloat" — is why a game lags as soon as someone else starts a download.',
    ),
    Article(
      'Mbps',
      'Megabits per second. Eight megabits make one megabyte, so 100 Mbps moves about 12.5 megabytes per second.',
    ),
    Article(
      'Packet loss',
      'The share of data packets that never arrive. Even 1–2% causes stutters in calls and games.',
    ),
    Article(
      'Provider (ISP)',
      'The company that connects you to the internet.',
    ),
    Article(
      'Throttling',
      'When a provider deliberately slows certain traffic, such as video, while everything else stays fast.',
    ),
  ],
  guides: [
    Article(
      'Getting an accurate result',
      'Pause downloads and streaming on every device at home, use a cable if you can or sit close to the router, then run the test two or three times. The typical result tells you more than a single lucky one.',
    ),
    Article(
      'Is it the Wi-Fi or the line?',
      'Test once over a cable and once over Wi-Fi in the same spot. If the cable is much faster, the bottleneck is the wireless link: move closer to the router, switch to the 5 GHz network or check the signal in the Nova app.',
    ),
    Article(
      'How much speed do I need?',
      'Web and social media need about 5 Mbps, HD video 5–8, 4K video 25 and a video call 3–4 in each direction. Online games care about ping more than speed — under 50 ms feels good. At home the needs add up: three people streaming at once need three times as much.',
    ),
    Article(
      'Reading the latency-under-load grade',
      'A or B: the connection stays responsive when busy. C or D: lag jumps whenever someone downloads. Turning on "SQM" or "smart queue" in the router settings often fixes it.',
    ),
  ],
  faq: [
    Article(
      'Why is my result lower than my plan?',
      'Plans quote the maximum. Wi-Fi, other devices, the distance to the server and evening congestion all take their share. A test over a cable shows what the line itself delivers.',
    ),
    Article(
      'Why do speed tests disagree?',
      'Each uses its own servers and method. Nova measures against Cloudflare over four parallel connections, which is close to how large downloads behave.',
    ),
    Article(
      'How much data does a test use?',
      'Roughly the speed times sixteen seconds: about 200 MB on a 100 Mbps line, more on faster ones. Keep that in mind on mobile data.',
    ),
    Article(
      'Are my results sent anywhere?',
      'No. History and settings stay on your device. The Privacy page lists exactly who Nova talks to.',
    ),
    Article(
      'Why does the browser version do less?',
      'A browser cannot read system traffic counters, scan the local network or see Wi-Fi details. The app can, on Windows, macOS and Android.',
    ),
    Article(
      'Is Nova free?',
      'Yes, completely. Nova is open source under the MIT license.',
    ),
  ],
  about: 'Nova is a free, open-source network companion: an accurate speed test and a live traffic monitor in one app. Besides raw speed it measures what decides how a connection feels — latency under load, jitter and stability. It runs on Windows, macOS and Android, and the speed test also works right in the browser.',
  privacy: [
    Article(
      'Stays on your device',
      'Test results, history, settings and traffic statistics are stored only on your device. Nova has no server of its own that collects them.',
    ),
    Article(
      'Who Nova talks to',
      "The speed test exchanges data with Cloudflare's speed-test servers. To show your provider and city, Nova asks ipwho.is, which sees your IP address. The throttling check uses Netflix's fast.com, and ping to services contacts YouTube, Google, Discord, Steam, Cloudflare and Telegram. The network scan talks only to devices on your local network. The browser version is hosted on GitHub Pages and loads its graphics engine from Google's gstatic.com.",
    ),
    Article(
      'The leaderboard',
      'For now it runs on sample data inside the app, and nothing is published. Once the online leaderboard launches, only your nickname, country, provider and best result will be shared — never your name or e-mail.',
    ),
    Article(
      'No tracking',
      'No ads, no analytics, no trackers.',
    ),
  ],
  help: [
    Article(
      'Running a test',
      'Press Start test. Nova measures ping first, then download, then upload — about twenty seconds in all.',
    ),
    Article(
      'The test fails',
      'Check that you are online and try again. A VPN or firewall that blocks Cloudflare keeps the test from reaching its server.',
    ),
    Article(
      'A warning on first launch',
      'Nova is signed with its own key rather than a paid Apple or Microsoft certificate. Windows: More info → Run anyway. macOS: System Settings → Privacy & Security → Open Anyway. Android: Install anyway.',
    ),
    Article(
      'Something is wrong',
      'Report it on GitHub — the button below opens the issue page.',
    ),
  ],
  reportButton: 'Report a problem',
);
