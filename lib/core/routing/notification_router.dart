import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../features/shared/chat/screens/chat_screen.dart';
import '../../features/shared/notifications/screens/notifications_screen.dart';
import '../../features/user/my_requests/screens/responses_my_request_screen.dart';
import '../../features/vendor/new_requests/screens/details_new_request_screen.dart';
import '../../widgets/components.dart';
import '../helpers/helpers.dart';
import '../models/notification_payload.dart';
import '../providers/auth_provider.dart';
import '../utils/constants/enumeration.dart';
import '../utils/context_utils.dart';
import 'app_route_observer.dart';

/// The single destination resolver every notification entry point calls:
/// foreground tap, background tap (onMessageOpenedApp), cold start
/// (getInitialMessage), and a NotificationsScreen row tap.
class NotificationRouter {
  NotificationRouter._();

  static NotificationPayload? _pending;
  static bool _appReady = false;

  /// Call from main() with the getInitialMessage() result, before runApp —
  /// this only stores it, it never navigates (the navigator doesn't exist yet).
  static void setPending(NotificationPayload? payload) {
    if (payload != null && payload.route.isNotEmpty) {
      _pending = payload;
    }
  }

  /// Call ONCE, from CacheProvider._navigationToHomePage, right after the
  /// home page is pushed. At that point auth + providers are ready and home
  /// is on the stack, so a deep-linked screen has a real back destination —
  /// this is what stops the cold-start path from racing InitCache.
  static void setAppReady() {
    _appReady = true;
    final payload = _pending;
    _pending = null;
    if (payload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => handle(payload));
    }
  }

  static Future<void> handle(NotificationPayload payload) async {
    if (payload.route.isEmpty) return;

    if (!_appReady) {
      _pending = payload;
      return;
    }

    final ctx = ContextUtils.globalContext;
    if (ctx == null) {
      _pending = payload;
      return;
    }

    final auth = ctx.read<AuthProvider>();
    final myId = auth.currentUseModel?.id;

    if (myId == null) {
      // Logged out — stash it and replay after the next successful login,
      // but only if that login is the same account this was addressed to.
      await _stashForNextLogin(payload);
      return;
    }

    // Client-side half of the "reaches the correct user" guarantee: a
    // payload addressed to a different account than the one signed in on
    // this device (e.g. a stale token FCM hasn't pruned yet, or a device
    // reused across accounts) is dropped, not navigated.
    if (payload.recipientId != null && payload.recipientId != myId) {
      Helper.logDebug('[NotificationRouter] payload for ${payload.recipientId} but signed in as $myId — dropping');
      return;
    }

    final destination = _buildDestination(payload, ctx);
    if (destination == null) return;

    final routeKey = payload.routeKey;
    final topRoute = AppRouteObserver.instance.currentRouteName;

    if (topRoute == routeKey) {
      return; // already looking at it
    }

    if (AppRouteObserver.instance.stackContains(routeKey)) {
      navigatorKey.currentState?.popUntil((r) => r.settings.name == routeKey);
      return;
    }

    navigationPush(ctx, destination, routeName: routeKey);
  }

  static Widget? _buildDestination(NotificationPayload payload, BuildContext ctx) {
    final auth = ctx.read<AuthProvider>();
    final myId = auth.currentUseModel?.id ?? 0;
    final isVendor = auth.currentUseModel?.role == UserRoleEnum.vendor.name;

    switch (payload.route) {
      case 'chat':
        final conversationId = int.tryParse(payload.targetId ?? payload.params['conversation_id'] ?? '');
        if (conversationId == null) return const NotificationsScreen();
        return ChatScreen(
          conversationId: conversationId,
          requestId: int.tryParse(payload.params['request_id'] ?? '') ?? 0,
          responseId: int.tryParse(payload.params['response_id'] ?? '') ?? 0,
          vendorId: int.tryParse(payload.params['vendor_id'] ?? '') ?? 0,
          receiverName: payload.params['receiver_name'] ?? 'المحادثة',
          receiverLogo: '',
          myUserId: myId,
          isVendor: isVendor,
        );
      case 'request_responses':
        final requestId = int.tryParse(payload.targetId ?? '');
        if (requestId == null) return const NotificationsScreen();
        return ResponsesMyRequestScreen(requestId: requestId);
      case 'request_details':
        final requestId = int.tryParse(payload.targetId ?? '');
        if (requestId == null) return const NotificationsScreen();
        return DetailsNewRequestScreen(requestId: requestId);
      default:
        return const NotificationsScreen();
    }
  }

  static DateTime? _pendingStashedAt;

  static Future<void> _stashForNextLogin(NotificationPayload payload) async {
    _pendingLoggedOutPayload = payload;
    _pendingStashedAt = DateTime.now();
  }

  static NotificationPayload? _pendingLoggedOutPayload;

  /// Called from AuthProvider after a successful login. Replays a
  /// notification that arrived while the app was signed out, but only if it
  /// was addressed to the account that just signed in, and only within a
  /// short window (stale deep links shouldn't surprise-navigate someone
  /// minutes into a fresh session).
  static void replayAfterLogin(int loggedInUserId) {
    final payload = _pendingLoggedOutPayload;
    final stashedAt = _pendingStashedAt;
    _pendingLoggedOutPayload = null;
    _pendingStashedAt = null;

    if (payload == null || stashedAt == null) return;
    if (DateTime.now().difference(stashedAt) > const Duration(minutes: 10)) return;
    if (payload.recipientId != null && payload.recipientId != loggedInUserId) return;

    WidgetsBinding.instance.addPostFrameCallback((_) => handle(payload));
  }
}
