import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, 
            defer: false
        )
        window.center()
        window.title = "Foreign Affairs Reader"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        
        // Set window content view hosting the SwiftUI ContentView
        let contentView = ContentView()
        window.contentView = NSHostingView(rootView: contentView)
        
        window.makeKeyAndOrderFront(nil)
        window.delegate = self
        
        // Enable system menus
        setupMenu()
        
        // Bring application to focus
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func setupMenu() {
        let mainMenu = NSMenu()
        
        // App Menu Item
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        // Basic quit item
        let quitItem = NSMenuItem(
            title: "Quit Foreign Affairs Reader",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        
        // View Menu Item
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        
        // Standard full-screen item
        let fullScreenItem = NSMenuItem(
            title: "Toggle Full Screen",
            action: #selector(NSWindow.toggleFullScreen(_:)),
            keyEquivalent: "f"
        )
        fullScreenItem.keyEquivalentModifierMask = [.control, .command]
        viewMenu.addItem(fullScreenItem)
        
        NSApp.mainMenu = mainMenu
    }
}

// Programmatic Main Execution
@main
struct ForeignAffairsReaderApp {
    static var delegate = AppDelegate()
    
    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

