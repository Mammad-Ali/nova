import Cocoa
import CoreWLAN
import FlutterMacOS

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

    super.awakeFromNib()
  }

  /// Holds the menu-bar item at its widest title's width; see "net_pulse/tray".
  private var titleWidth: NSLayoutConstraint?
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