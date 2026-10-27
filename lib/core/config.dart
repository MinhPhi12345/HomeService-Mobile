/// Cấu hình chung của app.
///
/// Địa chỉ Backend: mặc định là máy chủ thật `https://api.homeservice.id.vn/api`
/// (`flutter run`, `flutter build apk` không cần thêm gì).
/// Khi lập trình với Backend chạy trên máy tính, ghi đè bằng `--dart-define=API_BASE_URL=...`:
/// - Điện thoại cắm cáp + `adb reverse tcp:8080 tcp:8080`: `--dart-define=API_BASE_URL=http://localhost:8080/api`
/// - Android emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:8080/api`
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.homeservice.id.vn/api',
  );

  /// Phiên bản hiển thị trong mục Tài khoản – khớp `version:` trong pubspec.yaml.
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// Thời gian chờ tối đa cho 1 request.
  static const Duration requestTimeout = Duration(seconds: 20);

  /// Khách hàng tải lại vị trí Tasker (SRS US19).
  static const Duration trackingRefresh = Duration(seconds: 10);

  /// Tasker gửi vị trí khi đang làm đơn (SRS US19).
  static const Duration locationSendInterval = Duration(seconds: 15);

  /// Tasker tải lại danh sách lời mời (lời mời sống 45–60 giây).
  static const Duration offerRefresh = Duration(seconds: 5);

  /// Tải lại đơn đang xử lý / số thông báo chưa đọc.
  static const Duration bookingRefresh = Duration(seconds: 10);
  static const Duration badgeRefresh = Duration(seconds: 30);

  /// Gốc Backend (bỏ "/api"): "https://api.homeservice.id.vn/api" → "https://api.homeservice.id.vn".
  static String get mediaOrigin =>
      apiBaseUrl.replaceAll(RegExp(r'/+$'), '').replaceAll(RegExp(r'/api$'), '');

  /// Đường dẫn ảnh Backend lưu ("/uploads/…") → URL đầy đủ theo [apiBaseUrl].
  /// Ảnh cũ dạng "http://localhost:8080/uploads/…" cũng được trỏ về Backend đang dùng
  /// để điện thoại / emulator / bản deploy đều mở được.
  static String? mediaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final value = url.trim();
    final legacy = RegExp(r'^https?://[^/]+(/uploads/.*)$', caseSensitive: false).firstMatch(value);
    if (legacy != null) return '$mediaOrigin${legacy.group(1)}';
    if (RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) return value;
    return '$mediaOrigin${value.startsWith('/') ? '' : '/'}$value';
  }
}

/// Khu vực làm việc Backend chấp nhận (Common/WorkingAreas.cs).
const List<String> kWorkingAreas = [
  'Quận 1',
  'Quận 3',
  'Quận 4',
  'Quận 5',
  'Quận 7',
  'Quận 10',
  'Bình Thạnh',
  'Phú Nhuận',
  'Gò Vấp',
  'Tân Bình',
  'Thủ Đức',
];

/// Bán kính phục vụ Tasker được chọn (km).
const List<int> kServiceRadiusKm = [3, 5, 8];
