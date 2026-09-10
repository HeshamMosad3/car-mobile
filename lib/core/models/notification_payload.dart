import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';

/// One typed parse of a notification, from whichever of the four entry
/// points produced it (FCM data map, the local-notification tap payload
/// string, or a row from GET /notifications). Every FCM value is a string,
/// so all id parsing goes through this one place.
///
/// Tolerant by design: reads the new contract's keys first (`route`,
/// `category_v2`) and falls back to the legacy ones (`category`,
/// `target_id`-derived route mapping) so this client keeps deep-linking
/// correctly against an old backend, and an old backend's payload still
/// routes correctly here.
class NotificationPayload {
  final String route;
  final String category;
  final String? targetId;
  final int? recipientId;
  final String? notificationId;
  final String title;
  final String body;
  final Map<String, String> params;

  const NotificationPayload({
    required this.route,
    required this.category,
    this.targetId,
    this.recipientId,
    this.notificationId,
    this.title = '',
    this.body = '',
    this.params = const {},
  });

  /// Unique per-destination key used both for the Android tray notification
  /// id/tag and for navigation-stack dedupe (see NotificationRouter).
  String get routeKey => '$route:${targetId ?? '0'}';

  factory NotificationPayload.fromData(Map<String, dynamic> data) {
    final category = (data['category_v2'] ?? data['category'] ?? 'generic').toString();
    final route = (data['route'] ?? _routeFromLegacyCategory(category)).toString();

    Map<String, String> params = {};
    final rawParams = data['params'];
    if (rawParams is String && rawParams.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawParams);
        if (decoded is Map) {
          params = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {
        // Legacy payloads flatten these keys at the top level instead.
      }
    }
    if (params.isEmpty) {
      const knownKeys = {
        'conversation_id', 'message_id', 'sender_id', 'request_id',
        'response_id', 'vendor_id', 'receiver_name', 'is_shipping_request',
      };
      for (final key in knownKeys) {
        if (data[key] != null) params[key] = data[key].toString();
      }
    }

    final targetIdRaw = (data['target_id'] ?? '').toString();

    return NotificationPayload(
      route: route,
      category: category,
      targetId: targetIdRaw.isEmpty ? null : targetIdRaw,
      recipientId: int.tryParse((data['recipient_id'] ?? '').toString()),
      notificationId: (data['notification_id'] ?? '').toString().isEmpty
          ? null
          : data['notification_id'].toString(),
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      params: params,
    );
  }

  factory NotificationPayload.fromRemoteMessage(RemoteMessage? message) {
    if (message == null) {
      return const NotificationPayload(route: '', category: 'generic');
    }
    final data = Map<String, dynamic>.from(message.data);
    data['title'] ??= message.notification?.title;
    data['body'] ??= message.notification?.body;
    return NotificationPayload.fromData(data);
  }

  /// A row from GET /notifications (see NotificationModel).
  factory NotificationPayload.fromApiRow({
    required String? category,
    required String? targetId,
    required String title,
    required String body,
  }) {
    final cat = category ?? 'generic';
    return NotificationPayload(
      route: _routeFromLegacyCategory(cat),
      category: cat,
      targetId: targetId,
      title: title,
      body: body,
    );
  }

  String toJsonString() => jsonEncode({
        'route': route,
        'category_v2': category,
        'target_id': targetId,
        'recipient_id': recipientId?.toString(),
        'notification_id': notificationId,
        'title': title,
        'body': body,
        ...params,
      });

  static NotificationPayload? fromJsonString(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return NotificationPayload.fromData(decoded);
      }
    } catch (_) {}
    return null;
  }

  static String _routeFromLegacyCategory(String category) {
    switch (category) {
      case 'conversations':
      case 'chat_message':
      case 'shipping_request':
        return 'chat';
      case 'company_responses':
      case 'vendor_response':
        return 'request_responses';
      case 'customer_requests':
      case 'new_request':
        return 'request_details';
      default:
        return 'notifications';
    }
  }
}
