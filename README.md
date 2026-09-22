# HomeService – App di động

App di động dùng chung cho **Khách hàng** và **Tasker** của hệ thống HomeService (giao diện/chức năng phân biệt theo vai trò sau khi đăng nhập). Đề tài Công nghệ phần mềm Nâng cao, Nhóm 01.

- **Framework**: Flutter (Dart) ≥ 3.3
- **State management**: provider
- **HTTP**: package `http`, tự gắn JWT qua `SharedPreferences`
- **Backend**: gọi API từ repo `HomeService-Backend`

## ⚠️ Bước bắt buộc trước khi chạy

Repo này chỉ chứa mã nguồn Dart (`lib/`) và cấu hình (`pubspec.yaml`) — **chưa có** các thư mục nền tảng (`android/`, `ios/`...) vì môi trường tạo scaffold không cài Flutter SDK. Sau khi clone về máy đã cài Flutter, chạy:

```bash
flutter create . --project-name homeservice_mobile --org com.homeservice
flutter pub get
```

Lệnh `flutter create .` sẽ sinh các thư mục `android/`, `ios/`, v.v. mà **không** ghi đè `lib/` hay `pubspec.yaml` đã có sẵn.

## Cấu trúc thư mục

```
lib/
├── core/                  # constants.dart (URL backend), api_client.dart (HTTP + JWT)
├── models/                 # user.dart, service_category.dart, booking.dart
├── features/
│   ├── auth/                # login_screen, register_screen, auth_provider (US01-US03)
│   ├── customer/             # customer_home, booking_create, booking_history, service_repository (US10, US12-US15)
│   └── tasker/                 # tasker_home_screen (US17, US18, US20)
└── main.dart
```

## Cấu hình kết nối Backend

Sửa `lib/core/constants.dart`:

```dart
static const String apiBaseUrl = 'http://10.0.2.2:8080/api'; // Android emulator
// hoặc 'http://localhost:8080/api' khi chạy trên web/desktop
// hoặc IP LAN máy chạy backend khi test trên điện thoại thật
```

## Chạy dự án

```bash
flutter pub get
flutter run
```

## Các màn hình đã scaffold

| Màn hình | User Story |
|---|---|
| LoginScreen / RegisterScreen | US01, US02 – Đăng ký, đăng nhập (chọn vai trò Khách hàng/Tasker) |
| CustomerHomeScreen | US10 – Xem/Tìm kiếm dịch vụ |
| BookingCreateScreen | US12/US13 – Tạo đơn, chọn thời gian & địa chỉ |
| BookingHistoryScreen | US14/US15 – Hủy đơn, xem lịch sử |
| TaskerHomeScreen | US17/US18/US20 – Nhận/từ chối đơn, cập nhật trạng thái, xem đơn đã nhận |

Các User Story còn lại (US19 theo dõi vị trí realtime, US21 thanh toán, US25/US26 đánh giá, US28/US29 thông báo...) sẽ được nhóm bổ sung dần theo Sprint trong file Backlog. Gợi ý: US19 có thể dùng package `google_maps_flutter` hoặc `flutter_map`; US28/US29 có thể dùng Firebase Cloud Messaging.
