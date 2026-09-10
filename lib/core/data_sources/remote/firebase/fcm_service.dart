import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:car_mediator_mobile/core/helpers/helpers.dart';
import 'package:car_mediator_mobile/core/utils/connection_utils.dart';
import 'package:car_mediator_mobile/core/utils/context_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../../../models/notification_payload.dart';
import '../../../providers/conversation_provider.dart';
import '../../../providers/notification_badge_provider.dart';
import '../../../routing/notification_router.dart';
import '../../../services/shared/device_registration_service.dart';
import '../../local/secure_storage.dart';

/// Top-level, NOT a class method: Android runs this in a separate isolate
/// with no access to any state from the main isolate, and only a genuine
/// top-level `@pragma('vm:entry-point')` function survives release-mode AOT
/// tree-shaking as a valid entry point — a static class method silently
/// never runs there.
@pragma('vm:entry-point')
Future<void> fcmBackgroundMessageHandler(RemoteMessage message) async {
  // Required: this isolate has no Firebase state of its own.
  await Firebase.initializeApp();

  final payload = NotificationPayload.fromRemoteMessage(message);

  // Correct-user guard inside the isolate too: suppress rendering a push
  // addressed to a different account than the one signed in on this device.
  final myId = await SecureStorage.getCurrentUserId();
  if (payload.recipientId != null && myId != null && payload.recipientId != myId) {
    return;
  }

  if (message.notification != null) {
    SecureStorage.addNotificationCount();
  }

  // Only render locally when the server did NOT send a `notification` block
  // — otherwise the FCM SDK already displayed it, and rendering again would
  // double the tray entry.
  if (message.notification == null && payload.title.isNotEmpty) {
    await FcmService._showLocalNotification(payload);
  }
}

class FcmService {
  static FirebaseMessaging? _firebaseMessaging;
  static FirebaseMessaging get firebaseMessaging => FcmService._firebaseMessaging ?? FirebaseMessaging.instance;

  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onOpenedSub;
  static StreamSubscription<String>? _onTokenRefreshSub;

  static bool _initialized = false;

  /// Call ONCE from main(), before runApp. Registering listeners more than
  /// once (e.g. from a screen's initState) used to create duplicate
  /// FirebaseMessaging.onMessage subscriptions — this guard makes that
  /// impossible regardless of how many times initialize() is called.
  static Future<void> initializeFirebase() async {
    if (_initialized) return;
    _initialized = true;

    try {
      FcmService._firebaseMessaging = FirebaseMessaging.instance;

      await FcmService.initializeLocalNotifications();

      FirebaseMessaging.onBackgroundMessage(fcmBackgroundMessageHandler);

      _onMessageSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromBackground);
      _onTokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);
    } catch (e) {
      log('[FcmService] initializeFirebase error: $e');
    }
  }

  /// Cancels every listener this service registered — call on logout so a
  /// subsequent login doesn't end up with stacked subscriptions and so a
  /// signed-out device stops reacting to messages entirely.
  static Future<void> disposeListeners() async {
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
    await _onTokenRefreshSub?.cancel();
    _onMessageSub = null;
    _onOpenedSub = null;
    _onTokenRefreshSub = null;
    _initialized = false;
  }

  static Future<String?> getDeviceTokenFCM() async {
    try {
      String? _token = await FcmService.firebaseMessaging.getToken();
      Helper.logDebug('FCMServices------token----- $_token ');
      return _token;
    } catch (e) {
      Helper.logDebug("❌ Error getting FCM token: $e");
      return null;
    }
  }

  static void subscribeToTopic(String topic) async {
    if (await ConnectionUtils.hasInternetConnection())
      await FcmService.firebaseMessaging.subscribeToTopic(topic);
  }

  static void unsubscribeFromTopic(String topic) async {
    try {
      await FcmService.firebaseMessaging.unsubscribeFromTopic(topic);
    } catch (_) {}
  }

  static FlutterLocalNotificationsPlugin localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _highImportanceChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'إشعارات هامة',
    description: 'الإشعارات الأساسية للتطبيق',
    importance: Importance.max,
  );

  static Future<void> initializeLocalNotifications() async {
    final InitializationSettings _initSettings = InitializationSettings(
        android: AndroidInitializationSettings("@mipmap/ic_launcher"),
        iOS: DarwinInitializationSettings()
    );
    await FcmService.localNotificationsPlugin.initialize(_initSettings, onDidReceiveNotificationResponse: FcmService.onTapNotification);

    // The channel FCM's manifest meta-data points at must actually exist —
    // it used to only come into being implicitly the first time a local
    // notification was shown, which is too late for background/terminated
    // FCM-SDK-rendered pushes.
    await FcmService.localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_highImportanceChannel);

    await FcmService.firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Requests notification permission. Call this AFTER login, not at cold
  /// start — Android 13+ gives one shot at the POST_NOTIFICATIONS prompt, so
  /// asking before the user has any reason to care just burns it.
  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await FcmService.localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    // iOS (and web) authorization — FirebaseMessaging.requestPermission()
    // does NOT raise Android's runtime POST_NOTIFICATIONS prompt, so it's
    // additive here, not a replacement for the call above.
    final settings = await FcmService.firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      log('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      log('User granted provisional permission');
    } else {
      log('User declined or has not accepted permission');
    }
  }

  static NotificationDetails get _platformChannelSpecifics => NotificationDetails(
        android: AndroidNotificationDetails(
          _highImportanceChannel.id,
          _highImportanceChannel.name,
          channelDescription: _highImportanceChannel.description,
          priority: Priority.max,
          importance: Importance.max,
        ),
      );

  static Future<void> _showLocalNotification(NotificationPayload payload) async {
    // Deterministic per-thread id: different destinations (e.g. two
    // conversations) get separate tray entries, while repeat notifications
    // for the SAME destination collapse into one instead of stacking —
    // fixes the previous hardcoded id 0, which made every notification
    // overwrite the last regardless of what it was about.
    final id = payload.routeKey.hashCode & 0x7fffffff;

    await FcmService.localNotificationsPlugin.show(
      id,
      payload.title.isEmpty ? null : payload.title,
      payload.body.isEmpty ? null : payload.body,
      FcmService._platformChannelSpecifics,
      payload: payload.toJsonString(),
    );
  }

  static Future<void> _onTokenRefresh(String token) async {
    log('[FcmService] token refreshed');
    // Only meaningful if someone is signed in; DeviceRegistrationService
    // itself also no-ops harmlessly if the register call 401s.
    await DeviceRegistrationService.instance.registerCurrentDevice(force: true);
  }

  static void _onOpenedFromBackground(RemoteMessage message) {
    log('[FcmService] onMessageOpenedApp');
    NotificationRouter.handle(NotificationPayload.fromRemoteMessage(message));
  }

  static Future<void> onTapNotification(NotificationResponse? response) async {
    final payload = NotificationPayload.fromJsonString(response?.payload);
    if (payload == null) return;
    await NotificationRouter.handle(payload);
  }

  /// Reads getInitialMessage() — must be called once from main(), before
  /// runApp, and its result handed to NotificationRouter.setPending(). Kept
  /// here only as the read; NotificationRouter owns the "when is it safe to
  /// navigate" decision so cold start doesn't race InitCache.
  static Future<NotificationPayload?> readInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message == null) return null;
    return NotificationPayload.fromRemoteMessage(message);
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final payload = NotificationPayload.fromRemoteMessage(message);

    final ctx = ContextUtils.globalContext;
    if (ctx != null) {
      try {
        ctx.read<NotificationBadgeProvider>().fetchUnreadCounts();
        ctx.read<ConversationProvider>().onRealtimeMessageReceived(message.data);
      } catch (e) {
        log('Error updating providers on foreground FCM message: $e');
      }
    }

    if (message.notification != null) {
      SecureStorage.addNotificationCount();
    }

    // iOS already displays the `notification` block via
    // setForegroundNotificationPresentationOptions(alert: true) above —
    // calling show() as well would double-display it there. Android has no
    // such SDK-level foreground display, so it still needs the explicit show().
    if (Platform.isAndroid && payload.title.isNotEmpty) {
      await FcmService._showLocalNotification(payload);
    }
  }
}
