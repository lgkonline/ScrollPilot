
import SwiftUI
import AppKit
import Combine
import ServiceManagement
import Carbon.HIToolbox

@MainActor
final class ScrollPilotController: ObservableObject {
    @Published var naturalScrolling = true
    @Published var status = String(localized: LocalizedStringResource.readingSetting)
    
    private let naturalScrollIcon = "rectangle.and.hand.point.up.left.filled"
    private let unnaturalScrollIcon = "magicmouse.fill"

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    private let statusMenuItem = NSMenuItem(
        title: String(localized: LocalizedStringResource.readingSetting),
        action: nil,
        keyEquivalent: ""
    )
    
    private var launchAtLoginMenuItem: NSMenuItem!

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

            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(
            title: String(localized: LocalizedStringResource.toggleNaturalScrolling),
            action: #selector(toggleScrollingMenuAction),
            keyEquivalent: "s"
        )
        toggleItem.target = self
        toggleItem.keyEquivalentModifierMask = [.control, .option]
        menu.addItem(toggleItem)
        
        launchAtLoginMenuItem = NSMenuItem(
            title: String(localized: LocalizedStringResource.launchAtLogin),
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem.target = self
        menu.addItem(launchAtLoginMenuItem)
        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(
            title: String(localized: LocalizedStringResource.reloadSetting),
            action: #selector(refreshMenuAction),
            keyEquivalent: ""
        )
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: String(localized: LocalizedStringResource.quitScrollPilot),
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
    
    @objc private func toggleScrollingMenuAction() {
        toggleScrolling()
    }
    
    private func updateLoginAtLaunchMenuItem() {
        launchAtLoginMenuItem?.state =
            SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp

        do {
            switch service.status {
            case .enabled:
                try service.unregister()

            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
                return

            default:
                try service.register()
            }

            updateLoginAtLaunchMenuItem()
        } catch {
            status = "Automatischer Start fehlgeschlagen: \(error.localizedDescription)"
            updateMenuBar()
            updateLoginAtLaunchMenuItem()
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
            status = String(localized: LocalizedStringResource.couldNotReadSetting)
            updateMenuBar()
            return
        }

        let value = result.output.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        naturalScrolling = (value == "1" || value == "true")
        status = naturalScrolling
            ? String(localized: LocalizedStringResource.naturalScrollingIsOn)
            : String(localized: LocalizedStringResource.naturalScrollingIsOff)

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
            status = String(localized: LocalizedStringResource.savedButApplyingTheSettingFailed)
            refreshSetting()
            return
        }

        naturalScrolling = newValue
        status = newValue
        ? String(localized: LocalizedStringResource.naturalScrollingIsOn)
        : String(localized: LocalizedStringResource.naturalScrollingIsOff)

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
    private var globalHotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = ScrollPilotController()
        globalHotKey = GlobalHotKey { [weak self] in
            self?.controller?.toggleScrolling()
        }
    }
}


final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onPress: () -> Void

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()

                let result = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard result == noErr, hotKeyID.id == 1 else {
                    return noErr
                }

                let hotKey = Unmanaged<GlobalHotKey>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                DispatchQueue.main.async {
                    hotKey.onPress()
                }

                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard handlerStatus == noErr else {
            print("ScrollPilot: Event-Handler konnte nicht installiert werden.")
            return
        }

        let hotKeyID = EventHotKeyID(
            signature: OSType(0x53435250), // "SCRP"
            id: 1
        )

        let modifiers = UInt32(controlKey | optionKey)

        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if hotKeyStatus != noErr {
            print("ScrollPilot: Shortcut konnte nicht registriert werden. Code: \(hotKeyStatus)")
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
