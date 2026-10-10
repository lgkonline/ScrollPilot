
import SwiftUI
import AppKit
import ServiceManagement
import Carbon.HIToolbox

private struct ProcessResult: Sendable {
    let status: Int32
    let output: String
}

private enum ScrollingSettingsError: Error {
    case readFailed
    case writeFailed
    case activationToolUnavailable
    case activationFailed
}

private struct ScrollingSettingsService: Sendable {
    private static let defaultsPath = "/usr/bin/defaults"
    private static let activationPath =
        "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
    private static let preferenceKey = "com.apple.swipescrolldirection"

    func read() async -> Result<Bool, ScrollingSettingsError> {
        let result = await run(
            Self.defaultsPath,
            ["read", "-g", Self.preferenceKey]
        )

        guard result.status == 0 else {
            return .failure(.readFailed)
        }

        let value = result.output.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return .success(value == "1" || value == "true")
    }

    func setNaturalScrolling(
        _ enabled: Bool
    ) async -> Result<Void, ScrollingSettingsError> {
        let writeResult = await run(
            Self.defaultsPath,
            [
                "write", "-g", Self.preferenceKey,
                "-bool", enabled ? "true" : "false"
            ]
        )

        guard writeResult.status == 0 else {
            return .failure(.writeFailed)
        }

        guard FileManager.default.isExecutableFile(
            atPath: Self.activationPath
        ) else {
            return .failure(.activationToolUnavailable)
        }

        let activationResult = await run(Self.activationPath, ["-u"])
        guard activationResult.status == 0 else {
            return .failure(.activationFailed)
        }

        return .success(())
    }

    private func run(
        _ path: String,
        _ arguments: [String]
    ) async -> ProcessResult {
        await Task.detached(priority: .userInitiated) {
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

                return ProcessResult(
                    status: process.terminationStatus,
                    output: String(decoding: data, as: UTF8.self)
                )
            } catch {
                return ProcessResult(
                    status: -1,
                    output: error.localizedDescription
                )
            }
        }.value
    }
}

@MainActor
final class ScrollPilotController {
    private(set) var naturalScrolling = true
    private(set) var status = String(localized: LocalizedStringResource.readingSetting)
    
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
    
    
    private let inputMonitor = InputDeviceMonitor()
    private let settingsService = ScrollingSettingsService()
    private let automaticSwitchingKey = "automaticSwitchingEnabled"
    private var automaticSwitchingMenuItem: NSMenuItem!
    private var inputMonitoringSettingsMenuItem: NSMenuItem!
    private var operationTask: Task<Void, Never>?
    private var pendingAutomaticValue: Bool?
    private var automaticSwitchingEnabled: Bool {
        get {
            UserDefaults.standard.bool(
                forKey: automaticSwitchingKey
            )
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: automaticSwitchingKey
            )
        }
    }

    init() {
        setupMenuBar()
        refreshSetting()

        if automaticSwitchingEnabled {
            enableAutomaticSwitching(requestAccessIfNeeded: false)
        } else {
            updateAutomaticSwitchingMenuItem()
            updateInputMonitoringMenuItem()
        }
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
        
        
        automaticSwitchingMenuItem = NSMenuItem(
            title: String(
                localized: LocalizedStringResource.switchAutomatically
            ),
            action: #selector(toggleAutomaticSwitching),
            keyEquivalent: ""
        )
        automaticSwitchingMenuItem.target = self
        menu.addItem(automaticSwitchingMenuItem)

        inputMonitoringSettingsMenuItem = NSMenuItem(
            title: String(localized: "Open Input Monitoring Settings…"),
            action: #selector(openInputMonitoringSettings),
            keyEquivalent: ""
        )
        inputMonitoringSettingsMenuItem.target = self
        menu.addItem(inputMonitoringSettingsMenuItem)

        
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
        
        let openOnGitHubItem = NSMenuItem(
            title: String(localized: LocalizedStringResource.openOnGitHub),
            action: #selector(openOnGitHub),
            keyEquivalent: ""
        )
        openOnGitHubItem.target = self
        menu.addItem(openOnGitHubItem)

        let quitItem = NSMenuItem(
            title: String(localized: LocalizedStringResource.quitScrollPilot),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        updateMenuBar()
        updateAutomaticSwitchingMenuItem()
        updateLoginAtLaunchMenuItem()
        statusItem.menu = menu
    }
    
    @objc private func toggleScrollingMenuAction() {
        toggleScrolling()
    }
    
    
    @objc private func toggleAutomaticSwitching() {
        let shouldEnable = !automaticSwitchingEnabled

        if shouldEnable {
            automaticSwitchingEnabled = true
            enableAutomaticSwitching(requestAccessIfNeeded: true)
        } else {
            automaticSwitchingEnabled = false
            inputMonitor.stop()
            updateAutomaticSwitchingMenuItem()
        }
    }

    private func enableAutomaticSwitching(requestAccessIfNeeded: Bool) {
        let authorizationStatus = inputMonitor.authorizationStatus

        guard authorizationStatus == .granted else {
            inputMonitor.stop()

            if authorizationStatus == .unknown && requestAccessIfNeeded {
                inputMonitor.requestAccess()
                status = String(
                    localized: "Grant Input Monitoring access, then restart ScrollPilot."
                )
            } else {
                status = String(localized: "Input Monitoring permission is required.")
            }

            updateMenuBar()
            updateAutomaticSwitchingMenuItem()
            updateInputMonitoringMenuItem()
            return
        }

        let result = inputMonitor.start { [weak self] device in
            Task { @MainActor [weak self] in
                guard let self,
                      self.automaticSwitchingEnabled else {
                    return
                }

                switch device {
                case .magicMouse:
                    self.requestAutomaticSwitch(to: false)

                case .trackpad:
                    self.requestAutomaticSwitch(to: true)
                }
            }
        }

        guard result == kIOReturnSuccess else {
            updateAutomaticSwitchingMenuItem()

            status = String(localized: "Input device monitoring failed.")
            updateMenuBar()
            updateInputMonitoringMenuItem()

            return
        }

        automaticSwitchingEnabled = true
        updateAutomaticSwitchingMenuItem()
        updateInputMonitoringMenuItem()
    }

    private func updateAutomaticSwitchingMenuItem() {
        automaticSwitchingMenuItem?.state =
            automaticSwitchingEnabled ? .on : .off
    }

    private func updateInputMonitoringMenuItem() {
        inputMonitoringSettingsMenuItem?.isHidden =
            inputMonitor.authorizationStatus == .granted
    }

    @objc private func openInputMonitoringSettings() {
        let workspace = NSWorkspace.shared
        let inputMonitoringURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        )
        let privacyURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security"
        )

        if let inputMonitoringURL, workspace.open(inputMonitoringURL) {
            return
        }

        if let privacyURL {
            workspace.open(privacyURL)
        }
    }

    private func requestAutomaticSwitch(to enabled: Bool) {
        guard operationTask == nil else {
            pendingAutomaticValue = enabled
            return
        }

        startOperation {
            await self.setNaturalScrolling(enabled)
        }
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
                updateLoginAtLaunchMenuItem()
                return

            default:
                try service.register()
            }

            updateLoginAtLaunchMenuItem()
        } catch {
            status = String(localized: "Could not update launch at login.")
            updateMenuBar()
            updateLoginAtLaunchMenuItem()
        }
    }

    @objc private func refreshMenuAction() {
        refreshSetting()
    }
    
    @IBAction func openOnGitHub(_ sender: NSMenuItem) {
        if let url = URL(string: "https://github.com/lgkonline/ScrollPilot") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func refreshSetting() {
        startOperation {
            _ = await self.readSetting()
        }
    }


    func toggleScrolling() {
        startOperation {
            guard let currentValue = await self.readSetting() else {
                return
            }

            await self.applyNaturalScrolling(!currentValue)
        }
    }

    private func startOperation(
        _ operation: @escaping @MainActor () async -> Void
    ) {
        guard operationTask == nil else { return }

        operationTask = Task { [weak self] in
            guard let self else { return }
            await operation()

            while let pendingValue = self.pendingAutomaticValue {
                self.pendingAutomaticValue = nil
                await self.setNaturalScrolling(pendingValue)
            }

            self.operationTask = nil
        }
    }

    private func readSetting() async -> Bool? {
        switch await settingsService.read() {
        case .success(let value):
            updateDisplayedSetting(value)
            return value

        case .failure:
            status = String(
                localized: LocalizedStringResource.couldNotReadSetting
            )
            updateMenuBar()
            return nil
        }
    }

    private func setNaturalScrolling(_ enabled: Bool) async {
        guard let currentValue = await readSetting(),
              currentValue != enabled else {
            return
        }

        await applyNaturalScrolling(enabled)
    }

    private func applyNaturalScrolling(_ newValue: Bool) async {
        switch await settingsService.setNaturalScrolling(newValue) {
        case .success:
            updateDisplayedSetting(newValue)

        case .failure(.writeFailed):
            status = String(localized: "Could not save setting.")
            updateMenuBar()

        case .failure(.activationToolUnavailable):
            status = String(
                localized: "The system tool required to apply the setting is unavailable."
            )
            await refreshStoredValuePreservingStatus()
            updateMenuBar()

        case .failure(.activationFailed):
            status = String(
                localized:
                    LocalizedStringResource.savedButApplyingTheSettingFailed
            )
            await refreshStoredValuePreservingStatus()
            updateMenuBar()

        case .failure(.readFailed):
            break
        }
    }

    private func refreshStoredValuePreservingStatus() async {
        if case .success(let value) = await settingsService.read() {
            naturalScrolling = value
        }
    }

    private func updateDisplayedSetting(_ value: Bool) {
        naturalScrolling = value
        status = value
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
                accessibilityDescription: "ScrollPilot"
            )
            button.setAccessibilityValue(status)
        }

        statusMenuItem.title = status
    }

    func reportHotKeyRegistrationFailure() {
        status = String(
            localized: "Global shortcut could not be registered."
        )
        updateMenuBar()
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
        do {
            globalHotKey = try GlobalHotKey { [weak self] in
                self?.controller?.toggleScrolling()
            }
        } catch {
            controller?.reportHotKeyRegistrationFailure()
        }
    }
}


final class GlobalHotKey {
    enum RegistrationError: Error {
        case eventHandler(OSStatus)
        case hotKey(OSStatus)
    }

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onPress: () -> Void

    init(onPress: @escaping () -> Void) throws {
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
            throw RegistrationError.eventHandler(handlerStatus)
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
            if let eventHandler {
                RemoveEventHandler(eventHandler)
                self.eventHandler = nil
            }
            throw RegistrationError.hotKey(hotKeyStatus)
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
