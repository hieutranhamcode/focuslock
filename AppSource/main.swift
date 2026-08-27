// FocusLock — menu bar companion for Deskflow
//
// Watches configured apps/games; when one becomes frontmost, sends the LOCK
// key (default F14); when none are active anymore, sends the UNLOCK key
// (default F15). Deskflow is configured to bind those keys to
// switchToScreen + lockCursorToScreen(on/off).
//
// Add/remove watched apps entirely from the menu, no rebuild required, so
// Accessibility / Input Monitoring only need to be granted once.

import Cocoa
import ServiceManagement

// MARK: - Config model

struct GameEntry: Codable, Equatable {
    let bundleID: String
    let name: String
}

struct AppConfig: Codable {
    var games: [GameEntry]
    var lockKeyCode: Int
    var unlockKeyCode: Int

    static let `default` = AppConfig(
        games: [GameEntry(bundleID: "com.riotgames.LeagueofLegends.GameClient", name: "League of Legends")],
        lockKeyCode: 107, // F14
        unlockKeyCode: 113 // F15
    )
}

final class ConfigStore {
    static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("FocusLock", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // Previous product names, kept only so upgrades carry the old game list over.
    private static let legacyConfigURLs: [URL] = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ["DeskflowGuard", "LeagueLockWatcher"].map {
            base.appendingPathComponent($0, isDirectory: true).appendingPathComponent("config.json")
        }
    }()

    static let configURL = appSupportDir.appendingPathComponent("config.json")
    static let logURL = appSupportDir.appendingPathComponent("watcher.log")

    static func load() -> AppConfig {
        if let data = try? Data(contentsOf: configURL),
           let config = try? JSONDecoder().decode(AppConfig.self, from: data) {
            return config
        }
        for legacyURL in legacyConfigURLs {
            if let legacyData = try? Data(contentsOf: legacyURL),
               let legacyConfig = try? JSONDecoder().decode(AppConfig.self, from: legacyData) {
                save(legacyConfig)
                return legacyConfig
            }
        }
        save(.default)
        return .default
    }

    static func save(_ config: AppConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: configURL, options: .atomic)
    }
}

func appLog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    print(line, terminator: "")
    if let handle = try? FileHandle(forWritingTo: ConfigStore.logURL) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        try? handle.close()
    } else {
        try? line.write(to: ConfigStore.logURL, atomically: true, encoding: .utf8)
    }
}

// MARK: - Deskflow auto-configurator
//
// Edits ~/Library/Deskflow/Deskflow.conf directly to assign the LOCK/UNLOCK
// hotkeys, skipping the "record hotkey by pressing the real key" step in the
// Deskflow GUI (some wireless keyboards send F13+ via a HID path that
// Deskflow's hotkey recorder doesn't pick up, even though synthetic key
// events still work fine). The file is a flat Qt INI: "hotkeys\1\actions\1\type=3".

enum DeskflowConfigError: LocalizedError {
    case fileNotFound
    case missingComputerName
    case unsupportedKeyCode(Int)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Couldn't find ~/Library/Deskflow/Deskflow.conf. Open Deskflow at least once first."
        case .missingComputerName:
            return "Couldn't read the computer name (computerName) from Deskflow.conf."
        case .unsupportedKeyCode(let code):
            return "Key code \(code) isn't supported for Deskflow auto-configuration (F1–F20 only)."
        }
    }
}

enum DeskflowConfigurator {
    static let configURL = URL(fileURLWithPath: NSString(string: "~/Library/Deskflow/Deskflow.conf").expandingTildeInPath)
    static let backupURL = URL(fileURLWithPath: NSString(string: "~/Library/Deskflow/Deskflow.conf.focuslock-backup").expandingTildeInPath)

    // CGKeyCode -> F number, using macOS's standard virtual keycode table.
    private static let fNumberByCGKeyCode: [Int: Int] = [
        122: 1, 120: 2, 99: 3, 118: 4, 96: 5, 97: 6, 98: 7, 100: 8, 101: 9, 109: 10, 103: 11, 111: 12,
        105: 13, 107: 14, 113: 15, 106: 16, 64: 17, 79: 18, 80: 19, 90: 20,
    ]

    static func fName(forCGKeyCode code: Int) -> String {
        if let n = fNumberByCGKeyCode[code] { return "F\(n)" }
        return "keycode \(code)"
    }

    // Qt::Key_F1 == 0x01000030 (16777264); the following F keys increment by 1.
    private static func qtKeyCode(forCGKeyCode code: Int) throws -> Int {
        guard let n = fNumberByCGKeyCode[code] else { throw DeskflowConfigError.unsupportedKeyCode(code) }
        return 16777264 + (n - 1)
    }

    private static func parseLine(_ line: String) -> (path: [String], value: String)? {
        guard let eqIdx = line.firstIndex(of: "=") else { return nil }
        let keyPath = String(line[line.startIndex..<eqIdx])
        let value = String(line[line.index(after: eqIdx)...])
        guard keyPath.hasPrefix("hotkeys\\") || keyPath == "computerName" else { return nil }
        return (keyPath.components(separatedBy: "\\"), value)
    }

    private static func findActionIndex(_ lines: [String], hotkey: Int, type: Int) -> Int? {
        for line in lines {
            guard let (path, value) = parseLine(line), path.count == 5,
                  path[0] == "hotkeys", path[1] == "\(hotkey)", path[2] == "actions", path[4] == "type",
                  value == "\(type)" else { continue }
            return Int(path[3])
        }
        return nil
    }

    private static func lockOnBlock(hotkeyIndex hk: Int, screenName: String, qtKey: Int) -> [String] {
        let p = "hotkeys\\\(hk)"
        return [
            "\(p)\\actions\\1\\activeOnRelease=false",
            "\(p)\\actions\\1\\hasScreens=true",
            "\(p)\\actions\\1\\keys\\size=0",
            "\(p)\\actions\\1\\lockCursorToScreen=0",
            "\(p)\\actions\\1\\restartServer=false",
            "\(p)\\actions\\1\\switchInDirection=0",
            "\(p)\\actions\\1\\switchScreenName=\(screenName)",
            "\(p)\\actions\\1\\type=3",
            "\(p)\\actions\\1\\typeScreenNames\\size=0",
            "\(p)\\actions\\2\\activeOnRelease=false",
            "\(p)\\actions\\2\\hasScreens=true",
            "\(p)\\actions\\2\\keys\\size=0",
            "\(p)\\actions\\2\\lockCursorToScreen=1",
            "\(p)\\actions\\2\\restartServer=false",
            "\(p)\\actions\\2\\switchInDirection=0",
            "\(p)\\actions\\2\\switchScreenName=\(screenName)",
            "\(p)\\actions\\2\\type=6",
            "\(p)\\actions\\2\\typeScreenNames\\size=0",
            "\(p)\\actions\\size=2",
            "\(p)\\keys\\1\\key=\(qtKey)",
            "\(p)\\keys\\size=1",
        ]
    }

    private static func lockOffBlock(hotkeyIndex hk: Int, screenName: String, qtKey: Int) -> [String] {
        let p = "hotkeys\\\(hk)"
        return [
            "\(p)\\actions\\1\\activeOnRelease=false",
            "\(p)\\actions\\1\\hasScreens=true",
            "\(p)\\actions\\1\\keys\\size=0",
            "\(p)\\actions\\1\\lockCursorToScreen=2",
            "\(p)\\actions\\1\\restartServer=false",
            "\(p)\\actions\\1\\switchInDirection=0",
            "\(p)\\actions\\1\\switchScreenName=\(screenName)",
            "\(p)\\actions\\1\\type=6",
            "\(p)\\actions\\1\\typeScreenNames\\size=0",
            "\(p)\\actions\\size=1",
            "\(p)\\keys\\1\\key=\(qtKey)",
            "\(p)\\keys\\size=1",
        ]
    }

    /// Updates (or creates, if missing) the 2 LOCK/UNLOCK hotkeys in Deskflow.conf.
    /// Returns a short summary message for the user.
    static func apply(lockKeyCode: Int, unlockKeyCode: Int) throws -> String {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw DeskflowConfigError.fileNotFound
        }
        let lockQt = try qtKeyCode(forCGKeyCode: lockKeyCode)
        let unlockQt = try qtKeyCode(forCGKeyCode: unlockKeyCode)

        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.copyItem(at: configURL, to: backupURL)

        var lines = try String(contentsOf: configURL, encoding: .utf8).components(separatedBy: "\n")

        guard let computerName = lines.compactMap({ parseLine($0) }).first(where: { $0.path == ["computerName"] })?.value,
              !computerName.isEmpty else {
            throw DeskflowConfigError.missingComputerName
        }

        var hotkeyActionTypes: [Int: Set<Int>] = [:]
        for line in lines {
            guard let (path, value) = parseLine(line), path.count == 5,
                  path[0] == "hotkeys", path[2] == "actions", path[4] == "type",
                  let hk = Int(path[1]), let type = Int(value) else { continue }
            hotkeyActionTypes[hk, default: []].insert(type)
        }

        var lockHotkeyIndex: Int?
        var unlockHotkeyIndex: Int?
        for (hk, types) in hotkeyActionTypes where types.contains(6) {
            if types.contains(3) {
                lockHotkeyIndex = hk
            } else {
                unlockHotkeyIndex = hk
            }
        }

        func replaceLine(prefix: String, newValue: String) {
            if let idx = lines.firstIndex(where: { $0.hasPrefix(prefix) }) {
                lines[idx] = prefix + newValue
            }
        }

        if let lockIdx = lockHotkeyIndex {
            replaceLine(prefix: "hotkeys\\\(lockIdx)\\keys\\1\\key=", newValue: "\(lockQt)")
            if let switchIdx = findActionIndex(lines, hotkey: lockIdx, type: 3) {
                replaceLine(prefix: "hotkeys\\\(lockIdx)\\actions\\\(switchIdx)\\switchScreenName=", newValue: computerName)
            }
        }
        if let unlockIdx = unlockHotkeyIndex {
            replaceLine(prefix: "hotkeys\\\(unlockIdx)\\keys\\1\\key=", newValue: "\(unlockQt)")
        }

        if lockHotkeyIndex == nil || unlockHotkeyIndex == nil {
            var currentSize = hotkeyActionTypes.keys.max() ?? 0
            for line in lines {
                if let (path, value) = parseLine(line), path == ["hotkeys", "size"], let v = Int(value) {
                    currentSize = max(currentSize, v)
                }
            }
            var nextIndex = currentSize + 1
            var appended: [String] = []

            if lockHotkeyIndex == nil {
                appended += lockOnBlock(hotkeyIndex: nextIndex, screenName: computerName, qtKey: lockQt)
                lockHotkeyIndex = nextIndex
                nextIndex += 1
            }
            if unlockHotkeyIndex == nil {
                appended += lockOffBlock(hotkeyIndex: nextIndex, screenName: computerName, qtKey: unlockQt)
                unlockHotkeyIndex = nextIndex
                nextIndex += 1
            }

            let newSize = nextIndex - 1
            if let sizeIdx = lines.firstIndex(where: { $0.hasPrefix("hotkeys\\size=") }) {
                lines[sizeIdx] = "hotkeys\\size=\(newSize)"
            } else {
                appended.append("hotkeys\\size=\(newSize)")
            }
            lines.append(contentsOf: appended)
        }

        try lines.joined(separator: "\n").write(to: configURL, atomically: true, encoding: .utf8)

        return "Assigned LOCK=\(fName(forCGKeyCode: lockKeyCode)) (switch to \(computerName) + lock on), UNLOCK=\(fName(forCGKeyCode: unlockKeyCode)) (lock off) in Deskflow.conf."
    }

    static func killDeskflow() {
        for pattern in ["Deskflow.app/Contents/MacOS/Deskflow", "deskflow-core"] {
            let task = Process()
            task.launchPath = "/usr/bin/pkill"
            task.arguments = ["-f", pattern]
            try? task.run()
            task.waitUntilExit()
        }
    }

    static func relaunchDeskflow() {
        let url = URL(fileURLWithPath: "/Applications/Deskflow.app")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Key posting

func postKey(_ keyCode: CGKeyCode) {
    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
          let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
        appLog("ERROR: failed to create CGEvent for keyCode \(keyCode)")
        return
    }
    down.post(tap: .cghidEventTap)
    usleep(30_000)
    up.post(tap: .cghidEventTap)
}

// MARK: - Status bar icon
//
// Custom monochrome glyph: a padlock (closed when locked, open when
// unlocked) with a mouse-cursor arrow silhouette cut out of its body, so the
// icon reads as "the pointer is locked/unlocked", instead of a generic lock.
// Built by compositing two SF Symbols (crisp at menu-bar sizes, adapts to
// light/dark automatically via isTemplate) rather than hand-drawn bezier
// paths.

func makeStatusIcon(locked: Bool) -> NSImage? {
    let canvasSize = NSSize(width: 20, height: 18)

    guard let lockBase = NSImage(systemSymbolName: locked ? "lock.fill" : "lock.open.fill", accessibilityDescription: nil),
          let cursorBase = NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: nil) else {
        return nil
    }

    let lockConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
    let cursorConfig = NSImage.SymbolConfiguration(pointSize: 7, weight: .black)
    guard let lockImg = lockBase.withSymbolConfiguration(lockConfig),
          let cursorImg = cursorBase.withSymbolConfiguration(cursorConfig) else {
        return nil
    }
    lockImg.isTemplate = true
    cursorImg.isTemplate = true

    let result = NSImage(size: canvasSize)
    result.lockFocus()

    let lockRect = NSRect(
        x: (canvasSize.width - lockImg.size.width) / 2,
        y: (canvasSize.height - lockImg.size.height) / 2 + (locked ? 0 : 1),
        width: lockImg.size.width,
        height: lockImg.size.height
    )
    lockImg.draw(in: lockRect, from: .zero, operation: .sourceOver, fraction: 1.0)

    let cursorRect = NSRect(
        x: (canvasSize.width - cursorImg.size.width) / 2 + 0.5,
        y: lockRect.minY + lockRect.height * (locked ? 0.06 : 0.16),
        width: cursorImg.size.width,
        height: cursorImg.size.height
    )
    cursorImg.draw(in: cursorRect, from: .zero, operation: .destinationOut, fraction: 1.0)

    result.unlockFocus()
    result.isTemplate = true
    return result
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var config = ConfigStore.load()
    var locked = false
    var pendingWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateStatusIcon()
        rebuildMenu()

        let nc = NSWorkspace.shared.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didDeactivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ]
        for name in names {
            nc.addObserver(self, selector: #selector(handleWorkspaceNotification), name: name, object: nil)
        }

        appLog("FocusLock started. Watching \(config.games.count) app(s): \(config.games.map { $0.name }.joined(separator: ", "))")
        scheduleSync()
    }

    @objc func handleWorkspaceNotification(_ note: Notification) {
        scheduleSync()
    }

    func frontmostMatchedGame() -> GameEntry? {
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return nil }
        return config.games.first { $0.bundleID == id }
    }

    func scheduleSync() {
        pendingWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let matched = self.frontmostMatchedGame()
            self.setLock(matched != nil, matchedGame: matched)
        }
        pendingWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: item)
    }

    func setLock(_ shouldLock: Bool, matchedGame: GameEntry?) {
        guard shouldLock != locked else { return }
        postKey(CGKeyCode(shouldLock ? config.lockKeyCode : config.unlockKeyCode))
        locked = shouldLock
        appLog(shouldLock ? "LOCKED (app: \(matchedGame?.name ?? "?"))" : "UNLOCKED")
        updateStatusIcon()
        rebuildMenu()
    }

    func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        if let icon = makeStatusIcon(locked: locked) {
            button.image = icon
        } else {
            let image = NSImage(systemSymbolName: locked ? "lock.fill" : "lock.open.fill", accessibilityDescription: "FocusLock")
            image?.isTemplate = true
            button.image = image
        }
    }

    // MARK: Menu

    /// Small template SF Symbol for use as a menu item's icon (renders natively,
    /// no emoji, adapts to light/dark and selection highlight automatically).
    private func menuIcon(_ symbolName: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: "FocusLock", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        let status = NSMenuItem(title: locked ? "Status: Locked" : "Status: Unlocked", action: nil, keyEquivalent: "")
        status.isEnabled = false
        status.image = menuIcon(locked ? "lock.fill" : "lock.open.fill")
        menu.addItem(status)

        menu.addItem(.separator())

        let header = NSMenuItem(title: "Focus Apps:", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if config.games.isEmpty {
            let empty = NSMenuItem(title: "None yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for game in config.games {
                let item = NSMenuItem(title: game.name, action: #selector(removeGame(_:)), keyEquivalent: "")
                item.target = self
                item.image = menuIcon("xmark.circle")
                item.representedObject = game.bundleID
                item.toolTip = "Click to stop watching \(game.name) (\(game.bundleID))"
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let addFromApps = NSMenuItem(title: "Add App from Applications...", action: #selector(addGameFromApplications), keyEquivalent: "")
        addFromApps.target = self
        addFromApps.image = menuIcon("plus.app")
        menu.addItem(addFromApps)

        let runningMenu = NSMenu()
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        if runningApps.isEmpty {
            let empty = NSMenuItem(title: "No running apps", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            runningMenu.addItem(empty)
        } else {
            for app in runningApps {
                guard let bundleID = app.bundleIdentifier else { continue }
                let name = app.localizedName ?? bundleID
                let alreadyAdded = config.games.contains { $0.bundleID == bundleID }
                let item = NSMenuItem(title: name, action: alreadyAdded ? nil : #selector(addRunningApp(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = GameEntry(bundleID: bundleID, name: name)
                item.isEnabled = !alreadyAdded
                if alreadyAdded {
                    item.image = menuIcon("checkmark")
                }
                runningMenu.addItem(item)
            }
        }
        let addFromRunning = NSMenuItem(title: "Add Running App", action: nil, keyEquivalent: "")
        addFromRunning.image = menuIcon("list.bullet.rectangle")
        addFromRunning.submenu = runningMenu
        menu.addItem(addFromRunning)

        menu.addItem(.separator())

        let autoConfig = NSMenuItem(title: "Auto-Configure Deskflow Hotkeys", action: #selector(autoConfigureDeskflow), keyEquivalent: "")
        autoConfig.target = self
        autoConfig.image = menuIcon("gearshape")
        menu.addItem(autoConfig)

        menu.addItem(.separator())

        let loginEnabled = SMAppService.mainApp.status == .enabled
        let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.image = menuIcon(loginEnabled ? "checkmark.circle.fill" : "circle")
        menu.addItem(loginItem)

        let openLog = NSMenuItem(title: "View Log...", action: #selector(revealLog), keyEquivalent: "")
        openLog.target = self
        openLog.image = menuIcon("doc.text.magnifyingglass")
        menu.addItem(openLog)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit FocusLock", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: Actions

    @objc func removeGame(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        config.games.removeAll { $0.bundleID == bundleID }
        ConfigStore.save(config)
        appLog("Stopped watching: \(bundleID)")
        rebuildMenu()
    }

    @objc func addGameFromApplications() {
        let panel = NSOpenPanel()
        panel.title = "Choose an app to watch"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else {
            let alert = NSAlert()
            alert.messageText = "Couldn't read Bundle ID"
            alert.informativeText = "This file might not be a valid app."
            alert.runModal()
            return
        }
        let name = (bundle.infoDictionary?["CFBundleName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        addGame(GameEntry(bundleID: bundleID, name: name))
    }

    @objc func addRunningApp(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? GameEntry else { return }
        addGame(entry)
    }

    func addGame(_ entry: GameEntry) {
        guard !config.games.contains(where: { $0.bundleID == entry.bundleID }) else { return }
        config.games.append(entry)
        ConfigStore.save(config)
        appLog("Added app: \(entry.name) (\(entry.bundleID))")
        rebuildMenu()
        scheduleSync()
    }

    @objc func testLock() {
        appLog("TEST: forcing LOCK")
        locked = false
        setLock(true, matchedGame: GameEntry(bundleID: "test", name: "TEST"))
    }

    @objc func testUnlock() {
        appLog("TEST: forcing UNLOCK")
        locked = true
        setLock(false, matchedGame: nil)
    }

    @objc func autoConfigureDeskflow() {
        let alert = NSAlert()
        alert.messageText = "Auto-configure Deskflow hotkeys?"
        alert.informativeText = """
        This will quit Deskflow, edit Deskflow.conf to assign:
          • LOCK = \(DeskflowConfigurator.fName(forCGKeyCode: config.lockKeyCode))
          • UNLOCK = \(DeskflowConfigurator.fName(forCGKeyCode: config.unlockKeyCode))
        then relaunch Deskflow. The original file is backed up first (Deskflow.conf.focuslock-backup).
        """
        alert.addButton(withTitle: "Proceed")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let lockCode = config.lockKeyCode
        let unlockCode = config.unlockKeyCode

        DispatchQueue.global(qos: .userInitiated).async {
            DeskflowConfigurator.killDeskflow()
            Thread.sleep(forTimeInterval: 1.0)

            var resultMessage: String
            do {
                resultMessage = try DeskflowConfigurator.apply(lockKeyCode: lockCode, unlockKeyCode: unlockCode)
            } catch {
                resultMessage = "Error: \(error.localizedDescription)"
            }

            Thread.sleep(forTimeInterval: 0.5)
            DeskflowConfigurator.relaunchDeskflow()

            DispatchQueue.main.async {
                appLog("DeskflowConfigurator: \(resultMessage)")
                let done = NSAlert()
                done.messageText = "Done"
                done.informativeText = resultMessage
                NSApp.activate(ignoringOtherApps: true)
                done.runModal()
            }
        }
    }

    @objc func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            appLog("ERROR toggling login item: \(error.localizedDescription)")
        }
        rebuildMenu()
    }

    @objc func revealLog() {
        NSWorkspace.shared.activateFileViewerSelecting([ConfigStore.logURL])
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
