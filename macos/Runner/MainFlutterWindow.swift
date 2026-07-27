import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Регистрация плагинов (shared_preferences, window_manager, tray_manager,
    // local_notifier, file_selector). Без этой строки ни один плагин не
    // подключается и его канал падает с MissingPluginException.
    RegisterGeneratedPlugins(registry: flutterViewController)

    // --- Канал связи (MethodChannel) с сетевой картой macOS ---
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

    super.awakeFromNib()
  }
}