import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._(
    this._preferences,
    this._httpClient,
    this._secureStorage,
    String baseUrl,
  ) : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      currentUser = _readUser(_preferences);

  static const _tokenKey = 'access_token';
  static const _nameKey = 'user_name';
  static const _emailKey = 'user_email';
  static const _roleKey = 'user_role';
  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  final SharedPreferences _preferences;
  final http.Client _httpClient;
  final FlutterSecureStorage _secureStorage;
  final String _baseUrl;
  String? _token;
  UserSession? currentUser;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  static Future<ApiClient> create() async {
    final preferences = await SharedPreferences.getInstance();
    final api = ApiClient._(
      preferences,
      http.Client(),
      const FlutterSecureStorage(),
      _defaultBaseUrl,
    );
    api._token = await api._secureStorage.read(key: _tokenKey);
    return api;
  }

  static UserSession? _readUser(SharedPreferences preferences) {
    final name = preferences.getString(_nameKey);
    final email = preferences.getString(_emailKey);
    final role = preferences.getInt(_roleKey);
    if (name == null || email == null || role == null) return null;
    return UserSession(fullName: name, email: email, role: role);
  }

  Future<void> login(String email, String password) async {
    final result = await _send(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );
    await _saveSession(result as Map<String, dynamic>);
  }

  Future<void> register({
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
        'fullName': fullName,
        'email': email,
        'password': password,
        'phoneNumber': phoneNumber.isEmpty ? null : phoneNumber,
        'role': role,
      },
      requiresAuth: false,
    );
    await _saveSession(result as Map<String, dynamic>);
  }

  Future<void> _saveSession(Map<String, dynamic> response) async {
    final token = response['accessToken'] as String?;
    final name = response['fullName'] as String?;
    final email = response['email'] as String?;
    final role = response['role'] as int?;
    if (token == null || name == null || email == null || role == null) {
      throw const ApiFailure('Phản hồi đăng nhập không hợp lệ.');
    }

    await _secureStorage.write(key: _tokenKey, value: token);
    await _preferences.setString(_nameKey, name);
    await _preferences.setString(_emailKey, email);
    await _preferences.setInt(_roleKey, role);
    _token = token;
    currentUser = UserSession(fullName: name, email: email, role: role);
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: _tokenKey);
    await _preferences.remove(_nameKey);
    await _preferences.remove(_emailKey);
    await _preferences.remove(_roleKey);
    _token = null;
    currentUser = null;
  }

  Future<List<ServiceCategory>> getCategories() async {
    final result = await _send('GET', '/servicecategories');
    return (result as List<dynamic>)
        .map((item) => ServiceCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Booking> createBooking({
    required ServiceCategory category,
    required DateTime scheduledTime,
    required String address,
    required String note,
    required int quantity,
    required int paymentMethod,
    required double latitude,
    required double longitude,
  }) async {
    final result = await _send(
      'POST',
      '/bookings',
      body: {
        'serviceCategoryId': category.id,
        'scheduledTime': scheduledTime.toUtc().toIso8601String(),
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'note': note.isEmpty ? null : note,
        'quantity': quantity,
        'paymentMethod': paymentMethod,
        'customerPresent': paymentMethod == 0,
      },
    );
    return Booking.fromJson(result as Map<String, dynamic>);
  }

  Future<Booking> getBooking(int id) async {
    final result = await _send('GET', '/bookings/$id');
    return Booking.fromJson(result as Map<String, dynamic>);
  }

  Future<void> payBooking(int bookingId, int method) async {
    await _send(
      'POST',
      '/payments',
      body: {'bookingId': bookingId, 'method': method},
    );
  }

  Future<List<Booking>> getMyBookings() async {
    final result = await _send('GET', '/bookings/my');
    return (result as List<dynamic>)
        .map((item) => Booking.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TaskerOffer>> getMyOffers() async {
    final result = await _send('GET', '/offers/my');
    return (result as List<dynamic>)
        .map((item) => TaskerOffer.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> acceptOffer(int bookingId) async {
    await _send('POST', '/bookings/$bookingId/accept');
  }

  Future<void> rejectOffer(int bookingId) async {
    await _send('POST', '/bookings/$bookingId/reject');
  }

  Future<void> setTaskerAvailability(bool isAvailable) async {
    await _send(
      'PUT',
      '/taskers/availability',
      body: {'isAvailable': isAvailable},
    );
  }

  Future<bool> getTaskerAvailability() async {
    try {
      final profile = await _send('GET', '/taskers/profile');
      return (profile as Map<String, dynamic>)['isAvailable'] as bool;
    } on ApiFailure catch (error) {
      if (error.message.contains('(HTTP 404)')) {
        throw const ApiFailure(
          'Hồ sơ Tasker chưa được thiết lập. Vui lòng hoàn tất hồ sơ trước khi nhận đơn.',
        );
      }
      rethrow;
    }
  }

  Future<NotificationBatch> getNotifications() async {
    final result = await _send('GET', '/notifications/my');
    return NotificationBatch.fromJson(result as Map<String, dynamic>);
  }

  Future<void> markNotificationRead(int id) async {
    await _send('PUT', '/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _send('PUT', '/notifications/read-all');
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (requiresAuth && isAuthenticated) {
      headers['Authorization'] = 'Bearer $_token';
    } else if (requiresAuth) {
      throw const ApiFailure('Vui lòng đăng nhập để tiếp tục.');
    }

    try {
      final response = switch (method) {
        'GET' =>
          await _httpClient
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20)),
        'POST' =>
          await _httpClient
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 20)),
        'PUT' =>
          await _httpClient
              .put(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(const Duration(seconds: 20)),
        _ => throw ApiFailure('Phương thức API không được hỗ trợ: $method'),
      };

      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiFailure(_errorMessage(decoded, response.statusCode));
      }
      return decoded;
    } on ApiFailure {
      rethrow;
    } on SocketException {
      throw const ApiFailure(
        'Không kết nối được máy chủ. Hãy kiểm tra backend và địa chỉ API.',
      );
    } on TimeoutException {
      throw const ApiFailure('Máy chủ phản hồi quá lâu. Vui lòng thử lại.');
    } on http.ClientException {
      throw const ApiFailure(
        'Không gửi được yêu cầu đến máy chủ. Hãy kiểm tra kết nối mạng.',
      );
    } on FormatException {
      throw const ApiFailure('Máy chủ trả về dữ liệu không hợp lệ.');
    }
  }

  String _errorMessage(dynamic response, int statusCode) {
    if (response is Map<String, dynamic>) {
      final message = response['message'] ?? response['detail'];
      if (message is String && message.isNotEmpty) return message;
      final errors = response['errors'];
      if (errors is Map<String, dynamic>) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) return value.first.toString();
          if (value is String && value.isNotEmpty) return value;
        }
      }
      final title = response['title'];
      if (title is String && title.isNotEmpty) return title;
    }
    return 'Yêu cầu thất bại (HTTP $statusCode). Vui lòng thử lại.';
  }
}

class UserSession {
  const UserSession({
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String fullName;
  final String email;
  final int role;
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.unit,
    this.iconUrl,
  });

  final int id;
  final String name;
  final String? description;
  final double basePrice;
  final String unit;
  final String? iconUrl;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      basePrice: (json['basePrice'] as num).toDouble(),
      unit: json['unit'] as String,
      iconUrl: json['iconUrl'] as String?,
    );
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.serviceCategoryName,
    required this.scheduledTime,
    required this.address,
    required this.totalPrice,
    required this.status,
    this.taskerName,
  });

  final int id;
  final String serviceCategoryName;
  final DateTime scheduledTime;
  final String address;
  final double totalPrice;
  final int status;
  final String? taskerName;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as int,
      serviceCategoryName: json['serviceCategoryName'] as String,
      scheduledTime: DateTime.parse(json['scheduledTime'] as String).toLocal(),
      address: json['address'] as String,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      status: json['status'] as int,
      taskerName: json['taskerName'] as String?,
    );
  }
}

class TaskerOffer {
  const TaskerOffer({
    required this.offerId,
    required this.bookingId,
    required this.serviceCategoryName,
    required this.address,
    required this.scheduledTime,
    required this.distanceKm,
    required this.totalPrice,
    required this.estimatedCommission,
    required this.expiresAt,
    required this.wave,
    required this.quantity,
    this.note,
    this.customerRatingAverage,
  });

  final int offerId;
  final int bookingId;
  final String serviceCategoryName;
  final String address;
  final DateTime scheduledTime;
  final double distanceKm;
  final double totalPrice;
  final double estimatedCommission;
  final DateTime expiresAt;
  final int wave;
  final int quantity;
  final String? note;
  final double? customerRatingAverage;

  factory TaskerOffer.fromJson(Map<String, dynamic> json) {
    return TaskerOffer(
      offerId: json['offerId'] as int,
      bookingId: json['bookingId'] as int,
      serviceCategoryName: json['serviceCategoryName'] as String,
      address: json['address'] as String,
      scheduledTime: DateTime.parse(json['scheduledTime'] as String).toLocal(),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      estimatedCommission: (json['estimatedCommission'] as num).toDouble(),
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
      wave: json['wave'] as int,
      quantity: json['quantity'] as int,
      note: json['note'] as String?,
      customerRatingAverage: (json['customerRatingAverage'] as num?)
          ?.toDouble(),
    );
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int,
      title: json['title'] as String,
      message: json['message'] as String,
      isRead: json['isRead'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}

class NotificationBatch {
  const NotificationBatch({required this.items, required this.unreadCount});

  final List<NotificationItem> items;
  final int unreadCount;

  factory NotificationBatch.fromJson(Map<String, dynamic> json) {
    return NotificationBatch(
      items: (json['items'] as List<dynamic>)
          .map(
            (item) => NotificationItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      unreadCount: json['unreadCount'] as int,
    );
  }
}
