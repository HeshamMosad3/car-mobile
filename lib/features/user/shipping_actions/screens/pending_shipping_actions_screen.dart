import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/shipping_provider.dart';
import '../../../../core/styles/styles.dart';
import '../../../../core/utils/constants/colors_constants.dart';
import '../../../../models/shipping_status_model.dart';
import '../../../../widgets/arrow_back_widget.dart';
import '../../../../widgets/components.dart';
import '../../../shared/chat/screens/chat_screen.dart';

/// The shipments that are waiting on the customer. Tapping the current step opens that order's
/// chat, where the matching button is.
class PendingShippingActionsScreen extends StatefulWidget {
  const PendingShippingActionsScreen({super.key});

  @override
  State<PendingShippingActionsScreen> createState() => _PendingShippingActionsScreenState();
}

class _PendingShippingActionsScreenState extends State<PendingShippingActionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ShippingProvider>().loadPendingActions());
  }

  Future<void> _openChat(PendingShippingAction item) async {
    final myId = context.read<AuthProvider>().currentUseModel?.id ?? 0;
    await navigationPush(
      context,
      ChatScreen(
        conversationId: item.conversationId,
        requestId: item.requestId,
        responseId: item.responseId,
        vendorId: item.vendorId,
        receiverName: item.receiverName,
        receiverLogo: item.receiverLogo,
        myUserId: myId,
      ),
    );
    if (mounted) context.read<ShippingProvider>().loadPendingActions();
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ShippingProvider>().pendingActions;

    return Scaffold(
      backgroundColor: AppColor.secondaryColor,
      appBar: AppBar(
        title: Text('إجراءات الشحن المطلوبة', style: txtBold05),
        centerTitle: true,
        elevation: 0,
        leading: ArrowBackWidget(myContext: context),
      ),
      body: items.isEmpty
          ? Center(child: Text('لا توجد إجراءات مطلوبة منك حالياً', style: txtMedium04))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openChat(item),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.receiverName, style: txtBold05),
                                const SizedBox(height: 6),
                                Text(
                                  item.actionText,
                                  style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chat_bubble_outline, color: AppColor.primaryColor),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
