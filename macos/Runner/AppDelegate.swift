import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    private var activity: NSObjectProtocol?

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Не закрывать приложение полностью, когда нажата кнопка-крестик
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        // Запрещаем macOS останавливать замеры скорости в фоновом режиме
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Continuous network traffic sampling")
        super.applicationDidFinishLaunching(notification)
    }
}