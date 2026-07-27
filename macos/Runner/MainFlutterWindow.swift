import Cocoa
import CoreWLAN
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

    // --- Канал Wi-Fi: имя сети, уровень сигнала, скорость линка ---
    // Важно: начиная с macOS 14 имя сети (SSID) отдаётся только при выданном
    // доступе к геопозиции, а вот RSSI, скорость линка и канал доступны
    // всегда — поэтому SSID может быть nil, и это нормально.
    FlutterMethodChannel(
        name: "net_pulse/wifi",
        binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { call, result in
        guard call.method == "getInfo" else {
            result(FlutterMethodNotImplemented); return
        }
        guard let iface = CWWiFiClient.shared().interface(), iface.powerOn() else {
            result(nil) // Wi-Fi выключен или интерфейса нет (Ethernet)
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