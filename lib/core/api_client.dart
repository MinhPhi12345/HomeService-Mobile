import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';
import 'service_images.dart';

/// Lỗi đã được dịch sang câu tiếng Việt để hiện thẳng cho người dùng (SRS 8.6).
class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}

/// Lấy câu thông báo từ một lỗi bất kỳ.
String errorMessage(Object error) {
  if (error is ApiFailure) return error.message;
  return 'Đã có lỗi xảy ra. Vui lòng thử lại.';
}

/// Toàn bộ API của HomeService-Backend dùng trong app.
/// Là [ChangeNotifier] để màn hình gốc tự chuyển khi đăng nhập / đăng xuất.
class ApiClient extends ChangeNotifier {
  ApiClient._(this._preferences, this._http, this._secureStorage)
    : _baseUrl = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');

  static const _tokenKey = 'access_token';
  static const _userIdKey = 'user_id';
  static const _nameKey = 'user_name';
  static const _emailKey = 'user_email';
  static const _roleKey = 'user_role';
  static const _expiresKey = 'token_expires_at';

  final SharedPreferences _preferences;
  final http.Client _http;
  final FlutterSecureStorage _secureStorage;
  final String _baseUrl;
  String? _token;
  UserSession? _user;

  UserSession? get currentUser => _user;
  bool get isAuthenticated => _token != null && _user != null;
  String get baseUrl => _baseUrl;

  static Future<ApiClient> create() async {
    final preferences = await SharedPreferences.getInstance();
    final api = ApiClient._(
      preferences,
      http.Client(),
      const FlutterSecureStorage(),
    );
    await api._restoreSession();
    unawaited(api.checkMapTiles()); // chọn nguồn ảnh bản đồ, không chặn lúc mở app
    return api;
  }

  // ---------------------------------------------------------------- Phiên đăng nhập

  Future<void> _restoreSession() async {
    try {
      _token = await _secureStorage.read(key: _tokenKey);
    } catch (_) {
      _token = null;
    }
    final userId = _preferences.getInt(_userIdKey);
    final name = _preferences.getString(_nameKey);
    final email = _preferences.getString(_emailKey);
    final role = _preferences.getInt(_roleKey);
    final expires = DateTime.tryParse(_preferences.getString(_expiresKey) ?? '');
    final expired = expires != null && expires.isBefore(DateTime.now());
    if (_token == null ||
        userId == null ||
        name == null ||
        email == null ||
        role == null ||
        expired) {
      await _clearSession(notify: false);
      return;
    }
    _user = UserSession(
      userId: userId,
      fullName: name,
      email: email,
      role: role,
    );
  }

  Future<UserSession> login(String email, String password) async {
    final result = await _send(
      'POST',
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      auth: false,
    );
    return _saveSession(result as Json);
  }

  Future<UserSession> register({
    required String fullName,
    required String email,
    required String password,
    required String phoneNumber,
    required int role,
  }) async {
    final result = await _send(
      'POST',
      '/auth/register',
      body: {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'phoneNumber': phoneNumber.trim().isEmpty ? null : phoneNumber.trim(),
        'role': role,
      },
      auth: false,
    );
    return _saveSession(result as Json);
  }

  Future<UserSession> _saveSession(Json json) async {
    final token = json['accessToken'] as String?;
    final user = UserSession(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: (json['role'] as num?)?.toInt() ?? 0,
    );
    if (token == null || token.isEmpty) {
      throw const ApiFailure('Phản hồi đăng nhập không hợp lệ.');
    }
    if (user.role == 2) {
      throw const ApiFailure(
        'Tài khoản quản trị vui lòng dùng Website quản trị.',
      );
    }
    await _secureStorage.write(key: _tokenKey, value: token);
    await _preferences.setInt(_userIdKey, user.userId);
    await _preferences.setString(_nameKey, user.fullName);
    await _preferences.setString(_emailKey, user.email);
    await _preferences.setInt(_roleKey, user.role);
    final expiresAt = json['expiresAt'] as String?;
    if (expiresAt != null) {
      await _preferences.setString(_expiresKey, expiresAt);
    }
    _token = token;
    _user = user;
    notifyListeners();
    return user;
  }

  /// Cập nhật tên hiển thị sau khi sửa hồ sơ.
  Future<void> updateCachedName(String fullName) async {
    final user = _user;
    if (user == null) return;
    _user = user.copyWith(fullName: fullName);
    await _preferences.setString(_nameKey, fullName);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      if (_token != null) await _send('POST', '/auth/logout');
    } catch (_) {
      // Đăng xuất phía FE vẫn tiếp tục dù Backend không phản hồi.
    }
    await _clearSession();
  }

  Future<void> _clearSession({bool notify = true}) async {
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (_) {}
    for (final key in [_userIdKey, _nameKey, _emailKey, _roleKey, _expiresKey]) {
      await _preferences.remove(key);
    }
    _token = null;
    _user = null;
    if (notify) notifyListeners();
  }

  // ---------------------------------------------------------------- Dịch vụ

  Future<List<ServiceCategory>> getCategories({String? keyword}) async {
    final result = await _send(
      'GET',
      '/servicecategories',
      query: {if (keyword != null && keyword.isNotEmpty) 'keyword': keyword},
      auth: false,
    );
    final list = _parseList(result, ServiceCategory.fromJson);
    if (keyword == null || keyword.isEmpty) {
      ServiceImages.update(list.map((s) => (name: s.name, iconUrl: s.iconUrl)));
    }
    return list;
  }

  /// Tải ảnh dịch vụ 1 lần cho các màn chỉ có tên dịch vụ (thẻ đơn, lời mời của Tasker…).
  Future<void> ensureServiceImages() async {
    if (!ServiceImages.isEmpty) return;
    try {
      await getCategories();
    } catch (_) {
      // Không có mạng: dùng icon mặc định
    }
  }

  // ---------------------------------------------------------------- Đơn hàng

  Future<Booking> createBooking({
    required int serviceCategoryId,
    required DateTime scheduledTime,
    required String address,
    required double latitude,
    required double longitude,
    required int quantity,
    required int paymentMethod,
    required bool customerPresent,
    String? note,
    String? contactPhone,
  }) async {
    final result = await _send(
      'POST',
      '/bookings',
      body: {
        'serviceCategoryId': serviceCategoryId,
        'scheduledTime': scheduledTime.toUtc().toIso8601String(),
        'address': address.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
        'quantity': quantity,
        'paymentMethod': paymentMethod,
        'customerPresent': customerPresent,
        'contactPhone': (contactPhone == null || contactPhone.trim().isEmpty)
            ? null
            : contactPhone.trim(),
      },
    );
    return Booking.fromJson(result as Json);
  }

  Future<Booking> getBooking(int id) async =>
      Booking.fromJson(await _send('GET', '/bookings/$id') as Json);

  /// [statuses] lọc theo trạng thái; [upcoming] = đơn 2/3 sắp theo giờ hẹn.
  Future<List<Booking>> getMyBookings({
    List<int>? statuses,
    bool upcoming = false,
    String? keyword,
  }) async {
    final result = await _send(
      'GET',
      '/bookings/my',
      query: {
        if (statuses != null && statuses.isNotEmpty)
          'status': statuses.join(','),
        if (upcoming) 'upcoming': 'true',
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      },
    );
    return _parseList(result, Booking.fromJson);
  }

  Future<CancellationFee> getCancellationFee(int id) async =>
      CancellationFee.fromJson(
        await _send('GET', '/bookings/$id/cancellation-fee') as Json,
      );

  Future<void> cancelBooking(int id) => _send('POST', '/bookings/$id/cancel');

  Future<void> retryBooking(int id, {DateTime? scheduledTime}) => _send(
    'POST',
    '/bookings/$id/retry',
    body: {
      if (scheduledTime != null)
        'scheduledTime': scheduledTime.toUtc().toIso8601String(),
    },
  );

  Future<void> confirmBooking(int id) => _send('POST', '/bookings/$id/confirm');

  Future<void> createDispute(
    int bookingId, {
    required int reason,
    required String description,
    required List<String> evidenceUrls,
  }) => _send(
    'POST',
    '/bookings/$bookingId/dispute',
    body: {
      'reason': reason,
      'description': description.trim(),
      'evidenceUrls': evidenceUrls,
    },
  );

  Future<TaskerLocation?> getTaskerLocation(int bookingId) async {
    try {
      final result = await _send('GET', '/bookings/$bookingId/location');
      return TaskerLocation.fromJson(result as Json);
    } on ApiFailure catch (error) {
      if (error.isNotFound) return null; // Tasker chưa chia sẻ vị trí
      rethrow;
    }
  }

  // ---------------------------------------------------------------- Thanh toán

  Future<void> pay(int bookingId, int method) => _send(
    'POST',
    '/payments',
    body: {'bookingId': bookingId, 'method': method},
  );

  Future<Paged<PaymentItem>> getMyPayments({int page = 1, int pageSize = 20}) async {
    final result = await _send(
      'GET',
      '/payments/my',
      query: {'page': '$page', 'pageSize': '$pageSize'},
    );
    return Paged.fromJson(result as Json, PaymentItem.fromJson);
  }

  // ---------------------------------------------------------------- Tasker

  /// null = Tasker chưa gửi hồ sơ.
  Future<TaskerProfile?> getTaskerProfile() async {
    try {
      return TaskerProfile.fromJson(
        await _send('GET', '/taskers/profile') as Json,
      );
    } on ApiFailure catch (error) {
      if (error.isNotFound) return null;
      rethrow;
    }
  }

  Future<TaskerProfile> submitTaskerProfile({
    required String idCardNumber,
    required String idCardImageUrl,
    required String skills,
    required String workingArea,
    required String baseAddress,
    required double baseLatitude,
    required double baseLongitude,
    required int serviceRadiusKm,
  }) async {
    final result = await _send(
      'POST',
      '/taskers/profile',
      body: {
        'idCardNumber': idCardNumber.trim(),
        'idCardImageUrl': idCardImageUrl,
        'skills': skills,
        'workingArea': workingArea,
        'baseAddress': baseAddress.trim(),
        'baseLatitude': baseLatitude,
        'baseLongitude': baseLongitude,
        'serviceRadiusKm': serviceRadiusKm,
      },
    );
    return TaskerProfile.fromJson(result as Json);
  }

  /// Bật/tắt nhận đơn. Gửi kèm vị trí hiện tại 1 lần (ràng buộc ghép nối của nhóm).
  Future<void> setAvailability(
    bool isAvailable, {
    double? latitude,
    double? longitude,
  }) => _send(
    'PUT',
    '/taskers/availability',
    body: {
      'isAvailable': isAvailable,
      'latitude': ?latitude,
      'longitude': ?longitude,
    },
  );

  Future<List<TaskerOffer>> getMyOffers({bool all = false}) async {
    final result = await _send(
      'GET',
      '/offers/my',
      query: {if (all) 'all': 'true'},
    );
    return _parseList(result, TaskerOffer.fromJson);
  }

  Future<void> acceptOffer(int bookingId) =>
      _send('POST', '/bookings/$bookingId/accept');

  Future<void> rejectOffer(int bookingId) =>
      _send('POST', '/bookings/$bookingId/reject');

  /// 3 = bắt đầu (kèm ảnh trước), 4 = hoàn thành (kèm ảnh sau; đơn tiền mặt cần [cashCollected]).
  Future<void> updateBookingStatus(
    int bookingId, {
    required int status,
    required String photoUrl,
    bool? cashCollected,
  }) => _send(
    'PUT',
    '/bookings/$bookingId/status',
    body: {
      'status': status,
      'photoUrl': photoUrl,
      'cashCollected': ?cashCollected,
    },
  );

  Future<void> reportUnpaid(
    int bookingId, {
    required String note,
    required String photoUrl,
  }) => _send(
    'POST',
    '/bookings/$bookingId/report-unpaid',
    body: {'note': note.trim(), 'photoUrl': photoUrl},
  );

  Future<void> sendLocation(int bookingId, double latitude, double longitude) =>
      _send(
        'PUT',
        '/bookings/$bookingId/location',
        body: {'latitude': latitude, 'longitude': longitude},
      );

  Future<Wallet> getWallet() async =>
      Wallet.fromJson(await _send('GET', '/wallet') as Json);

  Future<Wallet> topUp(double amount) async => Wallet.fromJson(
    await _send('POST', '/wallet/topup', body: {'amount': amount}) as Json,
  );

  Future<Wallet> withdraw(double amount) async => Wallet.fromJson(
    await _send('POST', '/wallet/withdraw', body: {'amount': amount}) as Json,
  );

  Future<Paged<WalletTransaction>> getWalletTransactions({
    int page = 1,
    int pageSize = 20,
  }) async {
    final result = await _send(
      'GET',
      '/wallet/transactions',
      query: {'page': '$page', 'pageSize': '$pageSize'},
    );
    return Paged.fromJson(result as Json, WalletTransaction.fromJson);
  }

  // ---------------------------------------------------------------- Khiếu nại

  Future<Dispute> getDispute(int id) async =>
      Dispute.fromJson(await _send('GET', '/disputes/$id') as Json);

  Future<void> respondDispute(
    int id, {
    required String response,
    required List<String> evidenceUrls,
  }) => _send(
    'PUT',
    '/disputes/$id/respond',
    body: {'response': response.trim(), 'evidenceUrls': evidenceUrls},
  );

  // ---------------------------------------------------------------- Đánh giá

  Future<void> createReview({
    required int bookingId,
    required int revieweeId,
    required int rating,
    String? comment,
  }) => _send(
    'POST',
    '/reviews',
    body: {
      'bookingId': bookingId,
      'revieweeId': revieweeId,
      'rating': rating,
      'comment': (comment == null || comment.trim().isEmpty)
          ? null
          : comment.trim(),
    },
  );

  Future<List<Review>> getBookingReviews(int bookingId) async =>
      _parseList(await _send('GET', '/reviews/booking/$bookingId'), Review.fromJson);

  Future<ReviewSummary> getUserReviews(int userId) async =>
      ReviewSummary.fromJson(await _send('GET', '/reviews/user/$userId') as Json);

  Future<void> reportReview(int reviewId) =>
      _send('POST', '/reviews/$reviewId/report');

  // ---------------------------------------------------------------- Thông báo

  Future<NotificationPage> getNotifications({
    int page = 1,
    int pageSize = 20,
    bool unreadOnly = false,
  }) async {
    final result = await _send(
      'GET',
      '/notifications/my',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (unreadOnly) 'unreadOnly': 'true',
      },
    );
    return NotificationPage.fromJson(result as Json);
  }

  Future<int> getUnreadCount() async =>
      (await getNotifications(pageSize: 1)).unreadCount;

  Future<void> markNotificationRead(int id) =>
      _send('PUT', '/notifications/$id/read');

  Future<void> markAllNotificationsRead() =>
      _send('PUT', '/notifications/read-all');

  // ---------------------------------------------------------------- Hồ sơ & ảnh

  Future<Profile> getProfile() async =>
      Profile.fromJson(await _send('GET', '/profile') as Json);

  /// PUT gửi ĐỦ 4 field (Hướng dẫn FE 5.7).
  Future<Profile> updateProfile({
    required String fullName,
    String? phoneNumber,
    String? address,
    String? avatarUrl,
  }) async {
    String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    final result = await _send(
      'PUT',
      '/profile',
      body: {
        'fullName': fullName.trim(),
        'phoneNumber': clean(phoneNumber),
        'address': clean(address),
        'avatarUrl': clean(avatarUrl),
      },
    );
    final profile = Profile.fromJson(result as Json);
    await updateCachedName(profile.fullName);
    return profile;
  }

  /// Tải ảnh JPG/PNG ≤ 5 MB, trả về URL để gửi kèm API khác (Hướng dẫn FE 3.5).
  Future<String> uploadImage(String filePath) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/uploads'))
      ..headers['Accept'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final response = await _guard(() async {
      final streamed = await _http
          .send(request)
          .timeout(const Duration(seconds: 60));
      return http.Response.fromStream(streamed);
    });
    final decoded = await _decode(response, auth: true);
    final url = (decoded as Json?)?['url'] as String?;
    if (url == null) throw const ApiFailure('Tải ảnh thất bại.');
    return url;
  }

  // ---------------------------------------------------------------- Bản đồ & địa chỉ

  static const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _nominatim = 'https://nominatim.openstreetmap.org';
  static const _geoUserAgent = 'HomeService-Mobile/1.0 (vn.homeservice.home_service_mobile)';

  /// Nguồn ảnh nền đang dùng: Backend `/api/geo/tiles` (có cache) hoặc OpenStreetMap trực tiếp
  /// khi Backend chưa có API này / không ra được Internet. Bản đồ tự vẽ lại khi giá trị đổi.
  late final ValueNotifier<String> tileUrl = ValueNotifier(
    '$_baseUrl/geo/tiles/{z}/{x}/{y}.png',
  );

  String get mapTileUrl => tileUrl.value;

  /// Thử tải 1 ô bản đồ qua Backend; lỗi thì chuyển sang OpenStreetMap trực tiếp.
  Future<void> checkMapTiles() async {
    try {
      final response = await _http
          .get(Uri.parse('$_baseUrl/geo/tiles/0/0/0.png'))
          .timeout(const Duration(seconds: 8));
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode == 200 && type.startsWith('image/')) return;
    } catch (_) {
      // không kết nối được Backend => dùng trực tiếp
    }
    tileUrl.value = osmTileUrl;
  }

  Future<String?> reverseGeocode(double latitude, double longitude) async {
    final result = await _send(
      'GET',
      '/geo/reverse',
      query: {'lat': '$latitude', 'lng': '$longitude'},
    );
    return (result as Json?)?['address'] as String?;
  }

  Future<List<Json>> searchPlaces(String query) async {
    final result = await _send('GET', '/geo/search', query: {'q': query});
    return (result as List<dynamic>? ?? const []).cast<Json>();
  }

  // ---- Dự phòng: gọi thẳng Nominatim (OpenStreetMap) khi Backend không tra được địa chỉ

  DateTime _lastNominatim = DateTime.fromMillisecondsSinceEpoch(0);

  Future<dynamic> _nominatimGet(String path, Map<String, String> query) async {
    // Chính sách Nominatim: tối đa ~1 request/giây.
    final wait = _lastNominatim
        .add(const Duration(milliseconds: 1100))
        .difference(DateTime.now());
    if (!wait.isNegative) await Future<void>.delayed(wait);
    _lastNominatim = DateTime.now();
    final uri = Uri.parse('$_nominatim$path').replace(
      queryParameters: {
        'format': 'jsonv2',
        'addressdetails': '1',
        'accept-language': 'vi',
        ...query,
      },
    );
    final response = await _guard(
      () => _http
          .get(uri, headers: {'User-Agent': _geoUserAgent, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12)),
    );
    if (response.statusCode != 200) {
      throw ApiFailure('Không tra được địa chỉ (${response.statusCode}).');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<String?> reverseGeocodeDirect(double latitude, double longitude) async {
    final result = await _nominatimGet('/reverse', {
      'lat': '$latitude',
      'lon': '$longitude',
      'zoom': '18',
    });
    return result is Map<String, dynamic> ? formatOsmAddress(result) : null;
  }

  /// Kết quả cùng dạng với Backend: {latitude, longitude, address, title}.
  Future<List<Json>> searchPlacesDirect(String query) async {
    final result = await _nominatimGet('/search', {
      'q': query,
      'countrycodes': 'vn',
      'limit': '6',
    });
    final items = <Json>[];
    for (final raw in result is List ? result : const []) {
      if (raw is! Map<String, dynamic>) continue;
      final lat = double.tryParse('${raw['lat']}');
      final lon = double.tryParse('${raw['lon']}');
      final address = formatOsmAddress(raw);
      if (lat == null || lon == null || address == null) continue;
      final name = raw['name'] as String?;
      items.add({
        'latitude': lat,
        'longitude': lon,
        'address': address,
        'title': (name == null || name.isEmpty || address.startsWith(name)) ? null : name,
      });
    }
    return items;
  }

  /// Ghép địa chỉ gọn kiểu Việt Nam "số nhà đường, phường, quận, thành phố" (giống Backend).
  static String? formatOsmAddress(Json item) {
    final a = item['address'];
    if (a is Map<String, dynamic>) {
      String? pick(List<String> keys) {
        for (final key in keys) {
          final v = a[key];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
        return null;
      }

      final street = [
        pick(['house_number']),
        pick(['road', 'pedestrian', 'footway', 'residential']),
      ].whereType<String>().join(' ');
      final parts = [
        street.isEmpty ? null : street,
        pick(['quarter', 'neighbourhood', 'suburb', 'village', 'hamlet']),
        pick(['city_district', 'district', 'county', 'town']),
        pick(['city', 'state']),
      ].whereType<String>().toList();
      final unique = <String>[];
      for (final p in parts) {
        if (unique.isEmpty || unique.last != p) unique.add(p);
      }
      if (unique.length >= 2) return unique.join(', ');
    }
    final display = item['display_name'];
    if (display is String && display.isNotEmpty) {
      return display.split(',').take(4).map((s) => s.trim()).join(', ');
    }
    return null;
  }

  // ---------------------------------------------------------------- Lõi gửi request

  List<T> _parseList<T>(dynamic result, T Function(Json) parse) =>
      (result as List<dynamic>? ?? const [])
          .map((item) => parse(item as Json))
          .toList();

  Future<dynamic> _send(
    String method,
    String path, {
    Json? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (auth) {
      if (_token == null) {
        throw const ApiFailure(
          'Vui lòng đăng nhập để tiếp tục.',
          statusCode: 401,
        );
      }
      headers['Authorization'] = 'Bearer $_token';
    }
    final encoded = body == null ? null : jsonEncode(body);

    final response = await _guard(() {
      final Future<http.Response> future = switch (method) {
        'GET' => _http.get(uri, headers: headers),
        'POST' => _http.post(uri, headers: headers, body: encoded),
        'PUT' => _http.put(uri, headers: headers, body: encoded),
        'DELETE' => _http.delete(uri, headers: headers),
        _ => throw ApiFailure('Phương thức không hỗ trợ: $method'),
      };
      return future.timeout(AppConfig.requestTimeout);
    });
    return _decode(response, auth: auth);
  }

  Future<http.Response> _guard(Future<http.Response> Function() run) async {
    try {
      return await run();
    } on HandshakeException {
      throw const ApiFailure(
        'Không tạo được kết nối an toàn tới máy chủ. Hãy kiểm tra ngày giờ trên điện thoại rồi thử lại.',
      );
    } on SocketException {
      if (kDebugMode) debugPrint('Không kết nối được $_baseUrl');
      throw const ApiFailure(
        'Không kết nối được máy chủ. Vui lòng kiểm tra kết nối Internet (Wi-Fi hoặc 4G) rồi thử lại.',
      );
    } on TimeoutException {
      throw const ApiFailure('Máy chủ phản hồi quá lâu. Vui lòng thử lại.');
    } on http.ClientException {
      throw const ApiFailure(
        'Không gửi được yêu cầu. Hãy kiểm tra kết nối mạng.',
      );
    }
  }

  Future<dynamic> _decode(http.Response response, {required bool auth}) async {
    dynamic decoded;
    if (response.bodyBytes.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        decoded = null;
      }
    }
    final code = response.statusCode;
    if (code >= 200 && code < 300) return decoded;

    if (code == 401 && auth) {
      // Token hết hạn hoặc tài khoản bị khóa => về màn hình đăng nhập (SRS FR-03).
      await _clearSession();
      throw const ApiFailure(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        statusCode: 401,
      );
    }
    throw ApiFailure(_messageOf(decoded, code), statusCode: code);
  }

  String _messageOf(dynamic body, int code) {
    if (body is Map<String, dynamic>) {
      final message = body['message'];
      if (message is String && message.isNotEmpty) return message;
      final errors = body['errors'];
      if (errors is Map<String, dynamic>) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) return value.first.toString();
        }
      }
    }
    return switch (code) {
      400 => 'Dữ liệu chưa hợp lệ.',
      401 => 'Email hoặc mật khẩu không đúng.',
      403 => 'Bạn không có quyền thực hiện thao tác này.',
      404 => 'Không tìm thấy dữ liệu.',
      409 => 'Dữ liệu vừa thay đổi, vui lòng tải lại.',
      _ => 'Đã xảy ra lỗi hệ thống. Vui lòng thử lại sau.',
    };
  }
}
