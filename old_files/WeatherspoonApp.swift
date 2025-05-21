import SwiftUI
import Combine
import CoreLocation
import Foundation

@main
struct WeatherspoonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem?
    private var weatherController: WeatherController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        weatherController = WeatherController(statusItem: statusItem!)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        weatherController?.cleanup()
    }
}
