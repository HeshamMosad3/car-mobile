import 'dart:async';
import 'package:flutter/material.dart';
import '../data_sources/remote/reverb_service.dart';
import '../services/shared/notification_service.dart';

class NotificationBadgeProvider extends ChangeNotifier {
  final NotificationService _service;
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;

  Map<String, int> unreadCounts = {
    'customer_requests': 0,
    'company_responses': 0,
    'conversations': 0,
  };

  Map<String, Map<int, int>> entityUnreadCounts = {
    'conversations': {},
    'customer_requests': {},
    'company_responses': {},
  };

  NotificationBadgeProvider(this._service);

  /// Replaces the old 4-second polling. Call this once per session
  /// (e.g. in initState of the home screen) with the logged-in user's id.
  Future<void> startRealtimeListening(int userId) async {
    await stopRealtimeListening();

    // Initial fetch so the badge is correct as soon as the screen opens.
    await fetchUnreadCounts();

    final stream = await ReverbService.instance.listenToPrivateChannel('user.$userId');
    _realtimeSubscription = stream.listen((message) {
      if (message['event'] != 'notification.badge.updated') return;

      // The event now carries the real counts (see NotificationBadgeBroadcaster
      // server-side), so apply them directly — falling back to a re-fetch
      // only if they're absent, e.g. against an older backend.
      final data = message['data'];
      final unreadCounts = data is Map ? data['unread_counts'] : null;
      if (unreadCounts is Map && unreadCounts.isNotEmpty) {
        _parseRawData(Map<String, dynamic>.from(unreadCounts));
        notifyListeners();
      } else {
        fetchUnreadCounts();
      }
    });
  }

  Future<void> stopRealtimeListening() async {
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  int getCount(String category, {int? entityId}) {
    if (entityId != null) {
      return entityUnreadCounts[category]?[entityId] ?? 0;
    }
    final entityMap = entityUnreadCounts[category];
    if (entityMap != null && entityMap.isNotEmpty) {
      int sum = 0;
      entityMap.forEach((_, count) {
        if (count > 0) sum += count;
      });
      return sum;
    }
    return unreadCounts[category] ?? 0;
  }

  int getEntityCount(String category, int entityId) {
    return entityUnreadCounts[category]?[entityId] ?? 0;
  }

  Future<void> fetchUnreadCounts() async {
    final rawData = await _service.getRawUnreadCountsData();
    if (rawData != null) {
      _parseRawData(rawData);
      notifyListeners();
    }
  }

  void _parseRawData(Map<String, dynamic> data) {
    if (data['sections'] is Map) {
      final sections = data['sections'] as Map;
      sections.forEach((key, value) {
        if (value is num) {
          unreadCounts[key.toString()] = value.toInt();
        }
      });
    } else {
      data.forEach((key, value) {
        if (value is num) {
          unreadCounts[key] = value.toInt();
        }
      });
    }

    if (data['entities'] is Map) {
      final entities = data['entities'] as Map;
      entities.forEach((secKey, secValue) {
        if (secValue is Map) {
          final Map<int, int> itemMap = {};
          secValue.forEach((entId, count) {
            final parsedId = int.tryParse(entId.toString());
            if (parsedId != null && count is num) {
              itemMap[parsedId] = count.toInt();
            }
          });
          entityUnreadCounts[secKey.toString()] = itemMap;
        }
      });
    }
  }

  Future<void> markEntityRead({required String section, required int entityId}) async {
    if (entityUnreadCounts[section] != null) {
      final currentEntityCount = entityUnreadCounts[section]?[entityId] ?? 0;
      if (currentEntityCount > 0) {
        entityUnreadCounts[section]?[entityId] = 0;
        unreadCounts[section] = (unreadCounts[section] ?? 0) - currentEntityCount;
        if ((unreadCounts[section] ?? 0) < 0) unreadCounts[section] = 0;
        notifyListeners();
      }
    }

    final rawData = await _service.markEntityRead(section: section, entityId: entityId);
    if (rawData != null) {
      _parseRawData(rawData);
      notifyListeners();
    }
  }

  Future<void> markCategoryRead(String category) async {
    unreadCounts[category] = 0;
    entityUnreadCounts[category]?.clear();
    notifyListeners();

    final updated = await _service.markCategoryRead(category);
    if (updated != null) {
      unreadCounts = updated;
      notifyListeners();
    }
  }

  void incrementEntityCategory(String category, int entityId) {
    entityUnreadCounts[category] ??= {};
    entityUnreadCounts[category]![entityId] = (entityUnreadCounts[category]![entityId] ?? 0) + 1;
    unreadCounts[category] = (unreadCounts[category] ?? 0) + 1;
    notifyListeners();
  }

  void clearAll() {
    stopRealtimeListening();
    unreadCounts = {
      'customer_requests': 0,
      'company_responses': 0,
      'conversations': 0,
    };
    entityUnreadCounts = {
      'conversations': {},
      'customer_requests': {},
      'company_responses': {},
    };
    notifyListeners();
  }
}