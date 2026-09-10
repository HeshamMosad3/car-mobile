import 'package:flutter/material.dart';

/// Tracks route NAMES on the root navigator so NotificationRouter can dedupe
/// (skip pushing a screen that's already on top, or already on the stack)
/// without the app needing a full named-route table — see
/// widgets/components.dart's navigationPush(routeName:) for how a name gets
/// attached to an ordinary widget-instance push.
class AppRouteObserver extends NavigatorObserver {
  static final AppRouteObserver instance = AppRouteObserver._internal();
  AppRouteObserver._internal();

  final List<String?> _stack = [];

  String? get currentRouteName => _stack.isEmpty ? null : _stack.last;

  bool stackContains(String routeName) => _stack.contains(routeName);

  @override
  void didPush(Route route, Route? previousRoute) {
    _stack.add(route.settings.name);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (_stack.isNotEmpty) _stack.removeLast();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    _stack.remove(route.settings.name);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (_stack.isNotEmpty) _stack.removeLast();
    _stack.add(newRoute?.settings.name);
  }
}
