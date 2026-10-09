
import SwiftUI
import AppKit
import Combine

@MainActor
final class ScrollPilotController: ObservableObject {
    @Published var naturalScrolling = true
    @Published var status = "Einstellung wird gelesen …"
    
    private let naturalScrollIcon = "rectangle.and.hand.point.up.left.filled"
    private let unnaturalScrollIcon = "magicmouse.fill"

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    private let statusMenuItem = NSMenuItem(
        title: "Status wird gelesen …",
        action: nil,
        keyEquivalent: ""
    )

    init() {
        refreshSetting()
        setupMenuBar()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: naturalScrollIcon,
                accessibilityDescription: "ScrollPilot"
            )
            button.target = self
            button.action = #selector(handleClick(_:))

            // Linksklick schaltet um, Rechtsklick öffnet das Menü.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(
            title: "Einstellung neu einlesen",
            action: #selector(refreshMenuAction),
            keyEquivalent: ""
        )
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "ScrollPilot beenden",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        updateMenuBar()
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggleScrolling()
        }
    }

    @objc private func refreshMenuAction() {
        refreshSetting()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func refreshSetting() {
        let result = run(
            "/usr/bin/defaults",
            ["read", "-g", "com.apple.swipescrolldirection"]
        )

        guard result.status == 0 else {
            status = "Einstellung konnte nicht gelesen werden."
            updateMenuBar()
            return
        }

        let value = result.output.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        naturalScrolling = (value == "1" || value == "true")
        status = naturalScrolling
            ? "Natürliches Scrollen ist eingeschaltet."
            : "Natürliches Scrollen ist ausgeschaltet."

        updateMenuBar()
    }

    func toggleScrolling() {
        let newValue = !naturalScrolling

        let writeResult = run(
            "/usr/bin/defaults",
            [
                "write", "-g",
                "com.apple.swipescrolldirection",
                "-bool", newValue ? "true" : "false"
            ]
        )

        guard writeResult.status == 0 else {
            status = "Schreibfehler: \(writeResult.output)"
            updateMenuBar()
            return
        }

        let activationResult = run(
            "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings",
            ["-u"]
        )

        guard activationResult.status == 0 else {
            status = "Gespeichert, Aktualisierung fehlgeschlagen."
            refreshSetting()
            return
        }

        naturalScrolling = newValue
        status = newValue
            ? "Natürliches Scrollen aktiviert."
            : "Natürliches Scrollen deaktiviert."

        updateMenuBar()
    }

    private func updateMenuBar() {
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: naturalScrolling
                    ? naturalScrollIcon
                    : unnaturalScrollIcon,
                accessibilityDescription: status
            )
        }

        statusMenuItem.title = status
    }

    private func run(
        _ path: String,
        _ arguments: [String]
    ) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            return (
                process.terminationStatus,
                String(decoding: data, as: UTF8.self)
            )
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}

@main
struct ScrollPilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: ScrollPilotController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = ScrollPilotController()
    }
}
