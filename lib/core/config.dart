/// Cấu hình chung của app.
///
/// Địa chỉ Backend đọc từ `--dart-define=API_BASE_URL=...` khi chạy:
/// - Điện thoại thật cắm cáp + `adb reverse tcp:8080 tcp:8080`: giữ mặc định `http://localhost:8080/api`
/// - Android emulator: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api`
/// - Điện thoại qua Wi-Fi: `flutter run --dart-define=API_BASE_URL=http://<IP-máy-tính>:8080/api`
/// - Bản deploy VPS: `flutter build apk --dart-define=API_BASE_URL=http://<IP-VPS>:8080/api`
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
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

  /// Ảnh do Backend trả về chứa host mà máy đã gửi ảnh lên (vd: localhost:8080 khi tải từ web).
  /// Đổi sang host của [apiBaseUrl] để điện thoại/emulator mở được.
  static String? mediaUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final media = Uri.tryParse(url);
    final api = Uri.tryParse(apiBaseUrl);
    if (media == null || api == null || !media.hasScheme) return url;
    const localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};
    if (localHosts.contains(media.host) && media.host != api.host) {
      return media.replace(host: api.host, port: api.port).toString();
    }
    return url;
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
