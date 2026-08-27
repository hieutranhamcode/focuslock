# Cài đặt Deskflow auto-lock cho máy mới

Bộ này gồm 2 phần độc lập, phải làm cả 2:

1. **Deskflow** — cấu hình switchToScreen + lockCursorToScreen theo hotkey F14/F15.
2. **FocusLock** — app menu bar tự phát hiện game/app và gửi phím F14/F15.

---

## Phần 1 — Cài & cấu hình Deskflow trên máy mới

1. Cài Deskflow (deskflow.org) trên máy mới, add vào cùng hệ thống với các máy hiện có (Kiras-Mac-mini, Dragons-Mac-mini...).
2. Xác định:
   - `SCREEN_NAME` = tên màn hình Deskflow của máy đang chạy game (chính máy mới này), ví dụ `Kiras-Mac-mini.local`. Xem trong Deskflow GUI → Server → danh sách Screens.
3. Cấu hình hotkey — có 2 cách:

   **Cách nhanh (khuyến nghị):** cài `FocusLock.app` trước (xem Phần 2), rồi bấm icon khóa trên menu bar → **"Auto-Configure Deskflow Hotkeys"**. App sẽ tự tắt Deskflow, sửa file cấu hình gán đúng phím LOCK/UNLOCK đang dùng (mặc định F14/F15), rồi mở lại Deskflow — không cần làm gì thêm ở bước dưới. Bỏ qua toàn bộ phần "Mở Deskflow GUI..." bên dưới nếu dùng cách này.

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

## Phần 2 — Cài FocusLock

1. Tải `FocusLock.app.zip` từ [Releases](https://github.com/hieutranhamcode/focuslock/releases/latest), giải nén, hoặc copy cả thư mục `FocusLock-Setup` (chứa sẵn `FocusLock.app`) sang máy mới.
2. Kéo `FocusLock.app` vào `/Applications`.
3. Mở app lần đầu bằng cách **chuột phải → Open** (vì app build ad-hoc, chưa notarize nên macOS sẽ cảnh báo "không xác định nhà phát triển" — chỉ cần làm vậy 1 lần).
   - Nếu file bị đánh dấu quarantine sau khi AirDrop/tải về (icon menu bar không hiện, hoặc bị chặn ngay), chạy: `xattr -cr /Applications/FocusLock.app` rồi mở lại.
4. Một icon ổ khóa có hình con trỏ bên trong sẽ hiện trên menu bar (khóa mở = chưa khóa, khóa đóng = đang khóa). Bấm vào đó để mở menu.
5. Cấp quyền cho app trong **System Settings → Privacy & Security**:
   - **Accessibility** → thêm `FocusLock` ✅
   - **Input Monitoring** → thêm `FocusLock` ✅
   - (Có thể cần tắt/mở lại app sau khi cấp quyền lần đầu: bấm "Quit FocusLock" trong menu rồi mở lại app.)
6. Trong menu bar, bấm **"Start at Login"** để app tự chạy mỗi khi đăng nhập (không cần LaunchAgent/plist thủ công nữa).
7. Danh sách game mặc định là Liên Minh Huyền Thoại. Muốn thêm game khác: bấm **"Add App from Applications..."** (chọn file .app) hoặc **"Add Running App"** (chọn từ danh sách app đang mở) — xong ngay, không cần build lại gì cả.
8. Chưa cấu hình hotkey bên Deskflow? Bấm **"Auto-Configure Deskflow Hotkeys"** — xem chi tiết ở Phần 1.

Muốn build lại app này từ source (ví dụ máy không tin tưởng file .app có sẵn, hoặc muốn sửa code):

```bash
cd ~/Desktop/FocusLock-Setup   # hoặc nơi copy vào
./build_app.sh
```

Script sẽ biên dịch lại từ `AppSource/main.swift` thành `FocusLock.app` (universal binary, chạy được cả Apple Silicon và Intel), tự gắn icon từ `AppSource/Assets/AppIcon.icns`.

### Kiểm tra hoạt động

Xem log watcher qua menu **"View Log..."**, hoặc trực tiếp:

```bash
tail -f ~/Library/Application\ Support/FocusLock/watcher.log
```

Nếu Deskflow không phản ứng: 99% là do thiếu quyền Accessibility/Input Monitoring, hoặc hotkey F14/F15 trong Deskflow chưa khớp key code thật của bàn phím máy đó (xem mẹo sửa file trực tiếp ở Phần 1).
