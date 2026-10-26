import 'package:geolocator/geolocator.dart';

import 'api_client.dart';

/// Toạ độ đơn giản dùng trong app.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Trung tâm TP.HCM – dùng khi chưa lấy được GPS.
  static const hcmc = GeoPoint(10.7769, 106.7009);
}

/// Lấy vị trí GPS của máy. GPS là tính năng của điện thoại, không tốn phí API.
class LocationService {
  LocationService._();

  /// Ném [ApiFailure] với câu dễ hiểu nếu không lấy được vị trí.
  static Future<GeoPoint> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiFailure(
        'Vui lòng bật định vị (GPS) trên điện thoại rồi thử lại.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const ApiFailure('Bạn cần cho phép ứng dụng truy cập vị trí.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const ApiFailure(
        'Quyền vị trí đang bị tắt. Hãy mở Cài đặt > Ứng dụng > HomeService > Quyền để bật lại.',
      );
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return GeoPoint(last.latitude, last.longitude);
      throw const ApiFailure(
        'Chưa lấy được vị trí. Hãy ra chỗ thoáng hoặc thử lại sau vài giây.',
      );
    }
  }

  /// Giống [current] nhưng trả null thay vì báo lỗi (dùng khi gửi vị trí định kỳ).
  static Future<GeoPoint?> tryCurrent() async {
    try {
      return await current();
    } catch (_) {
      return null;
    }
  }
}
