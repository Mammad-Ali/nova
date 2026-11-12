import Cocoa
import CoreWLAN
import FlutterMacOS
import Network
import Sparkle
import WidgetKit

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    // Before the engine starts: Dart reads its settings right away.
    SandboxMigration.run()

    // Apps opened from the Finder or the Dock may hold 256 open files. The
    // network scan (lan_scan_engine.dart) keeps a few hundred sockets and
    // pings going at once, and past the limit every new one fails — the
    // scan then quietly finds nothing. Raise it as far as the system allows.
    var files = rlimit()
    if getrlimit(RLIMIT_NOFILE, &files) == 0, files.rlim_cur < 4096 {
      files.rlim_cur = min(files.rlim_max, 4096)
      setrlimit(RLIMIT_NOFILE, &files)
    }

    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Plugin registration (shared_preferences, window_manager, tray_manager,
    // local_notifier, file_selector). Without this line no plugin is wired up
    // and every plugin channel fails with MissingPluginException.
    RegisterGeneratedPlugins(registry: flutterViewController)

    // --- MethodChannel exposing macOS network interface counters ---
    FlutterMethodChannel(
        name: "net_pulse/traffic",
        binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { call, result in
        guard call.method == "getCounters" else {
            result(FlutterMethodNotImplemented); return
        }
        var rx: UInt64 = 0, tx: UInt64 = 0
        var addrs: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&addrs) == 0 {
            defer { freeifaddrs(addrs) }
            var ptr = addrs
            while let p = ptr {
                let ifa = p.pointee
                if ifa.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
                   let data = ifa.ifa_data?.assumingMemoryBound(to: if_data.self),
                   !String(cString: ifa.ifa_name).hasPrefix("lo") {
                    rx &+= UInt64(data.pointee.ifi_ibytes)
                    tx &+= UInt64(data.pointee.ifi_obytes)
                }
                ptr = ifa.ifa_next
            }
        }
        result([Int64(bitPattern: rx), Int64(bitPattern: tx)])
    }
    // --------------------------------------------------------

    // --- Wi-Fi channel: network name, signal strength, link rate ---
    // Note: since macOS 14 the SSID is only exposed when location access has
    // been granted, while RSSI, link rate and channel are always available —
    // so a nil SSID here is expected, not an error.
    FlutterMethodChannel(
        name: "net_pulse/wifi",
        binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { call, result in
        guard call.method == "getInfo" else {
            result(FlutterMethodNotImplemented); return
        }
        guard let iface = CWWiFiClient.shared().interface(), iface.powerOn() else {
            result(nil) // Wi-Fi is off, or there is no interface (Ethernet)
            return
        }
        var info: [String: Any] = [:]
        if let ssid = iface.ssid() { info["ssid"] = ssid }
        if let name = iface.interfaceName { info["interface"] = name }
        info["rssi"] = iface.rssiValue()
        info["noise"] = iface.noiseMeasurement()
        info["txRate"] = iface.transmitRate()
        if let ch = iface.wlanChannel() { info["channel"] = ch.channelNumber }
        result(info)
    }
    // --------------------------------------------------------

    // --- Menu-bar title that holds still ---
    // tray_manager shows the title in the system font, whose digits differ in
    // width, and lets the item resize with every reading; the menu bar is
    // anchored on the right, so the icon then jumps sideways. The plugin has
    // no setting for this, but its button lives in one of this app's windows
    // and is found there: digits get equal widths, and the item keeps the
    // width of the widest title Dart can produce.
    FlutterMethodChannel(
        name: "net_pulse/tray",
        binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { [weak self] call, result in
        guard call.method == "steadyTitle", let widest = call.arguments as? String else {
            result(FlutterMethodNotImplemented); return
        }
        guard let button = NSApp.windows.lazy
            .compactMap({ statusBarButton(in: $0.contentView) }).first else {
            result(false); return
        }
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        button.font = font
        button.alignment = .left
        button.window?.layoutIfNeeded()
        // The status bar pads the button beyond its text, so the width comes
        // from the laid-out frame, adjusted for the widest text.
        func textWidth(_ text: String) -> CGFloat {
            (text as NSString).size(withAttributes: [.font: font]).width
        }
        let width = ceil(button.frame.width + textWidth(widest) - textWidth(button.title))
        self?.titleWidth?.isActive = false
        let constraint = button.widthAnchor.constraint(greaterThanOrEqualToConstant: width)
        constraint.isActive = true
        self?.titleWidth = constraint
        result(true)
    }
    // --------------------------------------------------------

    // --- Widgets: what they show, and the links they open ---
    // Dart sends the widgets' data as JSON (widget_bridge.dart); it is left
    // where the widget extension can read it, and the widgets are told to
    // redraw.
    FlutterMethodChannel(
        name: "net_pulse/widgets",
        binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { call, result in
        guard call.method == "update", let json = call.arguments as? String else {
            result(FlutterMethodNotImplemented); return
        }
        do {
            try WidgetStore.write(json)
            WidgetCenter.shared.reloadAllTimelines()
            result(true)
        } catch {
            result(FlutterError(code: "write", message: error.localizedDescription, details: nil))
        }
    }

    // --- Metered connections ---
    // The automatic test (auto_test_provider.dart) skips connections macOS
    // calls costly — a phone's hotspot — or Low Data Mode.
    pathMonitor.start(queue: DispatchQueue(label: "net_pulse.path"))
    FlutterMethodChannel(
        name: "net_pulse/network",
        binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "isMetered":
            guard let path = self?.pathMonitor.currentPath else {
                result(nil); return
            }
            result(path.isExpensive || path.isConstrained)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // --- App icons ---
    // The apps card (app_icon.dart) shows each app's own icon, which macOS
    // keeps for every installed app: asked for by the app bundle's path.
    FlutterMethodChannel(
        name: "net_pulse/appicons",
        binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { call, result in
        guard call.method == "icon", let path = call.arguments as? String else {
            result(FlutterMethodNotImplemented); return
        }
        result(AppIcons.png(path: path).map { FlutterStandardTypedData(bytes: $0) })
    }

    // --- In-app updates (Sparkle) ---
    // The update banner's "Update now" opens Sparkle's window: the release
    // notes, then download, signature check, install and restart. Nova
    // checks for new versions on its own (update_provider.dart), so Sparkle
    // never checks unasked.
    FlutterMethodChannel(
        name: "net_pulse/updater",
        binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { [weak self] call, result in
        guard call.method == "checkForUpdates", let updater = self?.updater else {
            result(FlutterMethodNotImplemented); return
        }
        updater.checkForUpdates(nil)
        result(true)
    }

    // "Check for Updates…" in the app menu, where Mac apps keep it. Added
    // once the main menu exists, which the nib may finish after this window.
    DispatchQueue.main.async { [weak self] in
        guard let self, let appMenu = NSApp.mainMenu?.items.first?.submenu else { return }
        let item = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: "")
        item.target = self.updater
        appMenu.insertItem(item, at: 1)
    }

    // A tap on a widget opens a nova:// link; Flutter's app delegate hands
    // it to whoever registered for opened URLs.
    links = NovaLinks(messenger: flutterViewController.engine.binaryMessenger)
    (NSApp.delegate as? FlutterAppDelegate)?.addApplicationLifecycleDelegate(links!)
    // --------------------------------------------------------

    super.awakeFromNib()
  }

  /// Holds the menu-bar item at its widest title's width; see "net_pulse/tray".
  private var titleWidth: NSLayoutConstraint?

  /// Kept here: the app delegate holds its lifecycle delegates weakly.
  private var links: NovaLinks?

  /// Watches the network for the metered check above.
  private let pathMonitor = NWPathMonitor()

  /// Sparkle, reading the feed and key from Info.plist.
  private let updater = SPUStandardUpdaterController(
      startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
}

/// Nova ran in the App Sandbox up to 1.4, which kept its settings, test
/// history and sign-in in a container of its own. Outside the sandbox they
/// are read from the usual place, so the first launch copies them over,
/// once. The container is left as it was, so an older Nova still finds its
/// data there.
enum SandboxMigration {
  private static let doneKey = "nova_left_sandbox"

  static func run() {
    let defaults = UserDefaults.standard
    guard ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil,
          !defaults.bool(forKey: doneKey),
          let id = Bundle.main.bundleIdentifier else { return }
    defer { defaults.set(true, forKey: doneKey) }

    let saved = URL(fileURLWithPath: NSHomeDirectory())
      .appendingPathComponent("Library/Containers/\(id)/Data/Library/Preferences/\(id).plist")
    guard let old = NSDictionary(contentsOf: saved) as? [String: Any],
          old.keys.contains(where: { $0.hasPrefix("flutter.") }) else { return }
    // Whatever is here already came from development builds that ran
    // unsandboxed: the container holds the real data.
    for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("flutter.") {
      defaults.removeObject(forKey: key)
    }
    for (key, value) in old where key.hasPrefix("flutter.") {
      defaults.set(value, forKey: key)
    }
  }
}

/// App icons as PNG, drawn at [side] pixels from what Finder shows.
enum AppIcons {
  static func png(path: String, side: Int = 128) -> Data? {
    guard FileManager.default.fileExists(atPath: path),
          let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { return nil }
    let icon = NSWorkspace.shared.icon(forFile: path)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    icon.draw(in: NSRect(x: 0, y: 0, width: side, height: side),
              from: .zero, operation: .copy, fraction: 1)
    return bitmap.representation(using: .png, properties: [:])
  }
}

/// Where the app leaves what the widgets show. The widget extension runs in a
/// sandbox, so the file can't live in its container: it goes under the real
/// home folder, which the extension's entitlements open, read-only, for
/// this one folder.
enum WidgetStore {
  private static let home: String = {
    if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
      return String(cString: dir)
    }
    return NSHomeDirectory()
  }()

  static func write(_ json: String) throws {
    let folder = URL(fileURLWithPath: home)
      .appendingPathComponent("Library/Application Support/Nova", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data(json.utf8).write(to: folder.appendingPathComponent("widgets.json"), options: .atomic)
    saveIcons(for: json, in: folder.appendingPathComponent("icons", isDirectory: true))
  }

  /// The apps widgets show each app's icon, but can't ask macOS for it from
  /// their sandbox: every app listed ("bundle" → "icon" file name, see
  /// widget_bridge.dart) gets its icon saved next to the JSON, once a week.
  private static func saveIcons(for json: String, in folder: URL) {
    guard let root = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
          let apps = root["apps"] as? [String: Any],
          let list = apps["list"] as? [[String: Any]] else { return }
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
    for app in list {
      guard let bundle = app["bundle"] as? String, let name = app["icon"] as? String,
            !name.contains("/") else { continue }
      let file = folder.appendingPathComponent(name)
      let saved = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate
      if let saved, saved > weekAgo { continue }
      if let png = AppIcons.png(path: bundle, side: 64) {
        try? png.write(to: file, options: .atomic)
      }
    }
  }
}

/// nova:// links from the widgets. A tap can launch Nova, and then the link
/// arrives before Dart is listening, so links wait until Dart asks for them
/// ("take") and go straight through ("open") after that.
final class NovaLinks: NSObject, FlutterAppLifecycleDelegate {
  private let channel: FlutterMethodChannel
  private var pending: [String] = []
  private var dartListening = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "net_pulse/links", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, call.method == "take" else {
        result(FlutterMethodNotImplemented); return
      }
      self.dartListening = true
      result(self.pending)
      self.pending.removeAll()
    }
  }

  @objc(handleOpenURLs:)
  func handleOpen(_ urls: [URL]) -> Bool {
    let ours = urls.filter { $0.scheme == "nova" }
    guard !ours.isEmpty else { return false }
    for url in ours {
      if dartListening {
        channel.invokeMethod("open", arguments: url.absoluteString)
      } else {
        pending.append(url.absoluteString)
      }
    }
    return true
  }
}

/// The menu-bar item's button inside [view], searched depth first.
private func statusBarButton(in view: NSView?) -> NSStatusBarButton? {
  guard let view = view else { return nil }
  if let button = view as? NSStatusBarButton { return button }
  for subview in view.subviews {
    if let found = statusBarButton(in: subview) { return found }
  }
  return nil
}