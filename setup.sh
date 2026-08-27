#!/bin/bash
# FocusLock installer — chạy script này trên máy Mac mới.
# Cách dùng:
#   chmod +x setup.sh
#   ./setup.sh                                                     # mặc định: chỉ theo dõi LMHT, phím F14/F15
#   ./setup.sh "id1,id2,id3" 107 113                                # theo dõi nhiều game cùng lúc
#
# Ví dụ nhiều game (LMHT + Valorant):
#   ./setup.sh "com.riotgames.LeagueofLegends.GameClient,com.riotgames.valorant" 107 113
#
# Tham số (tùy chọn):
#   $1 = Danh sách Bundle ID các game cần theo dõi, cách nhau bởi dấu phẩy (mặc định: LMHT)
#   $2 = CGKeyCode dùng để LOCK   (mặc định: 107 = F14)
#   $3 = CGKeyCode dùng để UNLOCK (mặc định: 113 = F15)
#
# Bảng CGKeyCode các phím F hay dùng (để tránh trùng phím hệ thống F1-F12):
#   F13=105  F14=107  F15=113  F16=106  F17=64  F18=79  F19=80  F20=90
#
# Chỉ dùng 1 cặp phím LOCK/UNLOCK chung cho mọi game trong danh sách — hễ 1 trong các
# game đó đang là ứng dụng active thì tự LOCK, thoát ra hết thì tự UNLOCK.

set -e

GAME_BUNDLE_IDS_RAW="${1:-com.riotgames.LeagueofLegends.GameClient}"
LOCK_KEYCODE="${2:-107}"
UNLOCK_KEYCODE="${3:-113}"

APP_DIR="$HOME/Library/Application Support/FocusLock-CLI"
PLIST_PATH="$HOME/Library/LaunchAgents/com.kira.focuslock.cli.plist"
LABEL="com.kira.focuslock.cli"

# Chuyển "id1, id2 ,id3" (bash, phân tách dấu phẩy) thành literal Swift Set: ["id1", "id2", "id3"]
IFS=',' read -ra ID_ARRAY <<< "$GAME_BUNDLE_IDS_RAW"
SWIFT_SET_LITERAL="["
for raw_id in "${ID_ARRAY[@]}"; do
  trimmed_id="$(echo "$raw_id" | xargs)"
  [ -z "$trimmed_id" ] && continue
  SWIFT_SET_LITERAL+="\"$trimmed_id\", "
done
SWIFT_SET_LITERAL="${SWIFT_SET_LITERAL%, }]"

echo "==> Tạo thư mục $APP_DIR"
mkdir -p "$APP_DIR"

echo "==> Ghi main.swift"
echo "    Games   : $GAME_BUNDLE_IDS_RAW"
echo "    Lock key: $LOCK_KEYCODE   Unlock key: $UNLOCK_KEYCODE"
cat > "$APP_DIR/main.swift" <<SWIFT_EOF
// FocusLock
// Watches for any of the target games becoming frontmost and sends
// LOCK/UNLOCK key presses, which Deskflow is configured to bind to hotkeys
// (switchToScreen + lockCursorToScreen(on) / lockCursorToScreen(off)).

import Cocoa
import CoreGraphics

let gameBundleIDs: Set<String> = $SWIFT_SET_LITERAL
let lockKeyCode: CGKeyCode = $LOCK_KEYCODE
let unlockKeyCode: CGKeyCode = $UNLOCK_KEYCODE
let debounceSeconds: Double = 0.2

var locked = false
var pendingWorkItem: DispatchWorkItem?

func log(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("[\\(timestamp)] \\(message)")
    fflush(stdout)
}

func postKey(_ keyCode: CGKeyCode) {
    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
          let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
        log("ERROR: failed to create CGEvent for keyCode \\(keyCode)")
        return
    }
    down.post(tap: .cghidEventTap)
    usleep(30_000)
    up.post(tap: .cghidEventTap)
}

func frontmostMatchedGame() -> String? {
    guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
          gameBundleIDs.contains(id) else { return nil }
    return id
}

func setLock(_ shouldLock: Bool, matchedGame: String? = nil) {
    guard shouldLock != locked else { return }
    postKey(shouldLock ? lockKeyCode : unlockKeyCode)
    locked = shouldLock
    if shouldLock {
        log("LOCKED (game: \\(matchedGame ?? "?"))")
    } else {
        log("UNLOCKED")
    }
}

func scheduleSync() {
    pendingWorkItem?.cancel()
    let item = DispatchWorkItem {
        let matched = frontmostMatchedGame()
        setLock(matched != nil, matchedGame: matched)
    }
    pendingWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + debounceSeconds, execute: item)
}

let nc = NSWorkspace.shared.notificationCenter
let watchedNotifications: [NSNotification.Name] = [
    NSWorkspace.didActivateApplicationNotification,
    NSWorkspace.didDeactivateApplicationNotification,
    NSWorkspace.didHideApplicationNotification,
    NSWorkspace.didUnhideApplicationNotification,
    NSWorkspace.didTerminateApplicationNotification,
]

for name in watchedNotifications {
    nc.addObserver(forName: name, object: nil, queue: .main) { note in
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier,
              gameBundleIDs.contains(bundleID) else { return }
        scheduleSync()
    }
}

// Test thủ công: kill -USR1 <pid> ép LOCK, kill -USR2 <pid> ép UNLOCK.
signal(SIGUSR1, SIG_IGN)
signal(SIGUSR2, SIG_IGN)
let sigLock = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
sigLock.setEventHandler {
    log("TEST: forcing LOCK via SIGUSR1")
    locked = false
    setLock(true, matchedGame: "TEST")
}
sigLock.resume()

let sigUnlock = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: .main)
sigUnlock.setEventHandler {
    log("TEST: forcing UNLOCK via SIGUSR2")
    locked = true
    setLock(false)
}
sigUnlock.resume()

log("FocusLock started (pid \\(ProcessInfo.processInfo.processIdentifier)). Watching \\(gameBundleIDs.count) game(s): \\(gameBundleIDs.joined(separator: ", "))")
scheduleSync()
RunLoop.main.run()
SWIFT_EOF

echo "==> Biên dịch main.swift"
swiftc -O "$APP_DIR/main.swift" -o "$APP_DIR/focuslock-cli"

echo "==> Tạo LaunchAgent plist tại $PLIST_PATH"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST_PATH" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$APP_DIR/focuslock-cli</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>$APP_DIR/watcher.log</string>
	<key>StandardErrorPath</key>
	<string>$APP_DIR/watcher.err.log</string>
	<key>ProcessType</key>
	<string>Interactive</string>
</dict>
</plist>
PLIST_EOF

echo "==> Nạp LaunchAgent"
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo ""
echo "✅ Đã cài xong binary + LaunchAgent (theo dõi ${#ID_ARRAY[@]} game)."
echo ""
echo "⚠️  BƯỚC BẮT BUỘC TIẾP THEO (làm thủ công trong System Settings):"
echo "  1. System Settings → Privacy & Security → Accessibility"
echo "     → thêm '$APP_DIR/focuslock-cli' và bật ✅"
echo "  2. System Settings → Privacy & Security → Input Monitoring"
echo "     → thêm '$APP_DIR/focuslock-cli' và bật ✅"
echo "  3. Làm tương tự cho Deskflow (Accessibility + Input Monitoring)"
echo "  4. Sau khi cấp quyền xong, chạy lại:"
echo "       launchctl unload '$PLIST_PATH' && launchctl load '$PLIST_PATH'"
echo ""
echo "Xem log realtime bằng:"
echo "  tail -f '$APP_DIR/watcher.log'"
