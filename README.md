# Cài đặt Deskflow auto-lock cho máy mới

Bộ này gồm 2 phần độc lập, phải làm cả 2:

1. **Deskflow** — cấu hình switchToScreen + lockCursorToScreen theo hotkey F14/F15.
2. **FocusLock** — app menu bar tự phát hiện game/app và gửi phím F14/F15.

Có 2 cách cài FocusLock:

- **Cách A (khuyến nghị): dùng app có sẵn** — `FocusLock.app` trong thư mục này. Chỉ cần kéo vào `/Applications`, mở lên, cấp quyền 1 lần. Thêm/xóa game qua menu bar, không cần build lại. Xem "Phần 2A" bên dưới.
- **Cách B (cũ, dòng lệnh):** chạy `setup.sh`, phù hợp nếu máy không có sẵn `FocusLock.app` và bạn không muốn build. Mỗi lần đổi danh sách game phải build lại + cấp lại quyền. Xem "Phần 2B" bên dưới.

---

## Phần 1 — Cài & cấu hình Deskflow trên máy mới

1. Cài Deskflow (deskflow.org) trên máy mới, add vào cùng hệ thống với các máy hiện có (Kiras-Mac-mini, Dragons-Mac-mini...).
2. Xác định:
   - `SCREEN_NAME` = tên màn hình Deskflow của máy đang chạy game (chính máy mới này), ví dụ `Kiras-Mac-mini.local`. Xem trong Deskflow GUI → Server → danh sách Screens.
3. Cấu hình hotkey — có 2 cách:

   **Cách nhanh (khuyến nghị):** cài `FocusLock.app` trước (xem Phần 2A), rồi bấm icon 🔒/🔓 trên menu bar → **"⚙️ Auto-Configure Deskflow Hotkeys"**. App sẽ tự tắt Deskflow, sửa file cấu hình gán đúng phím LOCK/UNLOCK đang dùng (mặc định F14/F15), rồi mở lại Deskflow — không cần làm gì thêm ở bước dưới. Bỏ qua toàn bộ phần "Mở Deskflow GUI..." bên dưới nếu dùng cách này.

   **Cách thủ công:** Mở Deskflow GUI → **Settings → Hotkeys**, tạo 2 hotkey:

   **Hotkey 1 — phím F14**
   - Action 1: `Switch to screen` → chọn `SCREEN_NAME` (chính máy này)
   - Action 2: `Lock cursor to screen` → `On`

   **Hotkey 2 — phím F15**
   - Action 1: `Lock cursor to screen` → `Off`

   > Bấm phím F14/F15 thật trên bàn phím máy đó để Deskflow bắt đúng key code. Dùng F14/F15 (không phải F1/F2) vì 2 phím này không có chức năng mặc định nào trên macOS (F1/F2 bị hệ thống chiếm làm brightness nên không tới được Deskflow).

   **Nếu Deskflow không bắt được phím khi bấm thật** (một số bàn phím không dây/rút gọn, ví dụ NuPhy, gửi F13+ theo kiểu HID mà bộ ghi hotkey của Deskflow không nhận ra): bỏ qua bước ghi bằng tay, sửa thẳng vào file cấu hình sau khi đã **tắt hẳn Deskflow** (cả GUI lẫn process `deskflow-core`, xem Activity Monitor):
   >
   > File: `~/Library/Deskflow/Deskflow.conf`, tìm 2 dòng `hotkeys\N\keys\1\key=...` tương ứng với 2 hotkey vừa tạo (dù ghi được hay không, chúng vẫn có mặt trong file), sửa giá trị theo bảng mã Qt key:
   >
   > | Phím | Mã Qt (ghi vào Deskflow.conf) |
   > |------|-------------------------------|
   > | F13  | 16777276 |
   > | F14  | 16777277 |
   > | F15  | 16777278 |
   > | F16  | 16777279 |
   >
   > Ví dụ: hotkey LOCK dùng F14 → `hotkeys\1\keys\1\key=16777277`; hotkey UNLOCK dùng F15 → `hotkeys\2\keys\1\key=16777278`. Lưu file rồi mở lại Deskflow. Cách này không ảnh hưởng gì đến hệ thống tự động (app gửi phím giả lập, không cần bàn phím thật nhận diện được).

4. Áp dụng, khởi động lại Deskflow (kill hẳn qua Activity Monitor rồi mở lại, vì Deskflow hay giữ config cũ trong RAM nếu chỉ đóng cửa sổ).
5. Cấp quyền cho Deskflow trong **System Settings → Privacy & Security**:
   - Accessibility ✅
   - Input Monitoring ✅ (nếu Deskflow yêu cầu)

---

## Phần 2A — Cài bằng app (khuyến nghị)

1. Copy cả thư mục `FocusLock-Setup` (chứa sẵn `FocusLock.app`) sang máy mới.
2. Kéo `FocusLock.app` vào `/Applications`.
3. Mở app lần đầu bằng cách **chuột phải → Open** (vì app build ad-hoc, chưa notarize nên macOS sẽ cảnh báo "không xác định nhà phát triển" — chỉ cần làm vậy 1 lần).
   - Nếu file bị đánh dấu quarantine sau khi AirDrop/tải về (icon menu bar không hiện, hoặc bị chặn ngay), chạy: `xattr -cr /Applications/FocusLock.app` rồi mở lại.
4. Một icon ổ khóa có hình con trỏ bên trong sẽ hiện trên menu bar (khóa mở = chưa khóa, khóa đóng = đang khóa). Bấm vào đó để mở menu.
5. Cấp quyền cho app trong **System Settings → Privacy & Security**:
   - **Accessibility** → thêm `FocusLock` ✅
   - **Input Monitoring** → thêm `FocusLock` ✅
   - (Có thể cần tắt/mở lại app sau khi cấp quyền lần đầu: bấm "Quit FocusLock" trong menu rồi mở lại app.)
6. Trong menu bar, bấm **"Start at Login"** để app tự chạy mỗi khi đăng nhập (không cần LaunchAgent/plist thủ công nữa).
7. Danh sách game mặc định là Liên Minh Huyền Thoại. Muốn thêm game khác: bấm **"➕ Add App from Applications..."** (chọn file .app) hoặc **"➕ Add Running App"** (chọn từ danh sách app đang mở) — xong ngay, không cần build lại gì cả.
8. Test không cần mở game: bấm **"🔒 Test Lock"** / **"🔓 Test Unlock"** trong menu, xem Deskflow có phản ứng không.
9. Chưa cấu hình hotkey bên Deskflow? Bấm **"⚙️ Auto-Configure Deskflow Hotkeys"** — xem chi tiết ở Phần 1.

Muốn build lại app này từ source (ví dụ máy không tin tưởng file .app có sẵn, hoặc muốn sửa code):

```bash
cd ~/Desktop/FocusLock-Setup   # hoặc nơi copy vào
./build_app.sh
```

Script sẽ biên dịch lại từ `AppSource/main.swift` thành `FocusLock.app` (universal binary, chạy được cả Apple Silicon và Intel), tự gắn icon từ `AppSource/Assets/AppIcon.icns`.

---

## Phần 2B — Cài bằng dòng lệnh (cách cũ)

Copy cả thư mục `FocusLock-Setup` này sang máy mới (AirDrop / USB / iCloud Drive...), rồi trong Terminal:

```bash
cd ~/Desktop/FocusLock-Setup   # hoặc nơi bạn copy vào
chmod +x setup.sh
./setup.sh
```

Mặc định script theo dõi Liên Minh Huyền Thoại và dùng phím F14 (lock) / F15 (unlock) — đúng như cấu hình Deskflow ở Phần 1.

### Theo dõi nhiều game cùng lúc

Truyền danh sách Bundle ID cách nhau bởi dấu phẩy ở tham số đầu tiên:

```bash
./setup.sh "com.riotgames.LeagueofLegends.GameClient,com.riotgames.valorant" 107 113
```

Chỉ cần 1 cặp phím LOCK/UNLOCK dùng chung — hễ **bất kỳ game nào** trong danh sách đang active thì tự LOCK; khi tất cả đều không active nữa thì tự UNLOCK. Trong `watcher.log` sẽ ghi rõ game nào vừa kích hoạt lock, ví dụ `LOCKED (game: com.riotgames.valorant)`.

Cách tìm Bundle ID của 1 game/app bất kỳ (khi app đang chạy):

```bash
osascript -e 'id of app "Tên App"'
# hoặc
lsappinfo info -only bundleID "Tên App"
```

Nếu chỉ dùng 1 game, không cần dấu phẩy — dùng như cũ:

```bash
./setup.sh "com.riotgames.LeagueofLegends.GameClient" 107 113
```

Sau khi script chạy xong, làm đúng theo hướng dẫn nó in ra:

1. Cấp quyền **Accessibility** cho `focuslock-cli` trong System Settings.
2. Cấp quyền **Input Monitoring** cho `focuslock-cli`.
3. Chạy lại lệnh `launchctl unload/load` mà script gợi ý để áp dụng quyền mới.

Các mục dưới đây (kiểm tra hoạt động, đổi danh sách game, lưu ý build lại) chỉ áp dụng cho **Cách B (dòng lệnh)**. Nếu dùng Cách A (app), test/đổi game đã làm trực tiếp qua menu bar ở Phần 2A rồi, không cần đọc tiếp phần này.

### Kiểm tra hoạt động (Cách B)

Xem log watcher:

```bash
tail -f ~/Library/Application\ Support/FocusLock-CLI/watcher.log
```

Test thủ công không cần mở game (tìm PID watcher trước):

```bash
pgrep -f focuslock-cli
kill -USR1 <PID>   # ép LOCK — kiểm tra Deskflow log/hành vi chuột
kill -USR2 <PID>   # ép UNLOCK
```

Nếu Deskflow không phản ứng: 99% là do thiếu quyền Accessibility/Input Monitoring, hoặc hotkey F14/F15 trong Deskflow chưa khớp key code thật của bàn phím máy đó (xem mẹo sửa file trực tiếp ở Phần 1).

### Đổi danh sách game sau này (Cách B, trên máy đã cài rồi)

Chạy lại `setup.sh` với danh sách mới ngay trên máy đó — nó sẽ ghi đè `main.swift`, biên dịch lại binary và nạp lại đúng LaunchAgent hiện có (không tạo bản trùng):

```bash
cd ~/Desktop/FocusLock-Setup
./setup.sh "id_game_1,id_game_2,id_game_3" 107 113
```

Vì binary bị biên dịch lại, nhớ làm lại bước "xóa hẳn rồi thêm lại" quyền Accessibility/Input Monitoring bên dưới.

### Lưu ý khi build lại watcher (Cách B)

Mỗi lần sửa `main.swift` và biên dịch lại (`swiftc`), macOS sẽ **thu hồi quyền TCC** đã cấp cho binary cũ. Phải vào System Settings, **xóa hẳn** `focuslock-cli` khỏi danh sách Accessibility/Input Monitoring rồi **thêm lại**, không chỉ tắt/bật toggle.

> Đây chính là lý do Cách A (app) tốt hơn: danh sách game lưu trong `config.json` riêng, không đụng tới binary, nên **không** bị mất quyền mỗi khi thêm/xóa game. (Lưu ý: kể cả với Cách A, sửa/thêm tính năng vào code app — tức build lại `FocusLock.app` — vẫn làm mất quyền như bình thường; chỉ có thao tác thêm/xóa game qua menu là không ảnh hưởng.)
