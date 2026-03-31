import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/database_helper.dart';
import '../services/api_service.dart';
import '../services/api_config.dart';
import '../services/sync_service.dart';
import '../services/sync_queue.dart';

class StorageStageProxy extends ChangeNotifier {
  bool _isLogin = false;
  Map<String, dynamic>? _currentUser;
  bool _isOnline = false;

  StorageStageProxy() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLogin = prefs.getBool('isLogin') ?? false;
    final userStr = prefs.getString('user');
    if (userStr != null) {
      _currentUser = jsonDecode(userStr);
    }
    // Kiểm tra server có hoạt động không
    _isOnline = await ApiService.instance.isServerReachable();
    notifyListeners();
  }

  bool get isLogin => _isLogin;
  bool get isOnline => _isOnline;

  set isLogin(bool value) {
    _isLogin = value;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('isLogin', value);
    });
    notifyListeners();
  }

  Future<void> saveInfoUser(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> getInfoUserAsync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// Đăng ký: Thử API trước, nếu không có mạng thì lưu local
  Future<String?> registerUser({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    // Thử đăng ký qua API trước
    _isOnline = await ApiService.instance.isServerReachable();

    if (_isOnline) {
      final result = await ApiService.instance.register(
        username: username,
        email: email,
        password: password,
        displayName: displayName,
      );

      if (result['success'] == true) {
        // Đăng ký API thành công -> lưu user info vào local
        final user = result['user'];
        await _saveUserLocally(
          id: user['id'],
          username: user['username'],
          email: user['email'],
          displayName: user['displayName'] ?? displayName,
        );

        // Cũng lưu vào SQLite local để dùng offline
        final db = await DatabaseHelper.instance.database;
        try {
          await db.insert('users', {
            'id': user['id'],
            'username': user['username'],
            'email': user['email'],
            'password': _hashPassword(password),
          });
        } catch (_) {
          // Bỏ qua nếu user đã tồn tại trong local
        }

        // Tạo nhóm mặc định trên server
        await ApiService.instance.post(
          ApiConfig.groupsInit,
          {},
        );

        return null; // Thành công
      } else {
        return result['error'];
      }
    }

    // Fallback: Đăng ký local (offline)
    final db = await DatabaseHelper.instance.database;

    final usernameCheck = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (usernameCheck.isNotEmpty) {
      return "Tên đăng nhập đã tồn tại";
    }

    final emailCheck = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (emailCheck.isNotEmpty) {
      return "Email đã được sử dụng";
    }

    final randomDigits = 10000 + DateTime.now().millisecondsSinceEpoch % 90000;
    final id = '17710$randomDigits';
    await db.insert('users', {
      'id': id,
      'username': username,
      'email': email,
      'password': _hashPassword(password),
    });

    saveInfoUser("displayName_$username", displayName);

    return null; // success
  }

  /// Đăng nhập: Thử API trước, nếu không có mạng thì dùng local
  Future<String?> loginUser({
    required String username,
    required String password,
  }) async {
    // Thử đăng nhập qua API trước
    _isOnline = await ApiService.instance.isServerReachable();

    if (_isOnline) {
      final result = await ApiService.instance.login(
        username: username,
        password: password,
      );

      if (result['success'] == true) {
        final user = result['user'];
        await _saveUserLocally(
          id: user['id'],
          username: user['username'],
          email: user['email'],
          displayName: user['displayName'] ?? user['username'],
        );

        // Cũng cập nhật SQLite local
        final db = await DatabaseHelper.instance.database;
        final existing = await db.query('users', where: 'id = ?', whereArgs: [user['id']]);
        if (existing.isEmpty) {
          try {
            await db.insert('users', {
              'id': user['id'],
              'username': user['username'],
              'email': user['email'],
              'password': _hashPassword(password),
            });
          } catch (_) {}
        }

        // Tự động kéo dữ liệu từ server về máy
        await SyncService.instance.downloadAllData();

        isLogin = true;
        return null; // Thành công
      } else {
        return result['error'];
      }
    }

    // Fallback: Đăng nhập local (offline)
    final db = await DatabaseHelper.instance.database;
    final hashedPassword = _hashPassword(password);

    final result = await db.query(
      'users',
      where: '(username = ? OR email = ?) AND password = ?',
      whereArgs: [username, username, hashedPassword],
    );

    if (result.isEmpty) {
      return "Sai tên đăng nhập hoặc mật khẩu";
    }

    final user = result.first;
    final displayName = await getInfoUserAsync("displayName_${user['username']}") ?? user['username'];

    await _saveUserLocally(
      id: user['id'].toString(),
      username: user['username'].toString(),
      email: user['email'].toString(),
      displayName: displayName.toString(),
    );

    isLogin = true;
    return null; // success
  }

  /// Lưu thông tin user vào SharedPreferences
  Future<void> _saveUserLocally({
    required String id,
    required String username,
    required String email,
    required String displayName,
  }) async {
    final userJson = jsonEncode({
      'id': id,
      'name': displayName,
      'email': email,
      'username': username,
    });

    await saveInfoUser('user', userJson);
    await saveInfoUser("displayName_$username", displayName);
    _currentUser = jsonDecode(userJson);
  }

  /// Đổi mật khẩu: Thử API trước
  Future<String?> changePassword({
    required String username,
    required String oldPassword,
    required String newPassword,
  }) async {
    _isOnline = await ApiService.instance.isServerReachable();

    if (_isOnline) {
      final result = await ApiService.instance.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      if (result['success'] == true) {
        // Cũng cập nhật local
        final db = await DatabaseHelper.instance.database;
        await db.update(
          'users',
          {'password': _hashPassword(newPassword)},
          where: 'username = ?',
          whereArgs: [username],
        );
        return null;
      } else {
        return result['error'];
      }
    }

    // Fallback: Offline
    final db = await DatabaseHelper.instance.database;
    final hashedOldPassword = _hashPassword(oldPassword);

    final result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, hashedOldPassword],
    );

    if (result.isEmpty) {
      return "Mật khẩu cũ không chính xác";
    }

    final hashedNewPassword = _hashPassword(newPassword);
    await db.update(
      'users',
      {'password': hashedNewPassword},
      where: 'username = ?',
      whereArgs: [username],
    );

    return null; // success
  }

  /// Cập nhật profile: Thử API trước
  Future<String?> updateProfile({
    required String oldUsername,
    required String newUsername,
    required String newName,
  }) async {
    _isOnline = await ApiService.instance.isServerReachable();

    if (_isOnline) {
      final result = await ApiService.instance.updateProfile(
        displayName: newName,
        username: newUsername,
      );

      if (result['success'] != true) {
        return result['error'];
      }
    }

    // Cũng cập nhật local
    final db = await DatabaseHelper.instance.database;

    if (oldUsername != newUsername) {
      final usernameCheck = await db.query('users', where: 'username = ?', whereArgs: [newUsername]);
      if (usernameCheck.isNotEmpty && !_isOnline) {
        return "Tên đăng nhập đã tồn tại";
      }

      await db.update('users', {'username': newUsername}, where: 'username = ?', whereArgs: [oldUsername]);

      final prefs = await SharedPreferences.getInstance();

      final phone = prefs.getString("phone_$oldUsername");
      if (phone != null) {
        await prefs.setString("phone_$newUsername", phone);
        await prefs.remove("phone_$oldUsername");
      }

      final pin = prefs.getString("pin_$oldUsername");
      if (pin != null) {
        await prefs.setString("pin_$newUsername", pin);
        await prefs.remove("pin_$oldUsername");
      }

      await prefs.remove("displayName_$oldUsername");
    }

    await saveInfoUser("displayName_$newUsername", newName);

    if (_currentUser != null) {
      _currentUser!['name'] = newName;
      _currentUser!['username'] = newUsername;
      await saveInfoUser('user', jsonEncode(_currentUser));
      notifyListeners();
    }

    return null; // success
  }

  Future<void> savePhone(String username, String phone) async {
    await saveInfoUser("phone_$username", phone);
  }

  Future<String?> getPhone(String username) async {
    return await getInfoUserAsync("phone_$username");
  }

  Future<void> savePin(String username, String pinCode) async {
    final hashedPin = _hashPassword(pinCode);
    await saveInfoUser("pin_$username", hashedPin);
  }

  Future<void> removePin(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("pin_$username");
  }

  Future<bool> verifyPin(String username, String pinCode) async {
    final savedPinHash = await getInfoUserAsync("pin_$username");
    if (savedPinHash == null) {
      return true;
    }
    return savedPinHash == _hashPassword(pinCode);
  }

  Future<bool> hasPin(String username) async {
    final savedPinHash = await getInfoUserAsync("pin_$username");
    return savedPinHash != null;
  }

  Map<String, dynamic>? getCurrentUser() {
    return _currentUser;
  }

  Future<void> logoutUser() async {
    // 1. Flush sync queue trước khi đăng xuất
    final isOnline = await ApiService.instance.isServerReachable();
    if (isOnline) {
      // Flush pending queue
      await SyncQueue.instance.processQueue();
      // Upload full data as final backup
      await SyncService.instance.uploadAllData();
      // Revoke refresh token trên server
      try {
        final prefs = await SharedPreferences.getInstance();
        final refreshToken = prefs.getString('refresh_token');
        if (refreshToken != null) {
          await ApiService.instance.post(ApiConfig.logout, {
            'refreshToken': refreshToken,
          });
        }
      } catch (_) {}
    }

    // 2. Clear local state
    isLogin = false;
    _currentUser = null;
    await ApiService.instance.clearToken(); // Xoá cả access + refresh token
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    
    /// 3. Xoá dữ liệu local (bao gồm pending_actions queue)
    await DatabaseHelper.instance.clearUserData();
    
    notifyListeners();
  }

  /// Kiểm tra lại trạng thái online
  Future<void> checkOnlineStatus() async {
    _isOnline = await ApiService.instance.isServerReachable();
    notifyListeners();
  }
}
