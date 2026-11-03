/// Arabic label for a shipment status, for screens that only receive the raw value (the responses list).
String shippingStatusLabel(String status) {
  switch (status) {
    case 'AwaitingCustomerApproval':
      return 'بانتظار موافقة الزبون';
    case 'AwaitingCustomerData':
      return 'بانتظار استكمال البيانات';
    case 'ReadyForReview':
      return 'جاهز للمراجعة الإدارية';
    case 'SearchingCarrier':
      return 'جارٍ البحث عن شركة شحن';
    case 'AwaitingPayment':
      return 'بانتظار دفع رسوم الشحن';
    case 'Paid':
      return 'تم دفع رسوم الشحن';
    case 'BookingConfirmed':
      return 'تم تأكيد الحجز';
    case 'PickedUp':
      return 'تم استلام الشحنة';
    case 'InTransit':
      return 'في الطريق';
    case 'Delivered':
      return 'تم التسليم';
    case 'Unavailable':
      return 'تعذّر توفير الشحن';
    case 'Canceled':
      return 'أُلغي طلب الشحن';
    case 'Pending':
      return 'قيد المعالجة';
    default:
      return 'تم الشحن';
  }
}

/// Response of every shipping endpoint: the shipment (when the endpoint returns one) plus the raw
/// `result` for the few calls that return something else, e.g. a payment checkout.
class ShippingResultModel {
  final bool success;
  final String message;
  final ShippingStatusModel? shipping;
  final Map<String, dynamic> raw;

  const ShippingResultModel({
    this.success = false,
    this.message = '',
    this.shipping,
    this.raw = const {},
  });

  factory ShippingResultModel.fromJson(Map<String, dynamic>? json) {
    final result = json?['result'];
    final map = result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
    return ShippingResultModel(
      success: json?['success'] ?? false,
      message: json?['message'] ?? '',
      shipping: map.containsKey('status') ? ShippingStatusModel.fromJson(map) : null,
      raw: map,
    );
  }
}

class ShippingStatusModel {
  final int id;
  final String status;
  final String statusLabel;
  final String paymentStatus;
  final String paymentStatusLabel;
  final double? shippingCost;
  final String paymentDueAt;
  final String carrierName;
  final String trackingNumber;
  final String pickupDetails;
  final String cancelReason;
  final bool needsData;
  final bool canPay;
  final bool canCancel;

  const ShippingStatusModel({
    this.id = 0,
    this.status = '',
    this.statusLabel = '',
    this.paymentStatus = '',
    this.paymentStatusLabel = '',
    this.shippingCost,
    this.paymentDueAt = '',
    this.carrierName = '',
    this.trackingNumber = '',
    this.pickupDetails = '',
    this.cancelReason = '',
    this.needsData = false,
    this.canPay = false,
    this.canCancel = false,
  });

  factory ShippingStatusModel.fromJson(Map<String, dynamic>? json) {
    return ShippingStatusModel(
      id: json?['id'] ?? 0,
      status: json?['status'] ?? '',
      statusLabel: json?['status_label'] ?? '',
      paymentStatus: json?['payment_status'] ?? '',
      paymentStatusLabel: json?['payment_status_label'] ?? '',
      // MySQL returns decimals as strings and SQLite as numbers, so accept both.
      shippingCost: double.tryParse(json?['shipping_cost']?.toString() ?? ''),
      paymentDueAt: json?['payment_due_at'] ?? '',
      carrierName: json?['carrier_name'] ?? '',
      trackingNumber: json?['tracking_number'] ?? '',
      pickupDetails: json?['pickup_details'] ?? '',
      cancelReason: json?['cancel_reason'] ?? '',
      needsData: json?['needs_data'] == true,
      canPay: json?['can_pay'] == true,
      canCancel: json?['can_cancel'] == true,
    );
  }

  /// A closed shipment: nothing more will happen to it.
  bool get isClosed => status == 'Delivered' || status == 'Canceled' || status == 'Unavailable';
}


/// A shipment that is waiting for the customer to do something (approve, complete the data, pay).
/// Only these steps are listed: waiting on the admin or the carrier gives the user nothing to do.
class PendingShippingAction {
  final int shippingId;
  final String status;
  final String action;
  final String actionText;
  final int conversationId;
  final int requestId;
  final int responseId;
  final int vendorId;
  final String receiverName;
  final String receiverLogo;

  const PendingShippingAction({
    required this.shippingId,
    required this.status,
    required this.action,
    required this.actionText,
    required this.conversationId,
    required this.requestId,
    required this.responseId,
    required this.vendorId,
    this.receiverName = '',
    this.receiverLogo = '',
  });

  factory PendingShippingAction.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    return PendingShippingAction(
      shippingId: asInt(json['shipping_id']),
      status: json['status']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      actionText: json['action_text']?.toString() ?? '',
      conversationId: asInt(json['conversation_id']),
      requestId: asInt(json['request_id']),
      responseId: asInt(json['response_id']),
      vendorId: asInt(json['vendor_id']),
      receiverName: json['receiver_name']?.toString() ?? '',
      receiverLogo: json['receiver_logo']?.toString() ?? '',
    );
  }
}
