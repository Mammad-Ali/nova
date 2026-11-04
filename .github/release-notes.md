## What's new in 1.5

- **A speedometer you can read.** A fixed scale with numbers on it — 5, 10,
  50, 100, 250, 500, 750, 1G (up to 10G for multi-gig lines) — instead of
  one that stretched with every test. Past **100 Mbps** the needle glows;
  past **500 Mbps** the stars go to warp speed.
- **Which apps use the network.** A new card on the Monitor tab. On the Mac
  it is live: each app's speed right now and how much it has used since it
  started. On Android it shows today's traffic per app (after you allow
  *Usage access*).
- **More devices in "Who's on my network".** Phones and TVs that ignore
  every port are now found by ping, the ARP table, UPnP and Bonjour, with
  their maker and a better guess at what they are.
- **Automatic speed tests.** Optional, in Settings: every 1, 3 or 6 hours,
  never on mobile data or a hotspot, with a second try when a result comes
  in under 50 Mbps.
- **Menu bar your way.** Turn it off, or choose what it shows: speed and the
  past hour, speed, download and upload, today's traffic or just the icon —
  in bytes or bits.
- **Start a test from a Mac widget** without opening Nova, and **update
  the Mac app in place**: *Update now* installs the new version and restarts.

On the Mac, Nova now runs outside the App Sandbox — inside it, macOS hides
which apps use the network. Your settings, history and sign-in move over
on the first launch.

## Use it in the browser — nothing to install

**[Open Nova](https://mammad-ali.github.io/nova/)** — the speed test, latency to
services and the call check run right in the page. The traffic monitor, the
network scan, Wi-Fi details, "Find the cause" and the Mac widgets need the app.

## Install the app

| Platform | File | How |
|---|---|---|
| **Windows** | `Nova-Windows-Setup.exe` | Run it. No administrator rights needed. |
| **macOS** | `Nova-macOS.dmg` | Open it and drag **Nova** onto **Applications**. |
| **Android** | `Nova-Android.apk` | Open it on the phone and tap **Install**. If the phone says the package does not fit, use `Nova-Android-universal.apk`. |

### The first launch warns about an unknown developer — that is expected

Nova is signed with its own key rather than a paid Apple or Microsoft
certificate. The warning appears once; the app itself is unaffected.

- **Windows** — SmartScreen: *More info* → *Run anyway*.
- **macOS** — "Apple could not verify Nova": open **System Settings →
  Privacy & Security**, scroll down and click **Open Anyway** next to Nova.
- **Android** — Play Protect: *More details* → *Install anyway*.
