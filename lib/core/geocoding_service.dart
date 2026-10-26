import 'api_client.dart';
import 'location_service.dart';
import 'models.dart';

/// Một kết quả tìm địa chỉ.
class PlaceResult {
  const PlaceResult({required this.point, required this.address, this.title});

  final GeoPoint point;

  /// Địa chỉ gọn để điền vào ô nhập (số nhà, đường, phường, quận, thành phố).
  final String address;

  /// Tên địa điểm (nếu có), ví dụ "Chợ Bến Thành".
  final String? title;

  factory PlaceResult.fromJson(Json json) => PlaceResult(
    point: GeoPoint(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    ),
    address: json['address'] as String? ?? '',
    title: json['title'] as String?,
  );
}

/// Đổi toạ độ ⇄ địa chỉ – miễn phí, không cần API key.
/// Ưu tiên qua Backend (`/api/geo/...`, có cache); Backend lỗi thì gọi thẳng Nominatim (OpenStreetMap).
/// Lỗi mạng không làm hỏng màn hình: trả null / danh sách rỗng.
class GeocodingService {
  GeocodingService._();

  static Future<String?> reverse(ApiClient api, GeoPoint point) async {
    try {
      final address = await api.reverseGeocode(point.latitude, point.longitude);
      if (address != null && address.isNotEmpty) return address;
    } catch (_) {
      // Backend lỗi / chưa có /api/geo => thử gọi thẳng OpenStreetMap
    }
    try {
      return await api.reverseGeocodeDirect(point.latitude, point.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Tìm địa chỉ ở Việt Nam – chỉ gọi khi người dùng bấm tìm (không theo từng ký tự).
  static Future<List<PlaceResult>> search(ApiClient api, String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    List<PlaceResult> parse(List<Json> items) => items
        .map(PlaceResult.fromJson)
        .where((p) => p.address.isNotEmpty)
        .toList();
    try {
      final results = parse(await api.searchPlaces(q));
      if (results.isNotEmpty) return results;
    } catch (_) {
      // Backend lỗi / chưa có /api/geo => thử gọi thẳng OpenStreetMap
    }
    try {
      return parse(await api.searchPlacesDirect(q));
    } catch (_) {
      return const [];
    }
  }

  /// Vị trí đầu tiên khớp địa chỉ (dùng cho địa chỉ đã lưu trong hồ sơ).
  static Future<GeoPoint?> locate(ApiClient api, String address) async {
    final results = await search(api, address);
    return results.isEmpty ? null : results.first.point;
  }
}
