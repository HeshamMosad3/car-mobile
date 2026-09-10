import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {

  static const _storage = FlutterSecureStorage();

  static const String _tokenKey = 'auth_token_key';
  static const String _isLoggedIn = 'is_logged_in_key';
  static const String _userNameKey = 'user_name_key';
  static const String _userPhoneKey = 'user_phone_key';
  static const String _userLogoKey = 'user_logo_key';
  static const String _useRoleKey = 'user_role_key';
  static const String _companyNameAr = 'company_name_ar_key';
  static const String _companyNameEn = 'company_name_en_key';
  static const String _notificationsCounterKey = 'notification_counter_key';
  static const String _currentUserIdKey = 'current_user_id_key';
  static const String _deviceIdKey = 'device_id_key';
  static const String _registeredFcmTokenKey = 'registered_fcm_token_key';


  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<void> setIsLoggedIn(bool isLogin) async {
    await _storage.write(key: _isLoggedIn, value: isLogin.toString());
  }

  static Future<void> setUserRole(String role) async {
    await _storage.write(key: _useRoleKey, value: role);
  }

  static Future<bool> isLoggedIn() async {
    String? value = await _storage.read(key: _isLoggedIn);
    if (value == null) return false;
    return value.toLowerCase() == 'true';
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<String?> getUserRole() async {
    return await _storage.read(key: _useRoleKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<void> deleteUserRole() async {
    await _storage.delete(key: _useRoleKey);
  }

  /// Cached separately from the full user JSON (which lives in Hive) because
  /// the FCM background isolate has no Flutter widget tree / Provider access
  /// — this is the only signal it has for "does this payload belong to me".
  static Future<void> setCurrentUserId(int? userId) async {
    if (userId == null) {
      await _storage.delete(key: _currentUserIdKey);
    } else {
      await _storage.write(key: _currentUserIdKey, value: userId.toString());
    }
  }

  static Future<int?> getCurrentUserId() async {
    final value = await _storage.read(key: _currentUserIdKey);
    return value == null ? null : int.tryParse(value);
  }

  /// A stable per-install identifier, generated once, used to let the server
  /// revoke a device's previous token when its FCM token rotates.
  static Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  /// The last FCM token this device successfully registered with the
  /// backend — lets us skip a redundant register call when the token hasn't
  /// actually changed.
  static Future<void> setRegisteredFcmToken(String? token) async {
    if (token == null) {
      await _storage.delete(key: _registeredFcmTokenKey);
    } else {
      await _storage.write(key: _registeredFcmTokenKey, value: token);
    }
  }

  static Future<String?> getRegisteredFcmToken() async {
    return await _storage.read(key: _registeredFcmTokenKey);
  }

  static Future<void> saveUserData({required String name, required String phone, required String logo, String? companyNameAr, String? companyNameEn}) async {
    await Future.wait([
    _storage.write(key: _userNameKey, value: name),
    _storage.write(key: _userPhoneKey, value: phone),
    _storage.write(key: _userLogoKey, value: logo),
    _storage.write(key: _companyNameAr, value: companyNameAr),
    _storage.write(key: _companyNameEn, value: companyNameEn),
    ]);
  }

  static Future<void> addNotificationCount() async {
    String? value = await _storage.read(key: _notificationsCounterKey);
    int _count = int.parse(value ?? '0') + 1;
    await _storage.write(key: _notificationsCounterKey, value: _count.toString());
  }

  static Future<String?> getUserName() async {
    return await _storage.read(key: _userNameKey);
  }

  static Future<String?> getUserPhone() async {
    return await _storage.read(key: _userPhoneKey);
  }
  static Future<String?> getLogo () async {
    return await _storage.read(key: _userLogoKey);
  }

  static Future<String?> getCompanyNameAr() async {
    return await _storage.read(key: _companyNameAr);
  }

  static Future<String?> getCompanyNameEn() async {
    return await _storage.read(key: _companyNameEn);
  }

  static Future<void> clearAllUserData() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _userNameKey),
      _storage.delete(key: _userPhoneKey),
      _storage.delete(key: _userLogoKey),
      _storage.delete(key: _companyNameAr),
      _storage.delete(key: _companyNameEn),
    ]);
  }

  static Future<void> deleteAll() async {
     await _storage.deleteAll();
  }
}

// example: await SecureStorage.saveToken(token);