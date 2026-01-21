import SwiftUI
import AppKit
import os.log

@main
struct PortMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Подавляем системные логи в консоли
        setenv("OS_ACTIVITY_MODE", "disable", 1)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var portMonitor = PortMonitorService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Скрываем иконку в доке
        NSApp.setActivationPolicy(.accessory)

        // Создаём status item в menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Port Monitor")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Создаём popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 480, height: 560)
        popover?.behavior = .transient
        popover?.animates = true

        let contentView = ContentView(portMonitor: portMonitor)
        popover?.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc func togglePopover() {
        if let popover = popover, let button = statusItem?.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                portMonitor.refresh()
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

                // Делаем popover прозрачным
                if let popoverWindow = popover.contentViewController?.view.window {
                    popoverWindow.isOpaque = false
                    popoverWindow.backgroundColor = .clear
                }
            }
        }
    }
}
