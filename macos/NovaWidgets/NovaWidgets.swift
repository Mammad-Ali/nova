import AppIntents
import AppKit
import Charts
import SwiftUI
import WidgetKit

// Nova's desktop and Notification Centre widgets. The app writes what they
// show to a small JSON file (see widget_bridge.dart and WidgetStore in
// MainFlutterWindow.swift). "Start test" runs the test in the background
// (StartTestIntent); every other click goes to the app as a nova:// link
// that opens it on the matching action.

// MARK: - Data

/// What the app last wrote. Times are milliseconds since 1970; byte totals
/// arrive already formatted, the way the app shows them.
struct NovaSnapshot: Decodable {
  struct Test: Decodable {
    let t: Double
    let down: Double
    let up: Double
    let ping: Double
    let jitter: Double
    let grade: String
    let tier: String
    let tierKey: String

    var date: Date { Date(timeIntervalSince1970: t / 1000) }
  }

  struct Usage: Decodable {
    let hour: String
    let today: String
    let month: String
    let forecast: String?
  }

  struct Service: Decodable {
    let name: String
    let ms: Double?
  }

  /// Today's busiest apps, from Nova's own count (1.6 and later).
  struct Apps: Decodable {
    struct App: Decodable {
      let name: String
      let kind: String
      let bytes: String
      /// Of the busiest app's total, 0–1.
      let share: Double
      /// The icon Nova saved for the widgets, by file name.
      let icon: String?
    }
    let total: String
    let count: Int
    let list: [App]
  }

  /// The last scan of the network (1.6 and later).
  struct Network: Decodable {
    let online: Int
    let t: Double
    let newest: String?

    var date: Date { Date(timeIntervalSince1970: t / 1000) }
  }

  let test: Test?
  let recent: [Double]
  let best: Double?
  let usage: Usage?
  let services: [Service]
  let provider: String?
  let labels: [String: String]

  /// A test is running right now; absent in files from before 1.5.
  var running: Bool? = nil
  var apps: Apps? = nil
  var network: Network? = nil

  var isTesting: Bool { running == true }

  /// The app's words for [key] in the app's language, English until the app
  /// has written any.
  func label(_ key: String, _ english: String) -> String { labels[key] ?? english }

  /// Shown in the widget gallery before Nova has written anything.
  static let sample = NovaSnapshot(
    test: Test(
      t: Date().addingTimeInterval(-300).timeIntervalSince1970 * 1000,
      down: 214.4, up: 88.7, ping: 12.6, jitter: 2.1,
      grade: "A", tier: "Fast", tierKey: "fast"),
    recent: [92, 120, 88, 140, 176, 150, 198, 214.4],
    best: 214.4,
    usage: Usage(hour: "341 MB", today: "4.2 GB", month: "61.8 GB", forecast: "92 GB"),
    services: [
      Service(name: "Google", ms: 18), Service(name: "Cloudflare", ms: 9),
      Service(name: "YouTube", ms: 21), Service(name: "Discord", ms: 44),
      Service(name: "Telegram", ms: 63), Service(name: "Steam", ms: 131),
    ],
    provider: "Your provider",
    labels: [:],
    apps: Apps(total: "4.2 GB", count: 8, list: [
      Apps.App(name: "Google Chrome", kind: "app", bytes: "2.1 GB", share: 1, icon: nil),
      Apps.App(name: "Telegram", kind: "app", bytes: "880 MB", share: 0.42, icon: nil),
      Apps.App(name: "Music", kind: "app", bytes: "620 MB", share: 0.3, icon: nil),
      Apps.App(name: "macOS services", kind: "system", bytes: "290 MB", share: 0.14, icon: nil),
      Apps.App(name: "Mail", kind: "app", bytes: "120 MB", share: 0.06, icon: nil),
    ]),
    network: Network(online: 6, t: Date().addingTimeInterval(-720).timeIntervalSince1970 * 1000,
                     newest: "Xiaomi · Phone"))

  /// No test yet: the widgets invite one.
  static let empty = NovaSnapshot(
    test: nil, recent: [], best: nil, usage: nil, services: [], provider: nil, labels: [:])
}

/// Reads the file the app writes. The widget runs in a sandbox of its own,
/// so the file sits outside both containers, under the real home folder; the
/// widget's entitlements allow reading exactly that folder.
enum NovaStore {
  private static let home: String = {
    if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
      return String(cString: dir)
    }
    return NSHomeDirectory()
  }()

  static var file: URL {
    URL(fileURLWithPath: home)
      .appendingPathComponent("Library/Application Support/Nova/widgets.json")
  }

  /// An app's icon, saved by the app next to the JSON.
  static func icon(_ name: String?) -> NSImage? {
    guard let name, !name.contains("/") else { return nil }
    return NSImage(contentsOf: file.deletingLastPathComponent()
      .appendingPathComponent("icons").appendingPathComponent(name))
  }

  static func load() -> NovaSnapshot? {
    guard let data = try? Data(contentsOf: file) else { return nil }
    return try? JSONDecoder().decode(NovaSnapshot.self, from: data)
  }
}

// MARK: - Timeline

struct NovaEntry: TimelineEntry {
  let date: Date
  let snapshot: NovaSnapshot
}

/// The app reloads the widgets whenever it writes; the half-hourly refresh
/// only catches up after the app was quit.
struct NovaProvider: TimelineProvider {
  func placeholder(in context: Context) -> NovaEntry {
    NovaEntry(date: .now, snapshot: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (NovaEntry) -> Void) {
    let stored = NovaStore.load()
    completion(NovaEntry(date: .now, snapshot: stored ?? (context.isPreview ? .sample : .empty)))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<NovaEntry>) -> Void) {
    // One entry every five minutes for two hours keeps "6 min ago" true
    // without a ticking seconds counter; the app reloads sooner whenever it
    // has something new.
    let snapshot = NovaStore.load() ?? .empty
    let entries = (0..<24).map { step in
      NovaEntry(date: .now.addingTimeInterval(Double(step) * 5 * 60), snapshot: snapshot)
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

// MARK: - Look

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

/// Nova's colours (lib/core/theme/app_theme.dart).
enum Palette {
  static let sun = Color(hex: 0xFFC61A)
  static let down = Color(hex: 0x818CF8)
  static let up = Color(hex: 0xE879F9)
  static let alt = Color(hex: 0x60A5FA)
  static let info = Color(hex: 0x6366F1)
  static let green = Color(hex: 0x4ADE80)
  static let amber = Color(hex: 0xFBBF24)
  static let red = Color(hex: 0xFB7185)
  static let textMid = Color.white.opacity(0.72)
  static let textLo = Color.white.opacity(0.45)
  static let glass = Color.white.opacity(0.07)

  static func tier(_ key: String) -> Color {
    switch key {
    case "blazing": return green
    case "fast": return down
    case "good": return info
    case "moderate": return amber
    default: return red
    }
  }

  /// Same bands as the app's latency tiles.
  static func latency(_ ms: Double?) -> Color {
    guard let ms else { return textLo }
    if ms < 60 { return green }
    if ms < 120 { return alt }
    if ms < 250 { return amber }
    return red
  }
}

/// The app's night sky, with a hint of the gauge's sun in one corner.
struct NovaBackground: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(hex: 0x10142A), Color(hex: 0x04050A)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
      RadialGradient(
        colors: [Palette.sun.opacity(0.16), .clear],
        center: .topTrailing, startRadius: 0, endRadius: 160)
    }
  }
}

func formatted(_ value: Double) -> String {
  value >= 100 ? String(format: "%.0f", value) : String(format: "%.1f", value)
}

/// Where each tap goes. The app opens and starts the action straight away.
enum NovaLink {
  static let test = URL(string: "nova://test")!
  static let call = URL(string: "nova://call")!
  static let cause = URL(string: "nova://cause")!
  static let open = URL(string: "nova://open")!
  static let apps = URL(string: "nova://apps")!
  static let lan = URL(string: "nova://lan")!
  /// The test, but without bringing Nova forward.
  static let quietTest = URL(string: "nova://test?quiet=1")!
}

/// "Start test" on a widget: Nova runs the test in the background — its
/// window stays where it is — and the widget shows the result once it lands.
/// The link is opened without activating Nova; a Link would bring it to the
/// front. If Nova isn't running, this starts it, still in the background.
struct StartTestIntent: AppIntent {
  static var title: LocalizedStringResource = "Start a speed test"
  static var description = IntentDescription("Runs a speed test in Nova without opening its window.")

  func perform() async throws -> some IntentResult {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    configuration.addsToRecentItems = false
    _ = try? await NSWorkspace.shared.open(NovaLink.quietTest, configuration: configuration)
    return .result()
  }
}

// MARK: - Pieces

struct Wordmark: View {
  var body: some View {
    Text("Nova")
      .font(.system(size: 13, weight: .black, design: .rounded))
      .foregroundStyle(Palette.sun)
      .widgetAccentable()
  }
}

struct GradeBadge: View {
  let test: NovaSnapshot.Test

  var body: some View {
    Text(test.grade)
      .font(.system(size: 13, weight: .heavy, design: .rounded))
      .foregroundStyle(Palette.tier(test.tierKey))
      .frame(minWidth: 26, minHeight: 22)
      .padding(.horizontal, 2)
      .background(
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .fill(Palette.tier(test.tierKey).opacity(0.16)))
      .overlay(
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .stroke(Palette.tier(test.tierKey).opacity(0.45), lineWidth: 1))
  }
}

/// In place of the grade while a test runs.
struct TestingBadge: View {
  let snapshot: NovaSnapshot

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "hourglass")
      Text(snapshot.label("testing", "Testing…"))
    }
    .font(.system(size: 11, weight: .bold))
    .foregroundStyle(Palette.sun)
    .padding(.horizontal, 8)
    .frame(minHeight: 22)
    .background(Capsule().fill(Palette.sun.opacity(0.15)))
    .overlay(Capsule().stroke(Palette.sun.opacity(0.45), lineWidth: 1))
  }
}

/// The grade, or "Testing…" while a test runs.
struct StatusBadge: View {
  let snapshot: NovaSnapshot

  var body: some View {
    if snapshot.isTesting {
      TestingBadge(snapshot: snapshot)
    } else if let test = snapshot.test {
      GradeBadge(test: test)
    }
  }
}

/// "Start test": runs StartTestIntent, so the test starts without Nova
/// coming to the front.
struct TestButton: View {
  let snapshot: NovaSnapshot
  var stacked = false

  var body: some View {
    Button(intent: StartTestIntent()) {
      ActionLabel(
        icon: snapshot.isTesting ? "hourglass" : "play.fill",
        title: snapshot.isTesting
          ? snapshot.label("testing", "Testing…")
          : snapshot.label("runTest", "Start test"),
        primary: true,
        stacked: stacked)
    }
    .buttonStyle(.plain)
  }
}

/// "6 min ago", as of the entry being shown.
struct Age: View {
  let date: Date
  let now: Date

  private static let formatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .short
    return f
  }()

  var body: some View {
    HStack(spacing: 3) {
      Image(systemName: "clock")
      Text(date > now.addingTimeInterval(-60)
        ? Self.formatter.localizedString(fromTimeInterval: 0)
        : Self.formatter.localizedString(for: date, relativeTo: now))
    }
    .font(.system(size: 10, weight: .medium))
    .foregroundStyle(Palette.textLo)
    .lineLimit(1)
  }
}

/// The big download figure with upload and ping underneath.
struct SpeedFigures: View {
  let snapshot: NovaSnapshot
  let test: NovaSnapshot.Test
  var size: CGFloat = 34

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(snapshot.label("download", "Download"))
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Palette.textLo)
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(formatted(test.down))
          .font(.system(size: size, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
          .minimumScaleFactor(0.5)
          .lineLimit(1)
        Text("Mbps")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(Palette.down)
      }
      HStack(spacing: 10) {
        Label {
          Text(formatted(test.up)).monospacedDigit()
        } icon: {
          Image(systemName: "arrow.up").foregroundStyle(Palette.up)
        }
        Label {
          Text("\(formatted(test.ping)) ms").monospacedDigit()
        } icon: {
          Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(Palette.green)
        }
      }
      .labelStyle(TightLabel())
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(Palette.textMid)
    }
  }
}

struct TightLabel: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 3) {
      configuration.icon
      configuration.title
    }
  }
}

/// No test yet: a clear invitation instead of empty numbers.
struct NoTestYet: View {
  let snapshot: NovaSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Image(systemName: "speedometer")
        .font(.system(size: 26, weight: .semibold))
        .foregroundStyle(Palette.sun)
      Text(snapshot.label("noTest", "No test yet — click to run one"))
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Palette.textMid)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// A full-width button that opens the app on an action.
struct ActionButton: View {
  let icon: String
  let title: String
  let url: URL
  var primary = false
  var stacked = false

  var body: some View {
    Link(destination: url) {
      ActionLabel(icon: icon, title: title, primary: primary, stacked: stacked)
    }
  }
}

struct ActionLabel: View {
  let icon: String
  let title: String
  let primary: Bool
  let stacked: Bool

  var body: some View {
    if stacked {
      VStack(spacing: 3) {
        Image(systemName: icon)
          .font(.system(size: 13, weight: .bold))
        Text(title)
          .font(.system(size: 11, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .foregroundStyle(primary ? Color.black : Color.white)
      .padding(.horizontal, 6)
      .frame(maxWidth: .infinity, minHeight: 44)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(primary ? Color.white : Palette.glass))
    } else {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 11, weight: .bold))
        Text(title)
          .font(.system(size: 11.5, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
        Spacer(minLength: 0)
      }
      .foregroundStyle(primary ? Color.black : Color.white)
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity, minHeight: 28)
      .background(
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .fill(primary ? Color.white : Palette.glass))
    }
  }
}

struct Tile<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    content
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.glass))
  }
}

// MARK: - Speed (small)

struct SpeedSmallView: View {
  let entry: NovaEntry

  var body: some View {
    let s = entry.snapshot
    // The whole widget is the button: a click starts a test in the
    // background, and the figures change when it is done.
    Button(intent: StartTestIntent()) {
      VStack(alignment: .leading, spacing: 0) {
        HStack {
          Wordmark()
          Spacer()
          StatusBadge(snapshot: s)
        }
        Spacer(minLength: 4)
        if let test = s.test {
          SpeedFigures(snapshot: s, test: test)
            .opacity(s.isTesting ? 0.4 : 1)
          Spacer(minLength: 4)
          Age(date: test.date, now: entry.date)
        } else {
          NoTestYet(snapshot: s)
          Spacer(minLength: 0)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Speed & tools (medium)

struct ToolsMediumView: View {
  let entry: NovaEntry

  var body: some View {
    let s = entry.snapshot
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 0) {
        HStack {
          Wordmark()
          Spacer()
          StatusBadge(snapshot: s)
        }
        Spacer(minLength: 4)
        if let test = s.test {
          SpeedFigures(snapshot: s, test: test, size: 36)
            .opacity(s.isTesting ? 0.4 : 1)
          Spacer(minLength: 4)
          HStack {
            Age(date: test.date, now: entry.date)
            Spacer()
            Text(test.tier)
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(Palette.tier(test.tierKey))
          }
        } else {
          NoTestYet(snapshot: s)
          Spacer(minLength: 0)
        }
      }
      .frame(maxWidth: .infinity)

      VStack(spacing: 7) {
        TestButton(snapshot: s)
        ActionButton(icon: "video.fill", title: s.label("callCheck", "Call check"), url: NovaLink.call)
        ActionButton(icon: "stethoscope", title: s.label("findCause", "Find the cause"), url: NovaLink.cause)
      }
      .frame(width: 136)
    }
    .widgetURL(NovaLink.open)
  }
}

// MARK: - Dashboard (large)

struct DashboardLargeView: View {
  let entry: NovaEntry

  var body: some View {
    let s = entry.snapshot
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 6) {
        Wordmark()
        if let provider = s.provider {
          Text(provider)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Palette.textLo)
            .lineLimit(1)
        }
        Spacer()
        if let test = s.test, !s.isTesting {
          Age(date: test.date, now: entry.date)
        }
        StatusBadge(snapshot: s)
      }

      if let test = s.test {
        HStack(spacing: 6) {
          // Three across: a fourth (jitter) would squeeze every number.
          figure(s.label("download", "Download"), formatted(test.down), "Mbps", Palette.down)
          figure(s.label("upload", "Upload"), formatted(test.up), "Mbps", Palette.up)
          figure(s.label("ping", "Ping"), formatted(test.ping), "ms", Palette.green)
        }
        .opacity(s.isTesting ? 0.4 : 1)
      } else {
        Tile { NoTestYet(snapshot: s) }
      }

      if s.recent.count >= 2 {
        TrendChart(values: s.recent, best: s.best)
          .frame(height: 50)
      }

      if !s.services.isEmpty {
        Text(s.label("services", "Latency to services"))
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(Palette.textLo)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
          // One row of them when today's apps need the room below.
          ForEach(Array(s.services.prefix(hasApps(s) ? 3 : 6).enumerated()), id: \.offset) { _, service in
            Tile {
              HStack(spacing: 4) {
                Text(service.name)
                  .font(.system(size: 10, weight: .medium))
                  .foregroundStyle(Palette.textMid)
                  .lineLimit(1)
                Spacer(minLength: 2)
                Text(service.ms.map { "\(formatted($0))" } ?? "—")
                  .font(.system(size: 11, weight: .bold, design: .rounded))
                  .monospacedDigit()
                  .foregroundStyle(Palette.latency(service.ms))
              }
            }
          }
        }
      }

      if let apps = s.apps, !apps.list.isEmpty {
        Text(s.label("appsToday", "Apps today"))
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(Palette.textLo)
        HStack(spacing: 6) {
          ForEach(Array(apps.list.prefix(3).enumerated()), id: \.offset) { _, app in
            Tile {
              HStack(spacing: 6) {
                AppIcon(app: app, size: 18)
                Text(app.bytes)
                  .font(.system(size: 11, weight: .bold, design: .rounded))
                  .monospacedDigit()
                  .foregroundStyle(.white)
                  .lineLimit(1)
                  .minimumScaleFactor(0.7)
              }
            }
          }
        }
      }

      if let usage = s.usage {
        HStack(spacing: 6) {
          usageTile(s.label("pastHour", "Past hour"), usage.hour)
          usageTile(s.label("today", "Today"), usage.today)
          usageTile(s.label("month", "This month"), usage.month)
        }
      }

      Spacer(minLength: 0)

      // Icon above label: a third of the width is too narrow for both side
      // by side in every language.
      HStack(spacing: 6) {
        TestButton(snapshot: s, stacked: true)
        ActionButton(icon: "video.fill", title: s.label("callCheck", "Call check"), url: NovaLink.call, stacked: true)
        ActionButton(icon: "stethoscope", title: s.label("findCause", "Find the cause"), url: NovaLink.cause, stacked: true)
      }
    }
    .widgetURL(NovaLink.open)
  }

  private func figure(_ label: String, _ value: String, _ unit: String, _ color: Color) -> some View {
    Tile {
      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 3) {
          Text(label)
            .foregroundStyle(Palette.textLo)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
          Spacer(minLength: 0)
          Text(unit)
            .foregroundStyle(color)
            .fixedSize()
        }
        .font(.system(size: 9.5, weight: .semibold))
        Text(value)
          .font(.system(size: 18, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
          .minimumScaleFactor(0.6)
          .lineLimit(1)
      }
    }
  }

  private func hasApps(_ s: NovaSnapshot) -> Bool { !(s.apps?.list.isEmpty ?? true) }

  private func usageTile(_ label: String, _ value: String) -> some View {
    Tile {
      VStack(alignment: .leading, spacing: 1) {
        Text(label)
          .font(.system(size: 9.5, weight: .semibold))
          .foregroundStyle(Palette.textLo)
          .lineLimit(1)
        Text(value)
          .font(.system(size: 13, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    }
  }
}

/// Download speed over the recent tests, with the personal best as a line.
struct TrendChart: View {
  let values: [Double]
  let best: Double?

  var body: some View {
    let top = max(values.max() ?? 1, best ?? 0) * 1.15
    Chart {
      ForEach(Array(values.enumerated()), id: \.offset) { index, value in
        AreaMark(x: .value("Test", index), y: .value("Mbps", value))
          .foregroundStyle(
            LinearGradient(
              colors: [Palette.down.opacity(0.35), Palette.down.opacity(0.0)],
              startPoint: .top, endPoint: .bottom))
          .interpolationMethod(.monotone)
        LineMark(x: .value("Test", index), y: .value("Mbps", value))
          .foregroundStyle(Palette.down)
          .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
          .interpolationMethod(.monotone)
      }
      if let best {
        RuleMark(y: .value("Best", best))
          .foregroundStyle(Palette.sun.opacity(0.55))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
      }
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartYScale(domain: 0...top)
    .padding(.vertical, 4)
    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.glass))
  }
}

// MARK: - Traffic (small)

struct TrafficSmallView: View {
  let entry: NovaEntry

  var body: some View {
    let s = entry.snapshot
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 5) {
        Image(systemName: "arrow.up.arrow.down")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(Palette.sun)
        Text(s.label("traffic", "Traffic"))
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(.white)
        Spacer()
      }
      Spacer(minLength: 4)
      if let usage = s.usage {
        Text(s.label("today", "Today"))
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(Palette.textLo)
        Text(usage.today)
          .font(.system(size: 28, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
          .minimumScaleFactor(0.5)
          .lineLimit(1)
        Spacer(minLength: 4)
        row(s.label("month", "This month"), usage.month)
        if let forecast = usage.forecast {
          row(s.label("forecast", "Forecast"), forecast)
        }
        row(s.label("pastHour", "Past hour"), usage.hour)
      } else {
        Text(s.label("trafficEmpty", "Open Nova to start counting"))
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Palette.textMid)
        Spacer(minLength: 0)
      }
    }
    .widgetURL(NovaLink.open)
  }

  private func row(_ label: String, _ value: String) -> some View {
    HStack {
      Text(label).foregroundStyle(Palette.textLo)
      Spacer(minLength: 4)
      Text(value).monospacedDigit().foregroundStyle(Palette.textMid)
    }
    .font(.system(size: 10.5, weight: .semibold))
    .lineLimit(1)
  }
}

// MARK: - Apps today (small, medium)

/// The icon Nova saved for an app; a letter in a coloured square until there
/// is one, and a gear for macOS's own services.
struct AppIcon: View {
  let app: NovaSnapshot.Apps.App
  let size: CGFloat

  var body: some View {
    if let image = NovaStore.icon(app.icon) {
      Image(nsImage: image)
        .resizable()
        .interpolation(.high)
        .frame(width: size, height: size)
    } else {
      let color = app.kind == "app" ? AppIcon.color(app.name) : Palette.textMid
      ZStack {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
          .fill(color.opacity(0.18))
        if app.kind == "app" {
          Text(String(app.name.prefix(1)).uppercased())
            .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
        } else {
          Image(systemName: "gearshape.fill")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(color)
        }
      }
      .frame(width: size, height: size)
    }
  }

  /// The same colour for an app every time (app_badge.dart picks alike).
  static func color(_ name: String) -> Color {
    let palette = [Palette.down, Palette.up, Palette.alt, Palette.green, Palette.amber,
                   Palette.red, Palette.sun, Color(hex: 0x9333EA)]
    var hash = 0
    for unit in name.utf16 { hash = (hash &* 31 &+ Int(unit)) & 0x7fffffff }
    return palette[hash % palette.count]
  }
}

/// "Apps today" with Nova's wordmark; the total on the right when there's room.
struct AppsHeader: View {
  let snapshot: NovaSnapshot
  var total: String? = nil

  var body: some View {
    HStack(spacing: 6) {
      Wordmark()
      Text(snapshot.label("appsToday", "Apps today"))
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(Palette.textLo)
        .lineLimit(1)
      Spacer(minLength: 2)
      if let total {
        Text(total)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
      }
    }
  }
}

struct AppsEmpty: View {
  let snapshot: NovaSnapshot

  var body: some View {
    Text(snapshot.label("appsEmpty", "Nova counts each app's traffic while it runs"))
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(Palette.textMid)
  }
}

/// A: today's busiest app large, the next three as icons.
struct AppsSmallView: View {
  let entry: NovaEntry

  var body: some View {
    let s = entry.snapshot
    VStack(alignment: .leading, spacing: 0) {
      AppsHeader(snapshot: s)
      Spacer(minLength: 6)
      if let apps = s.apps, let top = apps.list.first {
        HStack(spacing: 8) {
          AppIcon(app: top, size: 34)
          VStack(alignment: .leading, spacing: 0) {
            Text(top.name)
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(Palette.textMid)
              .lineLimit(1)
            Text(top.bytes)
              .font(.system(size: 20, weight: .bold, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(.white)
              .lineLimit(1)
              .minimumScaleFactor(0.6)
          }
        }
        Spacer(minLength: 6)
        HStack(spacing: 5) {
          ForEach(Array(apps.list.dropFirst().prefix(3).enumerated()), id: \.offset) { _, app in
            AppIcon(app: app, size: 22)
          }
          if apps.count > 4 {
            Text(s.label("appsMore", "+{0} more").replacingOccurrences(of: "{0}", with: "\(apps.count - 4)"))
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(Palette.textLo)
              .lineLimit(1)
          }
        }
        Spacer(minLength: 6)
        HStack(spacing: 4) {
          Text(s.label("appsTotal", "Total"))
          Text(apps.total).monospacedDigit().foregroundStyle(Palette.textMid)
        }
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(Palette.textLo)
      } else {
        AppsEmpty(snapshot: s)
        Spacer(minLength: 0)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetURL(NovaLink.apps)
  }
}

/// B: today's four busiest apps, each with a bar against the busiest.
struct AppsMediumView: View {
  let entry: NovaEntry

  var body: some View {
    let s = entry.snapshot
    VStack(alignment: .leading, spacing: 7) {
      AppsHeader(snapshot: s, total: s.apps?.total)
      if let apps = s.apps, !apps.list.isEmpty {
        ForEach(Array(apps.list.prefix(4).enumerated()), id: \.offset) { _, app in
          HStack(spacing: 8) {
            AppIcon(app: app, size: 22)
            VStack(alignment: .leading, spacing: 3) {
              HStack {
                Text(app.name)
                  .font(.system(size: 11.5, weight: .semibold))
                  .foregroundStyle(.white)
                  .lineLimit(1)
                Spacer(minLength: 4)
                Text(app.bytes)
                  .font(.system(size: 11.5, weight: .bold, design: .rounded))
                  .monospacedDigit()
                  .foregroundStyle(Palette.textMid)
              }
              GeometryReader { geo in
                ZStack(alignment: .leading) {
                  Capsule().fill(Palette.glass)
                  Capsule()
                    .fill(Palette.down)
                    .frame(width: max(4, geo.size.width * min(1, app.share)))
                }
              }
              .frame(height: 4)
            }
          }
        }
        Spacer(minLength: 0)
      } else {
        Spacer(minLength: 0)
        AppsEmpty(snapshot: s)
        Spacer(minLength: 0)
      }
    }
    .widgetURL(NovaLink.apps)
  }
}

struct AppsView: View {
  let entry: NovaEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    if family == .systemSmall {
      AppsSmallView(entry: entry)
    } else {
      AppsMediumView(entry: entry)
    }
  }
}

// MARK: - Network (small)

struct NetworkSmallView: View {
  let entry: NovaEntry

  var body: some View {
    let s = entry.snapshot
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 5) {
        Text(s.label("network", "Network"))
          .font(.system(size: 13, weight: .black, design: .rounded))
          .foregroundStyle(Palette.sun)
        Spacer()
        Image(systemName: "laptopcomputer.and.iphone")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Palette.alt)
      }
      Spacer(minLength: 4)
      if let network = s.network {
        Text("\(network.online)")
          .font(.system(size: 34, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
        Text(s.label("online", "devices online"))
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(Palette.textMid)
          .lineLimit(1)
        Spacer(minLength: 4)
        if let newest = network.newest {
          Text(s.label("newDevice", "New: {0}").replacingOccurrences(of: "{0}", with: newest))
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(Palette.amber)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Palette.amber.opacity(0.15)))
          Spacer(minLength: 4)
        }
        Age(date: network.date, now: entry.date)
      } else {
        Text(s.label("networkEmpty", "Nova scans your network every half hour"))
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Palette.textMid)
        Spacer(minLength: 0)
      }
    }
    .widgetURL(NovaLink.lan)
  }
}

// MARK: - Widgets

/// The gallery's names come from the app's language once it has written its
/// file; English before that.
private let galleryLabels = NovaStore.load() ?? .empty

struct SpeedWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "NovaSpeed", provider: NovaProvider()) { entry in
      SpeedSmallView(entry: entry).containerBackground(for: .widget) { NovaBackground() }
    }
    .configurationDisplayName(galleryLabels.label("speedName", "Speed"))
    .description(galleryLabels.label("speedDesc", "Your last result at a glance. Tap to run a new test."))
    .supportedFamilies([.systemSmall])
  }
}

struct ToolsWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "NovaTools", provider: NovaProvider()) { entry in
      ToolsMediumView(entry: entry).containerBackground(for: .widget) { NovaBackground() }
    }
    .configurationDisplayName(galleryLabels.label("toolsName", "Speed & tools"))
    .description(galleryLabels.label("toolsDesc", "Your last result, with one tap to test, check a call or find the cause."))
    .supportedFamilies([.systemMedium])
  }
}

struct DashboardWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "NovaDashboard", provider: NovaProvider()) { entry in
      DashboardLargeView(entry: entry).containerBackground(for: .widget) { NovaBackground() }
    }
    .configurationDisplayName(galleryLabels.label("dashName", "Dashboard"))
    .description(galleryLabels.label("dashDesc", "Results, trend, latency to services and traffic — all at once."))
    .supportedFamilies([.systemLarge])
  }
}

struct TrafficWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "NovaTraffic", provider: NovaProvider()) { entry in
      TrafficSmallView(entry: entry).containerBackground(for: .widget) { NovaBackground() }
    }
    .configurationDisplayName(galleryLabels.label("trafficName", "Traffic"))
    .description(galleryLabels.label("trafficDesc", "How much data you used this hour, today and this month."))
    .supportedFamilies([.systemSmall])
  }
}

struct AppsWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "NovaApps", provider: NovaProvider()) { entry in
      AppsView(entry: entry).containerBackground(for: .widget) { NovaBackground() }
    }
    .configurationDisplayName(galleryLabels.label("appsName", "Apps today"))
    .description(galleryLabels.label("appsDesc", "Which apps used the most data today."))
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct NetworkWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "NovaNetwork", provider: NovaProvider()) { entry in
      NetworkSmallView(entry: entry).containerBackground(for: .widget) { NovaBackground() }
    }
    .configurationDisplayName(galleryLabels.label("networkName", "Network"))
    .description(galleryLabels.label("networkDesc", "How many devices are on your network, and who's new."))
    .supportedFamilies([.systemSmall])
  }
}

@main
struct NovaWidgets: WidgetBundle {
  var body: some Widget {
    SpeedWidget()
    ToolsWidget()
    DashboardWidget()
    TrafficWidget()
    AppsWidget()
    NetworkWidget()
  }
}
