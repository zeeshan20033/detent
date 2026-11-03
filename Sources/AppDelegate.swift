import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let state = AppState.shared
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diag.reset()
        Diag.log("bundle=\(Bundle.main.bundlePath)")
        Diag.log("accessibility trusted at launch = \(AXIsProcessTrusted())")

        buildStatusItem()
        state.start()

        // Keep the menu-bar icon in step with whatever the window is showing.
        state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateStatusIcon() }
            .store(in: &cancellables)

        if state.accessibilityGranted {
            showWindow()
        } else {
            state.requestAccessibility()
            showWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.monitor.stop()
    }

    // MARK: Window

    @objc func showWindow() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(state: state))
            let w = NSWindow(contentViewController: hosting)
            w.title = "Detent"
            w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Status item

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Detent")
            image?.isTemplate = true
            button.image = image
            if image == nil { button.title = "◍" }
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateStatusIcon()
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        let live = state.active && state.accessibilityGranted
        button.appearsDisabled = !live
        button.toolTip = live
            ? "Detent — clicking"
            : (state.accessibilityGranted ? "Detent — paused"
                                          : "Detent — needs Accessibility access")
    }

    // MARK: Menu

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        if !state.accessibilityGranted {
            let warn = NSMenuItem(title: "Needs Accessibility access…",
                                  action: #selector(grantAccess), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
            menu.addItem(.separator())
        }

        let toggle = NSMenuItem(title: state.active ? "Pause Clicking" : "Resume Clicking",
                                action: #selector(toggleActive), keyEquivalent: "")
        toggle.target = self
        toggle.isEnabled = state.accessibilityGranted
        menu.addItem(toggle)

        let open = NSMenuItem(title: "Open Detent…",
                              action: #selector(showWindow), keyEquivalent: ",")
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Detent", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func toggleActive() {
        state.active.toggle()
        updateStatusIcon()
    }

    @objc private func grantAccess() {
        state.requestAccessibility()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
