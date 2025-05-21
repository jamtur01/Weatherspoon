import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        menuBarController.cleanup()
    }
}
