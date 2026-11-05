import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/providers/auth_provider.dart';
import '../core/providers/notification_badge_provider.dart';
import '../core/providers/shipping_provider.dart';
import '../core/utils/constants/colors_constants.dart';
import '../features/shared/notifications/screens/notifications_screen.dart';
import '../features/user/shipping_actions/screens/pending_shipping_actions_screen.dart';
import '../models/shipping_status_model.dart';
import 'components.dart';

/// The bell in the home app bar. It carries a red count of everything new about the user's orders
/// (offers, request and shipment status changes, refunds), and opens the notifications list.
///
/// For customers ([showPendingActions]) it also announces the next thing they have to do on a
/// shipment ("ادفع رسوم الشحن") in a small bubble under the bell. The bubble appears once when the
/// step is new, hides itself after a few seconds, and tapping it opens the list of those steps.
class NotificationBellButton extends StatefulWidget {
  final bool showPendingActions;

  const NotificationBellButton({super.key, this.showPendingActions = false});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> with WidgetsBindingObserver {
  static const _bubbleDuration = Duration(seconds: 7);

  final LayerLink _link = LayerLink();
  OverlayEntry? _bubble;
  Timer? _hideTimer;
  Timer? _safetyRefresh;

  /// "shippingId:status" of the steps already announced, so each one pops up only once.
  final Set<String> _announced = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationBadgeProvider>().fetchUnreadCounts();

      if (widget.showPendingActions) {
        final shipping = context.read<ShippingProvider>();
        shipping.loadPendingActions();

        // The server pushes every shipment status change; this is what updates the bell by itself.
        final userId = context.read<AuthProvider>().currentUseModel?.id;
        if (userId != null) shipping.startRealtime(userId);
      }
    });

    // Safety net in case the live connection dropped for a while.
    _safetyRefresh = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    context.read<NotificationBadgeProvider>().fetchUnreadCounts();
    if (widget.showPendingActions) context.read<ShippingProvider>().refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the browser, another app or the lock screen: catch up on anything missed.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _hideBubble();
    _safetyRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openNotifications() async {
    _hideBubble();
    await navigationPush(context, const NotificationsScreen());
    if (mounted) _refresh();
  }

  Future<void> _openActions() async {
    _hideBubble();
    await navigationPush(context, const PendingShippingActionsScreen());
    if (mounted) context.read<ShippingProvider>().loadPendingActions();
  }

  // ---- the bubble ----

  void _syncBubble(List<PendingShippingAction> pending, bool isCurrentRoute) {
    if (!mounted) return;

    // Never float over another screen, and forget everything once nothing is waiting so a step
    // that comes back later is announced again.
    if (!isCurrentRoute) {
      _hideBubble();
      return;
    }
    if (pending.isEmpty) {
      _announced.clear();
      _hideBubble();
      return;
    }

    final keys = pending.map((a) => '${a.shippingId}:${a.status}').toList();
    final fresh = keys.where((k) => !_announced.contains(k)).toList();
    if (fresh.isEmpty) return;
    _announced.addAll(keys);

    final first = pending[keys.indexOf(fresh.first)];
    final extra = pending.length - 1;
    _showBubble(extra > 0 ? '${first.actionText} (+$extra)' : first.actionText);
  }

  void _showBubble(String text) {
    _hideBubble();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _bubble = OverlayEntry(
      builder: (_) => CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(6, 2),
        child: Align(
          alignment: Alignment.topLeft,
          child: _ActionBubble(text: text, onTap: _openActions, onClose: _hideBubble),
        ),
      ),
    );
    overlay.insert(_bubble!);
    _hideTimer = Timer(_bubbleDuration, _hideBubble);
  }

  void _hideBubble() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _bubble?.remove();
    _bubble = null;
  }

  // ---- the bell ----

  @override
  Widget build(BuildContext context) {
    final bell = context.select<NotificationBadgeProvider, int>((p) => p.bellCount);
    final pending = widget.showPendingActions
        ? context.select<ShippingProvider, List<PendingShippingAction>>((p) => p.pendingActions)
        : const <PendingShippingAction>[];

    // Something waiting on the customer must never show as "0", even after its notification was read.
    final count = bell > pending.length ? bell : pending.length;

    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBubble(pending, isCurrentRoute));

    return CompositedTransformTarget(
      link: _link,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
        child: Semantics(
          button: true,
          label: count > 0 ? 'الإشعارات، $count جديد' : 'الإشعارات',
          child: InkResponse(
            onTap: _openNotifications,
            radius: 28,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    count > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                    size: 38,
                    color: AppColor.primaryColor,
                  ),
                  if (count > 0)
                    Positioned(
                      top: 3,
                      right: 1,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small popup under the bell: a rounded card with a pointer towards the bell.
class _ActionBubble extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _ActionBubble({required this.text, required this.onTap, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.62;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 14),
              child: CustomPaint(size: const Size(14, 7), painter: _PointerPainter()),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFB71C1C),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                      InkResponse(
                        onTap: onClose,
                        radius: 16,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFB71C1C));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
