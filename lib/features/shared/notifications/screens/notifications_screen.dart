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

const _knownBadgeBuckets = {'conversations', 'customer_requests', 'company_responses'};


class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<NotificationProvider>(context, listen: false);
      provider.resetPagination();
      await provider.getNotifications();
    });

    _scrollController.addListener(() {
      final p = Provider.of<NotificationProvider>(context, listen: false);
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent &&
          !p.isLoading &&
          p.hasMore) {
        p.getNotifications(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text("الإشعارات", style: txtMedium05,),
        leading: ArrowBackWidget(myContext: context),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {

          if ( provider.notificationModelList.isEmpty && provider.isLoading) {
            return const CustomLoading();
          }

          return RefreshIndicator(
            onRefresh: () => provider.refreshGetNotifications(),
            child: provider.notificationModelList.isNotEmpty ? ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: provider.notificationModelList.length + (provider.isLoading ? 1 : 0),
              shrinkWrap: true,
              padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
              itemBuilder: (context, index) {
                if (index < provider.notificationModelList.length) {
                  final notif = provider.notificationModelList[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: Card(
                        elevation: 3,
                        shadowColor: Colors.black26,
                        color: notif.isRead ? Colors.white : AppColor.primaryColor.withOpacity(0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _onNotificationTap(context, notif),
                              child: ListTile(
                                contentPadding: EdgeInsets.all(16),
                                leading: Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColor.primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.notifications, color: AppColor.primaryColor, size: 28),
                                ),
                                title: Text(
                                  notif.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.bold,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    notif.body,
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10,),
                           Divider(color: Colors.grey.withOpacity(0.3),),
                           Padding(padding: EdgeInsets.only(left: 16, right: 16,bottom: 10,top: 10),
                           child:  Align(
                             alignment: Alignment.centerLeft,
                             child: Text(
                               notif.createdAt,
                               textDirection: TextDirection.ltr,
                               style: TextStyle(fontSize: 12, color: Colors.grey),
                             ),
                           ),)
                          ],
                        ),
                      ),
                    ),
                  );
                } else {
                  return const Padding(padding: EdgeInsets.only(bottom: 10),
                    child: CustomLoading(radius: 18,),
                  );
                }
              },
            ) : const CustomEmptyWidget(label: 'لا توجد إشعارات للعرض حالياً',),);
        },
      ),
    );
  }

  void _onNotificationTap(BuildContext context, NotificationModel notif) {
    final targetId = notif.targetId;
    final category = notif.category;

    if (category != null && _knownBadgeBuckets.contains(category) && targetId != null) {
      final entityId = int.tryParse(targetId);
      if (entityId != null) {
        context.read<NotificationBadgeProvider>().markEntityRead(section: category, entityId: entityId);
      }
    }

    NotificationRouter.handle(NotificationPayload.fromApiRow(
      category: category,
      targetId: targetId,
      title: notif.title,
      body: notif.body,
    ));
  }
}


