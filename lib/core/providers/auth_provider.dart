import 'dart:async';
import 'dart:io';

import 'package:car_mediator_mobile/core/data_sources/remote/api_endpoints.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../features/shared/auth/opt_screen.dart';
import '../../features/shared/cache/init_cache.dart';
import '../../models/user_model.dart';
import '../../widgets/components.dart';
import '../data_sources/local/cache_helper.dart';
import '../data_sources/local/secure_storage.dart';
import '../data_sources/remote/firebase/fcm_service.dart';
import '../data_sources/remote/reverb_service.dart';
import '../helpers/helpers.dart';
import '../helpers/toast_helper.dart';
import '../routing/notification_router.dart';
import '../services/shared/auth_service.dart';
import '../services/shared/device_registration_service.dart';
import 'bottom_navigation_bar_provider.dart';
import 'notification_badge_provider.dart';

class AuthProvider extends ChangeNotifier{
  final AuthService _authService;

  UserResponseModel? loginUserModel;
  UserResponseModel? registerUserModel;
  UserModel? currentUseModel;

  bool isLoggedIn = false;

  final ImagePicker imagePicker = ImagePicker();
  File? uploadLogo;

  AuthProvider(this._authService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _toggleLoading() {
    _isLoading = !_isLoading;
    notifyListeners();
  }

  Future<void> getCurrentUser() async {
    isLoggedIn = await SecureStorage.isLoggedIn();
    final _json = CacheHelper.getCachedCurrentUserData();
    currentUseModel = (_json == null) ? null : UserModel.fromJson(_json);
    // Mirrored into SecureStorage (separate from the Hive cache above)
    // because the FCM background isolate has no Hive/Provider access — this
    // is the only way it can check "does this payload belong to me".
    await SecureStorage.setCurrentUserId(currentUseModel?.id);
    notifyListeners();
  }

  Future<void> register(BuildContext context, {required Map<String, dynamic> body}) async {
    loginUserModel = null;
    _toggleLoading();
    try {
      final _response = await _authService.auth(body: body, path: ApiEndpoints.register);
      if (_response != null) {
        loginUserModel = _response;
        if(loginUserModel?.success ?? false){
          ToastHelper.showSuccess(loginUserModel?.message ?? '');
          navigationPush(context, OptScreen(phoneNumber: body['phoneNumber'],));
        }else{
          ToastHelper.showError(loginUserModel?.message ?? '');
        }
      }
    } catch (e) {
      Helper.logDebug('$runtimeType ---> Failed register: ${e}');
      ToastHelper.showError(e.toString());
    } finally {
      _toggleLoading();
    }
  }

  Future<void> loginWithOtp(BuildContext context, {required Map<String, dynamic> body}) async {
    loginUserModel = null;
    _toggleLoading();
    try {
      final _response = await _authService.auth(body: body, path: ApiEndpoints.loginWithOtp);
      if (_response != null) {
        loginUserModel = _response;
        if(loginUserModel?.success ?? false){
          currentUseModel = loginUserModel?.result?.user;

          await Future.wait([
            _saveCurrentUserDataToCache(currentUseModel),
            SecureStorage.saveToken(loginUserModel?.result?.token ?? ''),
            SecureStorage.setIsLoggedIn(true),
            SecureStorage.setUserRole(loginUserModel?.result?.user?.role ?? ''),
            SecureStorage.setCurrentUserId(currentUseModel?.id),
          ]);

          // Bind this device's token to the freshly-signed-in account, then
          // ask for notification permission now that there's a reason to —
          // not at cold start, where Android 13+ only gives one shot at it.
          unawaited(DeviceRegistrationService.instance.registerCurrentDevice(force: true));
          unawaited(FcmService.requestPermissions());
          if (currentUseModel?.id != null) {
            NotificationRouter.replayAfterLogin(currentUseModel!.id!);
          }

          navigationPushAndRemoveUntil(context, InitCache(userRole: loginUserModel?.result?.user?.role ?? '',));
        }else{
          ToastHelper.showError(loginUserModel?.message ?? '');
        }
      }
    } catch (e) {
      Helper.logDebug('$runtimeType ---> Failed loginWithOtp: ${e}');
      ToastHelper.showError(e.toString());
    } finally {
      _toggleLoading();
    }
  }

  Future<void> logout(BuildContext context) async {
    _toggleLoading();
    try {
      // Revoke this device's push token server-side WHILE the Sanctum token
      // is still valid, in the same request — this is what stops a
      // reused/shared phone from continuing to receive the previous
      // account's notifications after logout.
      final fcmToken = await FirebaseMessaging.instance.getToken();
      await _authService.logout(fcmToken: fcmToken);
    } catch (e) {
      Helper.logDebug('$runtimeType ---> Failed logout: ${e}');
    } finally {
      currentUseModel = null;
      await Future.wait([
        CacheHelper.deleteCurrentUserData(),
        SecureStorage.deleteToken(),
        SecureStorage.setIsLoggedIn(false),
        SecureStorage.deleteUserRole(),
        SecureStorage.setCurrentUserId(null),
        SecureStorage.setRegisteredFcmToken(null),
      ]);

      // Deleting the token guarantees the NEXT signed-in account (on a
      // reused/shared device) gets a fresh token rather than inheriting
      // this one — combined with the server-side revoke above, this closes
      // the cross-account leakage path from both ends.
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
      FcmService.unsubscribeFromTopic('all');
      // NOT FcmService.disposeListeners() — those subscriptions are meant to
      // live for the whole app process (see initializeFirebase()'s doc
      // comment). Nothing re-initializes them if a different account signs
      // in later without an app restart, and every handler downstream
      // already no-ops correctly with nobody signed in.
      try {
        await FcmService.localNotificationsPlugin.cancelAll();
      } catch (_) {}
      ReverbService.instance.disconnect();

      if (context.mounted) {
        context.read<NotificationBadgeProvider>().clearAll();
        context.read<BottomNavigationBarProvider>().setCurrentIndex(context, 0);
        navigationPushAndRemoveUntil(context, InitCache(userRole: null,));
      }
      _toggleLoading();
    }
  }

  Future<void> _saveCurrentUserDataToCache(UserModel? currentUseModel) async {
    if(currentUseModel != null){
      await CacheHelper.cacheCurrentUserData({
        'id': currentUseModel.id,
        'name': currentUseModel.name,
        'logo': currentUseModel.logo,
        'phone': currentUseModel.phoneNumber,
        'company_name_ar': currentUseModel.companyNameAr,
        'company_name_en': currentUseModel.companyNameEn,
      });
    }
  }

  Future initialization() async{
    uploadLogo = null;
  }
}
