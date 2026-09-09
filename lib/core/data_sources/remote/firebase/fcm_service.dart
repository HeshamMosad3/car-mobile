import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:car_mediator_mobile/core/helpers/helpers.dart';
import 'package:car_mediator_mobile/core/utils/connection_utils.dart';
import 'package:car_mediator_mobile/core/utils/context_utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../../../../features/shared/notifications/screens/notifications_screen.dart';
import '../../../../features/shared/chat/screens/chat_screen.dart';
import '../../../../features/user/my_requests/screens/responses_my_request_screen.dart';
import '../../../../features/vendor/new_requests/screens/details_new_request_screen.dart';
import '../../../../widgets/components.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/conversation_provider.dart';
import '../../../providers/notification_badge_provider.dart';
import '../../local/secure_storage.dart';


class FcmService {
  static FirebaseMessaging? _firebaseMessaging;
  static FirebaseMessaging get firebaseMessaging => FcmService._firebaseMessaging ?? FirebaseMessaging.instance;

  static Future<void> initializeFirebase() async {

    try{
      FcmService._firebaseMessaging = FirebaseMessaging.instance;
      await FcmService.initializeLocalNotifications();
      await FcmService.onBackgroundMsg();
      FcmService.subscribeToTopic('all');
    }catch(e){
      print(e);
    }
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
    if(await ConnectionUtils.hasInternetConnection())
      await FcmService.firebaseMessaging.subscribeToTopic(topic);
  }

  static FlutterLocalNotificationsPlugin localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initializeLocalNotifications() async {
    final InitializationSettings _initSettings = InitializationSettings(
        android: AndroidInitializationSettings("@mipmap/ic_launcher"),
        iOS: DarwinInitializationSettings()
    );
    /// on did receive notification response = for when app is opened via notification while in foreground on android
    await FcmService.localNotificationsPlugin.initialize(_initSettings, onDidReceiveNotificationResponse: FcmService.onTapNotification);
    /// need this for ios foregournd notification
    ///Configure notification permissions
    ///IOS
    await FcmService.firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true, // Required to display a heads up notification
      badge: true,
      sound: true,
    );
    /// for android
    NotificationSettings settings = await FcmService.firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }
  }

  static NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: AndroidNotificationDetails(
      "high_importance_channel", "High Importance Notifications", priority: Priority.max, importance: Importance.max,
    ),

  );

  static Future<void> backgroundHandler(RemoteMessage message) async {
    if (message.notification != null){
      log("--------FirebaseMessaging.onBackgroundMessage.listen----------");
      log('title---- ${message.notification?.title}');
      log('body---- ${message.notification?.body}');
      SecureStorage.addNotificationCount();
    }

    // if(message.data != null){
    //   if(message.data['type_notification'] == 'all'){
    //     print('type_notification---- ${message.data['type_notification']}');
    //     print('title---- ${message.notification?.title}');
    //     print('body---- ${message.notification?.body}');
    //     GlobalNavigator.dialogAdvancedGlobal(title: message.notification?.title ?? '',
    //         description: message.notification?.body ?? 'مرحباً',
    //         iconPath: AssetsPath.notification,
    //         onTabCancel: (){
    //         });
    //   }
    //
    // }

  }

  static void _handleNotificationNavigation(Map<String, dynamic>? data) {
    if (data == null) return;
    print("---_handleNotificationNavigation--- payload: $data");
    final _cxt = ContextUtils.globalContext;
    if (_cxt == null) return;

    try {
      final category = data['category'];

      if (category == 'conversations') {
        final conversationId = data['conversation_id'];
        if (conversationId != null) {
          navigationPush(_cxt, ChatScreen(
            conversationId: int.tryParse(conversationId.toString()) ?? 0,
            requestId: int.tryParse(data['request_id']?.toString() ?? '0') ?? 0,
            responseId: int.tryParse(data['response_id']?.toString() ?? '0') ?? 0,
            vendorId: int.tryParse(data['vendor_id']?.toString() ?? '0') ?? 0,
            receiverName: data['receiver_name']?.toString() ?? 'المحادثة',
            receiverLogo: '',
            myUserId: _cxt.read<AuthProvider>().currentUseModel?.id ?? 0,
          ));
          return;
        }
      } else if (category == 'company_responses') {
        final targetId = data['target_id'];
        if (targetId != null) {
          navigationPush(_cxt, ResponsesMyRequestScreen(
            requestId: int.tryParse(targetId.toString()) ?? 0,
          ));
          return;
        }
      } else if (category == 'customer_requests') {
        final targetId = data['target_id'];
        if (targetId != null) {
          navigationPush(_cxt, DetailsNewRequestScreen(
            requestId: int.tryParse(targetId.toString()) ?? 0,
          ));
          return;
        }
      }

      // Default fallback
      navigationPush(_cxt, NotificationsScreen());
    } catch (e) {
      log("Error navigating from notification: $e");
      navigationPush(_cxt, NotificationsScreen());
    }
  }

  static Future<void> onTapNotification(NotificationResponse? response) async {
    if (response?.payload == null) return;
    print('---onTapNotification--payload-------${response?.payload}---------');
    try {
      final Map<String, dynamic> data = jsonDecode(response!.payload!);
      _handleNotificationNavigation(data);
    } catch (e) {
      final _cxt = ContextUtils.globalContext;
      if (_cxt != null) navigationPush(_cxt, NotificationsScreen());
    }
  }

  static Future<void> initialMessage() async {
    //When App is Terminated
    var message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) {
      print("----FirebaseMessaging----initalMessage------${message.toString()}----");
      _handleNotificationNavigation(message.data);
    }
  }

  static Future<void> onMessage_OpenedApp() async {
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      print("--------FirebaseMessaging.onMessageOpenedApp.listen----------");
      _handleNotificationNavigation(message.data);
    });
  }

  static Future<void> onBackgroundMsg() async {
    //background message listener
    FirebaseMessaging.onBackgroundMessage(backgroundHandler);
  }

  // for receiving message when app is in foreground : for android
  static Future<void> onMessage() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // if this is available when Platform.isIOS, you'll receive the notification twice
      print("message recieved----onMessage--foreground messages-----");
      final cxt = ContextUtils.globalContext;
      if (cxt != null) {
        try {
          cxt.read<NotificationBadgeProvider>().fetchUnreadCounts();
          cxt.read<ConversationProvider>().onRealtimeMessageReceived(message.data);
        } catch (e) {
          log('Error updating NotificationBadgeProvider on FCM: $e');
        }
      }

      if(message.notification != null){
        print('title---- ${message.notification?.title}');
        print('body---- ${message.notification?.body}');

        SecureStorage.addNotificationCount();

        await FcmService.localNotificationsPlugin.show(
          0, message.notification!.title, message.notification!.body, FcmService.platformChannelSpecifics,
          payload: jsonEncode(message.data),
        );
      }
    });
  }

}

