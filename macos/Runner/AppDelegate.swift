import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    private var activity: NSObjectProtocol?

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Don't quit the app when the close button is pressed
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        // Stop macOS from suspending our measurements in the background
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Continuous network traffic sampling")
        super.applicationDidFinishLaunching(notification)
    }
}