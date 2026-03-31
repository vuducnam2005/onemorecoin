import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// Service gọi REST API backend
/// Hỗ trợ: Auto-refresh token, device binding, idempotency
class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  String? _accessToken;
  String? _refreshToken;
  bool _isRefreshing = false;

  // ========================
  // TOKEN MANAGEMENT
  // ========================

  /// Lấy access token đã lưu
  Future<String?> getToken() async {
    if (_accessToken != null) return _accessToken;
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('jwt_token');
    _refreshToken = prefs.getString('refresh_token');
    return _accessToken;
  }

  /// Lưu cả access + refresh token
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  /// Lưu access token (backward compat)
  Future<void> saveToken(String token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  /// Xoá token khi đăng xuất
  Future<void> clearToken() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('refresh_token');
  }

  /// Kiểm tra có token không
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Headers chuẩn cho mọi request
  Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ========================
  // AUTO-REFRESH TOKEN
  // ========================

  /// Tự động refresh token khi nhận 401
  /// Nếu refresh cũng fail → trả false (cần login lại)
  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing) return false; // Tránh concurrent refresh
    _isRefreshing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = _refreshToken ?? prefs.getString('refresh_token');

      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.refreshToken),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refreshToken': refreshToken,
          'deviceId': await _getDeviceId(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(
          accessToken: data['token'],
          refreshToken: data['refreshToken'],
        );
        return true;
      } else {
        // Refresh thất bại → cần login lại
        await clearToken();
        return false;
      }
    } catch (e) {
      print('[ApiService] Refresh token error: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Device ID đơn giản (dùng shared_preferences)
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }

  /// Kiểm tra server có hoạt động không
  Future<bool> isServerReachable() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.health))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ========================
  // AUTH
  // ========================

  /// Đăng ký tài khoản mới
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'displayName': displayName ?? username,
          'deviceId': await _getDeviceId(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        await saveTokens(
          accessToken: data['token'],
          refreshToken: data['refreshToken'] ?? '',
        );
        return {'success': true, 'user': data['user'], 'token': data['token']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Đăng ký thất bại'};
      }
    } on SocketException {
      return {'success': false, 'error': 'Không thể kết nối đến server'};
    } catch (e) {
      return {'success': false, 'error': 'Lỗi: $e'};
    }
  }

  /// Đăng nhập
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'deviceId': await _getDeviceId(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await saveTokens(
          accessToken: data['token'],
          refreshToken: data['refreshToken'] ?? '',
        );
        return {'success': true, 'user': data['user'], 'token': data['token']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Đăng nhập thất bại'};
      }
    } on SocketException {
      return {'success': false, 'error': 'Không thể kết nối đến server'};
    } catch (e) {
      return {'success': false, 'error': 'Lỗi: $e'};
    }
  }

  /// Lấy thông tin profile
  Future<Map<String, dynamic>> getProfile() async {
    return await _authenticatedGet(ApiConfig.profile);
  }

  /// Cập nhật profile
  Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? username,
  }) async {
    return await _authenticatedPut(ApiConfig.profile, {
      if (displayName != null) 'displayName': displayName,
      if (username != null) 'username': username,
    });
  }

  /// Đổi mật khẩu
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    return await _authenticatedPut(ApiConfig.changePassword, {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
  }

  // ========================
  // AUTHENTICATED REQUEST HELPERS (auto-refresh)
  // ========================

  Future<Map<String, dynamic>> _authenticatedGet(String url) async {
    var result = await get(url);
    if (result['statusCode'] == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        result = await get(url);
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> _authenticatedPut(String url, Map<String, dynamic> body) async {
    var result = await put(url, body);
    if (result['statusCode'] == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        result = await put(url, body);
      }
    }
    return result;
  }

  // ========================
  // GENERIC CRUD HELPERS
  // ========================

  /// GET request
  Future<Map<String, dynamic>> get(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: await _headers(),
      );
      return {
        'success': response.statusCode == 200,
        'data': jsonDecode(response.body),
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'error': 'Lỗi: $e'};
    }
  }

  /// POST request (auto-refresh on 401)
  Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) async {
    try {
      var response = await http.post(
        Uri.parse(url),
        headers: await _headers(),
        body: jsonEncode(body),
      );

      // Auto-refresh nếu 401
      if (response.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          response = await http.post(
            Uri.parse(url),
            headers: await _headers(),
            body: jsonEncode(body),
          );
        }
      }

      return {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'data': jsonDecode(response.body),
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'error': 'Lỗi: $e'};
    }
  }

  /// PUT request (auto-refresh on 401)
  Future<Map<String, dynamic>> put(String url, Map<String, dynamic> body) async {
    try {
      var response = await http.put(
        Uri.parse(url),
        headers: await _headers(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          response = await http.put(
            Uri.parse(url),
            headers: await _headers(),
            body: jsonEncode(body),
          );
        }
      }

      return {
        'success': response.statusCode == 200,
        'data': jsonDecode(response.body),
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'error': 'Lỗi: $e'};
    }
  }

  /// DELETE request (auto-refresh on 401)
  Future<Map<String, dynamic>> delete(String url) async {
    try {
      var response = await http.delete(
        Uri.parse(url),
        headers: await _headers(),
      );

      if (response.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          response = await http.delete(
            Uri.parse(url),
            headers: await _headers(),
          );
        }
      }

      return {
        'success': response.statusCode == 200,
        'data': jsonDecode(response.body),
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'error': 'Lỗi: $e'};
    }
  }

  // ========================
  // SYNC
  // ========================

  /// Upload toàn bộ dữ liệu local lên server
  Future<Map<String, dynamic>> syncUpload(Map<String, dynamic> allData) async {
    return await post(ApiConfig.syncUpload, allData);
  }

  /// Download toàn bộ dữ liệu từ server về local
  Future<Map<String, dynamic>> syncDownload() async {
    return await get(ApiConfig.syncDownload);
  }
}
