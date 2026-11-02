import Charts
import SwiftUI
import WidgetKit

// Nova's desktop and Notification Centre widgets. The app writes what they
// show to a small JSON file (see widget_bridge.dart and WidgetStore in
// MainFlutterWindow.swift); every tap goes back to the app as a nova:// link
// that starts the matching action.

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

  let test: Test?
  let recent: [Double]
  let best: Double?
  let usage: Usage?
  let services: [Service]
  let provider: String?
  let labels: [String: String]

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
    labels: [:])

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
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Wordmark()
        Spacer()
        if let test = s.test { GradeBadge(test: test) }
      }
      Spacer(minLength: 4)
      if let test = s.test {
        SpeedFigures(snapshot: s, test: test)
        Spacer(minLength: 4)
        Age(date: test.date, now: entry.date)
      } else {
        NoTestYet(snapshot: s)
        Spacer(minLength: 0)
      }
    }
    .widgetURL(NovaLink.test)
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
          if let test = s.test { GradeBadge(test: test) }
        }
        Spacer(minLength: 4)
        if let test = s.test {
          SpeedFigures(snapshot: s, test: test, size: 36)
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
        ActionButton(icon: "play.fill", title: s.label("runTest", "Start test"), url: NovaLink.test, primary: true)
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
        if let test = s.test {
          Age(date: test.date, now: entry.date)
          GradeBadge(test: test)
        }
      }

      if let test = s.test {
        HStack(spacing: 6) {
          // Three across: a fourth (jitter) would squeeze every number.
          figure(s.label("download", "Download"), formatted(test.down), "Mbps", Palette.down)
          figure(s.label("upload", "Upload"), formatted(test.up), "Mbps", Palette.up)
          figure(s.label("ping", "Ping"), formatted(test.ping), "ms", Palette.green)
        }
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
          ForEach(Array(s.services.prefix(6).enumerated()), id: \.offset) { _, service in
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
        ActionButton(icon: "play.fill", title: s.label("runTest", "Start test"), url: NovaLink.test, primary: true, stacked: true)
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

@main
struct NovaWidgets: WidgetBundle {
  var body: some Widget {
    SpeedWidget()
    ToolsWidget()
    DashboardWidget()
    TrafficWidget()
  }
}
