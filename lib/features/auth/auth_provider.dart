import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../models/user.dart';

/// EP01 - US01 (đăng ký), US02 (đăng nhập), US03 (đăng xuất)
class AuthProvider extends ChangeNotifier {
  AuthResult? _current;
  AuthResult? get current => _current;
  bool get isLoggedIn => _current != null;
  UserRole? get role => _current?.role;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null) return;
    // Trong bản đầy đủ nên gọi API /auth/me để lấy lại thông tin user.
    // Ở đây giữ đơn giản: yêu cầu đăng nhập lại nếu app bị đóng hoàn toàn.
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
    required UserRole role,
  }) async {
    final json = await ApiClient.instance.post('/auth/register', auth: false, body: {
      'fullName': fullName,
      'email': email,
      'password': password,
      'phoneNumber': phoneNumber,
      'role': role.index,
    });
    await _saveSession(AuthResult.fromJson(json as Map<String, dynamic>));
  }

  Future<void> login({required String email, required String password}) async {
    final json = await ApiClient.instance.post('/auth/login', auth: false, body: {
      'email': email,
      'password': password,
    });
    await _saveSession(AuthResult.fromJson(json as Map<String, dynamic>));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    _current = null;
    notifyListeners();
  }

  Future<void> _saveSession(AuthResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', result.accessToken);
    _current = result;
    notifyListeners();
  }
}
