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

    super.awakeFromNib()
  }
}