import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../data_sources/local/secure_storage.dart';
import '../../data_sources/remote/api_service.dart';
import '../../errors/api_exceptions.dart';
import '../../helpers/helpers.dart';

/// Registers/unregisters this device's FCM token with the backend's
/// per-device token table (see the notification upgrade plan, Phase 1).
/// This is what lets one account receive pushes on every signed-in device,
/// and what stops a reused/shared phone from keeping the previous account's
/// notifications after logout.
class DeviceRegistrationService {
  DeviceRegistrationService._internal();

  static final DeviceRegistrationService instance = DeviceRegistrationService._internal();

  /// Registers the current FCM token, unless it's the same token we already
  /// successfully registered (skips a redundant call on every app start).
  Future<void> registerCurrentDevice({bool force = false}) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      if (!force) {
        final lastRegistered = await SecureStorage.getRegisteredFcmToken();
        if (lastRegistered == token) return;
      }

      final deviceId = await SecureStorage.getOrCreateDeviceId();
      final body = <String, dynamic>{
        'fcmToken': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'deviceId': deviceId,
      };

      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final android = await deviceInfo.androidInfo;
          body['deviceModel'] = android.model;
          body['osVersion'] = 'Android ${android.version.release}';
        } else if (Platform.isIOS) {
          final ios = await deviceInfo.iosInfo;
          body['deviceModel'] = ios.utsname.machine;
          body['osVersion'] = ios.systemVersion;
        }
      } catch (_) {}

      await ApiService().postData('notifications/devices/register', body: body);
      await SecureStorage.setRegisteredFcmToken(token);
    } on ApiException catch (e) {
      // Registering a device must never block login/app-start — an
      // unreachable or older backend without this endpoint yet should not
      // surface an error to the user.
      Helper.logDebug('[DeviceRegistrationService] register failed: ${e.message}');
    } catch (e) {
      Helper.logDebug('[DeviceRegistrationService] register failed: $e');
    }
  }

  /// Unregisters this device's current token. Call BEFORE clearing the auth
  /// token on logout — the request needs it to authenticate.
  Future<void> unregisterCurrentDevice() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      await ApiService().postData('notifications/devices/unregister', body: {'fcmToken': token});
      await SecureStorage.setRegisteredFcmToken(null);
    } catch (e) {
      Helper.logDebug('[DeviceRegistrationService] unregister failed: $e');
    }
  }
}
