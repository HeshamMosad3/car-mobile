import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/notification_payload.dart';
import '../../../../core/providers/notification_badge_provider.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/routing/notification_router.dart';
import '../../../../core/styles/styles.dart';
import '../../../../core/utils/constants/colors_constants.dart';
import '../../../../core/utils/size_config.dart';
import '../../../../models/notification_model.dart';
import '../../../../widgets/arrow_back_widget.dart';
import '../../../../widgets/custom_empty_widget.dart';
import '../../../../widgets/custom_loading.dart';

/// Notification category -> the unread-badge section it counts in (cleared when that item is opened).
const _badgeSectionOfCategory = {
  'chat_message': 'conversations',
  'new_request': 'customer_requests',
  'vendor_response': 'company_responses',
};

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _unreadColor = Color(0xFFE6EEFB);

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<NotificationProvider>(context, listen: false);
      provider.resetPagination();
      await provider.getNotifications();

      // Everything on this screen has now been seen, so the bell resets. The rows already loaded
      // keep their "unread" look for this visit, so the user can still tell what is new.
      if (mounted) context.read<NotificationBadgeProvider>().markAllRead();
    });

    _scrollController.addListener(() {
      final p = Provider.of<NotificationProvider>(context, listen: false);
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !p.isLoading && p.hasMore) {
        p.getNotifications(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text("الإشعارات", style: txtMedium05),
        leading: ArrowBackWidget(myContext: context),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.notificationModelList.isEmpty && provider.isLoading) {
            return const CustomLoading();
          }

          final items = provider.notificationModelList;

          return RefreshIndicator(
            onRefresh: () => provider.refreshGetNotifications(),
            child: items.isEmpty
                // A scrollable, so pull-to-refresh still works on the empty state.
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [CustomEmptyWidget(label: 'لا توجد إشعارات للعرض حالياً')],
                  )
                : ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length + (provider.isLoading ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFEDEFF2)),
                    itemBuilder: (context, index) {
                      if (index >= items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: CustomLoading(radius: 18),
                        );
                      }
                      return _NotificationRow(
                        notification: items[index],
                        unreadColor: _unreadColor,
                        onTap: () => _onNotificationTap(context, items[index]),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  /// Every notification opens the screen where its next step is: a shipment's chat (where paying and
  /// approving happen), the offers on a request, a request to answer, or the main screen.
  void _onNotificationTap(BuildContext context, NotificationModel notif) {
    final category = notif.category;

    final section = _badgeSectionOfCategory[category];
    final entityId = int.tryParse(notif.targetId ?? '');
    if (section != null && entityId != null) {
      context.read<NotificationBadgeProvider>().markEntityRead(section: section, entityId: entityId);
    }

    // This is already the notifications list: opening another copy of it would help nobody.
    if (notif.route == 'notifications') return;

    NotificationRouter.handle(NotificationPayload.fromApiRow(
      category: category,
      targetId: notif.targetId,
      title: notif.title,
      body: notif.body,
      route: notif.route,
      routeTargetId: notif.routeTargetId,
      params: notif.routeParams,
    ));
  }
}

/// One compact row. About 70 px tall, so a screen shows around ten of them.
class _NotificationRow extends StatelessWidget {
  final NotificationModel notification;
  final Color unreadColor;
  final VoidCallback onTap;

  const _NotificationRow({required this.notification, required this.unreadColor, required this.onTap});

  IconData get _icon {
    switch (notification.category) {
      case 'chat_message':
        return Icons.chat_bubble_outline_rounded;
      case 'new_request':
      case 'request_update':
        return Icons.assignment_outlined;
      case 'vendor_response':
        return Icons.local_offer_outlined;
      case 'vendor_status':
        return Icons.verified_user_outlined;
      case 'shipment_update':
        return Icons.local_shipping_outlined;
    }
    // Older notifications are all "generic": where they lead tells what they are about.
    if (notification.route == 'chat') return Icons.local_shipping_outlined;
    if (notification.route == 'request_responses') return Icons.assignment_outlined;
    return Icons.notifications_none_rounded;
  }

  /// "20:11" for today, "11-03 20:11" for older ones (the stored text is "2026-11-03 20:11").
  String get _time {
    final raw = notification.createdAt;
    if (raw.length < 16) return raw;
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return raw.startsWith(today) ? raw.substring(11, 16) : raw.substring(5, 16);
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: unread ? unreadColor : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColor.primaryColor.withOpacity(unread ? 0.14 : 0.08),
                child: Icon(_icon, size: 19, color: AppColor.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: unread ? FontWeight.w800 : FontWeight.w600, height: 1.25),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _time,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF5B6270), height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (unread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsetsDirectional.only(end: 4),
                  decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
                ),
              Icon(isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 20, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
