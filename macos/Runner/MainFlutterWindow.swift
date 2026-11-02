import Cocoa
import CoreWLAN
import FlutterMacOS
import WidgetKit

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
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
}

/// Where the app leaves what the widgets show. The widget extension runs in a
/// sandbox of its own, so the file can't live in either container: it goes
/// under the real home folder, which both sides' entitlements open for this
/// one folder.
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