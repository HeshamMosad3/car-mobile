import 'package:flutter/material.dart';

import '../../../../core/utils/constants/colors_constants.dart';
import '../../../../models/shipping_status_model.dart';

/// Where a shipment is in its life, as a number, so the card can tell which steps are behind it.
/// Canceled / unavailable shipments return -1: they are not on the happy path at all.
int shippingStepRank(String? status) {
  switch (status) {
    case 'AwaitingCustomerApproval':
      return 0;
    case 'AwaitingCustomerData':
    case 'Pending': // shipments from before the manual-quote flow, still waiting for the customer's data
      return 1;
    case 'ReadyForReview':
      return 2;
    case 'SearchingCarrier':
      return 3;
    case 'AwaitingPayment':
      return 4;
    case 'Paid':
      return 5;
    case 'BookingConfirmed':
      return 6;
    case 'PickedUp':
      return 7;
    case 'InTransit':
      return 8;
    case 'Delivered':
      return 9;
    default:
      return -1;
  }
}

/// The shipping card inside the chat bubble.
///
/// Compact on purpose: a three-dot progress line (approve → data → pay) instead of a button per
/// step, one button for the step that is waiting on the customer, and a "follow the shipment" button
/// that always opens the status page. Done steps are green with a check; the waiting step has its
/// own color; the rest are grey.
class ShippingCardWidget extends StatelessWidget {
  const ShippingCardWidget({
    super.key,
    required this.shipping,
    required this.isVendor,
    required this.isPaying,
    required this.onFillForm,
    required this.onPay,
    required this.onTrack,
  });

  final ShippingStatusModel? shipping;
  final bool isVendor;
  final bool isPaying;
  final VoidCallback onFillForm; // approval / data form
  final VoidCallback onPay;
  final VoidCallback onTrack; // status page

  static const Color _approveColor = Color(0xFF052659); // navy
  static const Color _dataColor = Color(0xFF6A1B9A); // purple
  static const Color _payColor = Color(0xFFE65100); // deep orange
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFB71C1C);
  static const Color _greyLine = Color(0xFFBDBDBD);
  static const Color _greyText = Color(0xFF616161);

  @override
  Widget build(BuildContext context) {
    final current = shipping;
    final rank = current == null ? 0 : shippingStepRank(current.status);
    final closed = current != null && rank == -1;

    final approveDone = rank >= 1;
    final dataDone = rank >= 2;
    final payDone = current?.paymentStatus == 'paid';

    // The step that is waiting on the customer (0 approve, 1 data, 2 pay), or -1 when nothing is.
    var waiting = -1;
    if (!isVendor && !closed) {
      if (rank <= 0) {
        waiting = 0;
      } else if (rank == 1) {
        waiting = 1;
      } else if (rank == 4 && current!.canPay) {
        waiting = 2;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(current, rank, closed, waiting),
        if (!closed) ...[
          const SizedBox(height: 10),
          _stepper(approveDone: approveDone, dataDone: dataDone, payDone: payDone, waiting: waiting),
        ],
        if (waiting != -1) ...[
          const SizedBox(height: 12),
          _actionButton(waiting),
        ],
        const SizedBox(height: 8),
        _trackButton(filled: waiting == -1),
      ],
    );
  }

  Widget _header(ShippingStatusModel? current, int rank, bool closed, int waiting) {
    final Color chipColor = closed
        ? _red
        : rank >= 5
            ? _green
            : waiting != -1
                ? _payColor
                : _approveColor;

    return Row(
      children: [
        const Icon(Icons.local_shipping, color: _approveColor, size: 20),
        const SizedBox(width: 6),
        const Text('طلب شحن', style: TextStyle(color: _approveColor, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        if (current != null && current.statusLabel.isNotEmpty)
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Text(
                current.statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }

  Widget _stepper({required bool approveDone, required bool dataDone, required bool payDone, required int waiting}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _node(1, 'الموافقة', _approveColor, done: approveDone, active: waiting == 0),
        _line(approveDone),
        _node(2, 'البيانات', _dataColor, done: dataDone, active: waiting == 1),
        _line(dataDone),
        _node(3, 'الدفع', _payColor, done: payDone, active: waiting == 2),
      ],
    );
  }

  Widget _node(int number, String label, Color color, {required bool done, required bool active}) {
    final Color labelColor = done ? _green : (active ? color : _greyText);

    return SizedBox(
      width: 54,
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? _green : (active ? color : Colors.transparent),
              border: done || active ? null : Border.all(color: _greyText, width: 1.5),
            ),
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 17)
                : Text(
                    '$number',
                    style: TextStyle(color: active ? Colors.white : _greyText, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(color: labelColor, fontSize: 11, fontWeight: done || active ? FontWeight.w800 : FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _line(bool done) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(height: 2.5, color: done ? _green : _greyLine),
      ),
    );
  }

  /// The one button for the step that is waiting on the customer, in that step's own color.
  Widget _actionButton(int waiting) {
    switch (waiting) {
      case 0:
        return _solidButton('الموافقة على الشحن', _approveColor, onFillForm);
      case 1:
        return _solidButton('أكمل بيانات الشحن', _dataColor, onFillForm);
      default:
        return _solidButton('ادفع رسوم الشحن', _payColor, onPay, loading: isPaying);
    }
  }

  Widget _solidButton(String label, Color color, VoidCallback onTap, {bool loading = false}) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: color,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: loading ? null : onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  /// Always opens the status page with the shipping details. Filled when nothing else is pending.
  Widget _trackButton({required bool filled}) {
    final radius = BorderRadius.circular(12);
    final Color fg = filled ? Colors.white : AppColor.primaryColor;

    return Material(
      color: filled ? AppColor.primaryColor : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTrack,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColor.primaryColor, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('تابع عملية الشحن', style: TextStyle(color: fg, fontSize: 13.5, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios_rounded, color: fg, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}
