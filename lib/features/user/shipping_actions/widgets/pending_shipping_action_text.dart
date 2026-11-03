import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/shipping_provider.dart';
import '../../../../core/utils/size_config.dart';
import '../../../../widgets/components.dart';
import '../screens/pending_shipping_actions_screen.dart';

/// Short text in the home app bar saying what the customer has to do next on a shipment
/// ("ادفع رسوم الشحن"). It behaves like a notification without the icon: it is only there while
/// something is waiting on the customer, and tapping it opens the list of those shipments.
class PendingShippingActionText extends StatefulWidget {
  const PendingShippingActionText({super.key});

  @override
  State<PendingShippingActionText> createState() => _PendingShippingActionTextState();
}

class _PendingShippingActionTextState extends State<PendingShippingActionText> with WidgetsBindingObserver {
  Timer? _safetyRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ShippingProvider>();
      provider.loadPendingActions();

      // The server pushes every status change; this is what makes the text update by itself.
      final userId = context.read<AuthProvider>().currentUseModel?.id;
      if (userId != null) provider.startRealtime(userId);
    });

    // Safety net in case the live connection dropped for a while.
    _safetyRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) context.read<ShippingProvider>().refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the browser, another app or the lock screen: catch up on anything missed.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ShippingProvider>().refresh();
    }
  }

  @override
  void dispose() {
    _safetyRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _open() async {
    await navigationPush(context, const PendingShippingActionsScreen());
    if (mounted) context.read<ShippingProvider>().loadPendingActions();
  }

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<ShippingProvider>().pendingActions;
    if (pending.isEmpty) return const SizedBox.shrink();

    final extra = pending.length - 1;
    final text = extra > 0 ? '${pending.first.actionText} (+$extra)' : pending.first.actionText;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: SizeConfig.widthResponsive(0.42)),
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFB71C1C), // deep red: readable on the white app bar, unlike the yellow accent
                fontSize: SizeConfig.widthResponsive(0.034),
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
