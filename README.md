# HomeService Mobile

Ứng dụng Flutter cho **Khách hàng** và **Tasker** của hệ thống HomeService (Nhóm 15). Gọi API của repo `HomeService-Backend`.

- Flutter 3.44+ (Dart 3.12+), chạy trên Android 7.0 (API 24) trở lên
- Bản đồ: OpenStreetMap (`flutter_map`) – miễn phí, không cần Google Maps API key
- Chỉ đường / gọi điện: mở app Google Maps và trình gọi điện có sẵn (`url_launcher`)

## Chạy app

```powershell
flutter pub get
flutter run
```

Mặc định app gọi máy chủ thật **https://api.homeservice.id.vn/api** – không cần bật Backend trên máy.

Khi lập trình với Backend chạy trên máy tính (`docker compose up` trong `HomeService-Backend`):

| Thiết bị | Lệnh |
|---|---|
| Điện thoại thật cắm cáp | `adb reverse tcp:8080 tcp:8080` rồi `flutter run --dart-define=API_BASE_URL=http://localhost:8080/api` |
| Android emulator | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api` |

`adb` nằm ở `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.

## Cấu trúc

```
lib/
├── main.dart                 # Màn chờ khởi động → MaterialApp, tiếng Việt, AuthGate
├── core/                     # api_client (toàn bộ API), models, labels (enum số ↔ nhãn),
│                             #   format, validators, config (base URL), location_service
├── theme/app_theme.dart      # Bảng màu, kiểu chữ dùng chung (cũng dùng cho Web Customer)
├── widgets/                  # Nút, thẻ, trạng thái, bản đồ, chọn ảnh, đánh giá, điều hướng,
│                             #   motion.dart (hiện dần, nhấp nhô, radar, bản đồ minh họa, đầu trang)
└── features/
    ├── splash/               # Màn chờ có hiệu ứng logo
    ├── auth/                 # Welcome (3 trang giới thiệu), Đăng nhập, Đăng ký (Khách hàng / Tasker)
    ├── customer/             # Trang chủ, Đặt dịch vụ, Thanh toán, Đơn hàng, Chi tiết đơn, Khiếu nại
    ├── tasker/               # Nhận việc, Lịch làm, Chi tiết việc, Hồ sơ Tasker, Ví, Phản hồi khiếu nại
    └── common/               # Thông báo, Tài khoản, Sửa hồ sơ, Lịch sử thanh toán
```

## Giao diện

- Phông **Be Vietnam Pro** (`assets/fonts`, giấy phép SIL OFL) và bảng màu teal dùng chung với Web Customer.
- Màn chờ 2 lớp: màn chờ gốc Android (`android/app/src/main/res/drawable*/launch_background.xml`, Android 12+ dùng `values-v31/styles.xml`) rồi tới màn chờ Flutter có hiệu ứng (`lib/features/splash`).
- Icon ứng dụng: `mipmap-*/ic_launcher*.png` + icon thích ứng `mipmap-anydpi-v26/ic_launcher.xml`.
- Hiệu ứng chuyển trang, hiện dần, nhấp nhô… tự tắt khi điện thoại bật “Xóa hoạt ảnh”.

## Chức năng theo User Story

| Vai trò | Màn hình | US |
|---|---|---|
| Tất cả | Đăng ký, đăng nhập, đăng xuất, tự đăng xuất khi token hết hạn | US01–US03 |
| Khách hàng | Trang chủ: tìm dịch vụ, bảng giá, đơn đang xử lý | US10, US11 |
| Khách hàng | Đặt dịch vụ: số lượng, chọn ngày/giờ, ghim vị trí trên bản đồ, chọn thanh toán (tiền mặt chỉ mở khi đủ điều kiện) | US12, US13 |
| Khách hàng | Thanh toán trước có đếm ngược 15 phút; trả nợ / phí hủy | US21, US36 |
| Khách hàng | Đơn hàng 3 tab; chi tiết đơn với nút theo trạng thái: hủy (xem phí trước), thử lại, xác nhận, khiếu nại, đánh giá, đặt lại | US14, US15, US33, US34, US35, US37 |
| Khách hàng | Theo dõi vị trí Tasker trên bản đồ (10 giây/lần) | US19 |
| Tasker | Hồ sơ xác thực: CCCD + ảnh, kỹ năng, khu vực, điểm làm việc, bán kính 3/5/8 km | US04 |
| Tasker | Bật/tắt nhận đơn (gửi GPS 1 lần), lời mời có đếm ngược, nhận / bỏ qua | US16, US17, US28 |
| Tasker | Lịch làm; chi tiết việc: chỉ đường, gọi khách, bắt đầu/hoàn thành kèm ảnh, gửi vị trí 15 giây/lần khi đang làm, báo khách chưa trả, phản hồi khiếu nại, đánh giá khách | US18–US20, US26, US35, US36 |
| Tasker | Ví: số dư, nạp, rút, lịch sử; thu nhập theo đơn | US22–US24 |
| Tất cả | Thông báo (lọc chưa đọc, đọc hết, số trên biểu tượng), hồ sơ cá nhân, báo cáo đánh giá bất thường | US05, US27, US29 |

## Kiểm tra

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

### Build APK phát hành (cài được trên mọi điện thoại Android 7.0+)

1. **Lần đầu**: tạo khóa ký – `powershell -ExecutionPolicy Bypass -File .\tao-khoa-ky-apk.ps1`
   (tạo `android\app\homeservice-release.jks` + `android\key.properties`, **không commit, nhớ sao lưu**).
   Mọi bản cập nhật phải ký cùng khóa này thì điện thoại mới cài đè được lên bản cũ.
2. Mỗi lần phát hành: tăng `version:` trong `pubspec.yaml` (vd `1.0.1+2` – số sau dấu `+` luôn tăng), rồi
   ```powershell
   flutter build apk --release
   ```
   Đây là APK "đa kiến trúc" (arm64-v8a, armeabi-v7a, x86_64) nên chạy được trên mọi dòng máy. **Không** dùng `--split-per-abi`.
3. File: `build/app/outputs/flutter-apk/app-release.apk` – script `build-deploy.ps1` (thư mục `Nang Cao`) tự chép thành `HomeService.apk` vào bản deploy của Web Customer.

App tự tin cậy chứng chỉ gốc Let's Encrypt (`lib/core/trusted_roots.dart`) nên HTTPS chạy được cả trên Android 7.0.
